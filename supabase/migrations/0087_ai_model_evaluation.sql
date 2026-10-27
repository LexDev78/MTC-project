-- De quoi dire qu'un modèle est meilleur qu'un autre.
--
-- Sans cela, « notre modèle marche mieux que Voyage » est une opinion. Et
-- une opinion suffit à prendre la mauvaise décision : on compare deux
-- modèles sur trois photos choisies après coup, on conclut, on bascule, et
-- on découvre la régression par les ventes.
--
-- Il faut donc un étalon : un jeu de photos **figé**, avec pour chacune le
-- produit qu'elle désigne vraiment, et une mesure unique que tout modèle
-- subit à l'identique.
--
-- ## La mesure
--
-- `recall@k` : sur combien de photos le bon produit figure-t-il dans les k
-- premiers résultats. C'est la mesure du problème réel — l'écran montre une
-- grille, la personne regarde les premiers, et le bon produit y est ou n'y
-- est pas. `recall@1` dit « le premier résultat était le bon », `recall@5`
-- « il était visible sans faire défiler ».
--
-- Le `MRR` (moyenne des inverses du rang) l'accompagne parce qu'il
-- distingue ce que `recall@5` confond : trouver en position 1 et trouver en
-- position 5 comptent pareil pour lui, pas pour la personne qui cherche.
--
-- ## Le piège à éviter
--
-- Si une photo sert à la fois à entraîner et à évaluer, le modèle la
-- reconnaît au lieu de généraliser, et la mesure annonce un succès qui ne
-- se reproduira pas en production. Les photos promues ici sont donc
-- **exclues de l'export d'entraînement** (`export_training_pairs`, en bas de
-- ce fichier) — une seule condition `not exists`, mais c'est elle qui rend
-- les chiffres dignes de confiance.

-- ---- le jeu d'évaluation --------------------------------------------------

create table public.ai_eval_examples (
  id uuid primary key default gen_random_uuid(),

  -- Dans le bucket `visual-search-queries` (`0086`) : ce sont de vraies
  -- photos de clients, promues depuis leurs recherches. Un jeu fabriqué par
  -- nous — produits photographiés proprement sur fond neutre — mesurerait
  -- un problème que personne n'a.
  image_path text not null,

  expected_product_id text not null references public.products (id) on delete cascade,

  -- `promoted` : issue d'une recherche réelle où la personne a ouvert ce
  -- produit. `manual` : ajoutée à la main, pour couvrir un cas que l'usage
  -- n'a pas encore produit (une catégorie nouvelle, un cas d'échec connu).
  source text not null check (source in ('promoted', 'manual')),

  note text,
  created_at timestamptz not null default now(),

  unique (image_path, expected_product_id)
);

alter table public.ai_eval_examples enable row level security;

-- Aucune policy : ni lecture ni écriture pour les clients. Le jeu
-- d'évaluation est un outil d'exploitation, et les photos qu'il référence
-- appartiennent à d'autres personnes.
grant select, insert, update, delete on public.ai_eval_examples to service_role;

-- L'empreinte de chaque photo d'évaluation, **par modèle**. C'est ce qui
-- permet de mesurer un modèle candidat entièrement en SQL : on calcule les
-- empreintes une fois, hors ligne, puis la comparaison ne coûte plus rien
-- et se rejoue autant de fois qu'on veut (seuil, k, filtres).
create table public.ai_eval_embeddings (
  example_id uuid not null references public.ai_eval_examples (id) on delete cascade,
  model text not null references public.ai_models (name) on update cascade,
  embedding extensions.vector(1024) not null,
  dim integer not null,
  created_at timestamptz not null default now(),
  primary key (example_id, model)
);

alter table public.ai_eval_embeddings enable row level security;
grant select, insert, update, delete on public.ai_eval_embeddings to service_role;

-- ---- promouvoir des requêtes réelles au rang d'étalon --------------------

-- Une recherche où la personne a ouvert un résultat est, telle quelle, un
-- exemple d'évaluation : on connaît la photo et on connaît la réponse
-- attendue.
--
-- Un seul clic par requête est retenu — le premier. Deux produits ouverts
-- depuis la même photo veulent dire que la personne hésitait, et un étalon
-- se construit sur des cas nets.
create or replace function public.promote_queries_to_eval(p_limit integer default 50)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted integer;
begin
  insert into public.ai_eval_examples (image_path, expected_product_id, source, note)
  select q.image_path, c.product_id, 'promoted',
         'Promue depuis la recherche ' || q.id::text
    from public.visual_search_queries q
    join public.visual_search_clicks c on c.query_id = q.id
   where not exists (
           select 1 from public.ai_eval_examples e
            where e.image_path = q.image_path
         )
     -- Un seul clic sur cette requête : pas d'hésitation.
     and (select count(*) from public.visual_search_clicks c2 where c2.query_id = q.id) = 1
   order by q.created_at desc
   limit least(coalesce(p_limit, 50), 500)
  on conflict (image_path, expected_product_id) do nothing;

  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$$;

revoke all on function public.promote_queries_to_eval(integer) from public, anon, authenticated;
grant execute on function public.promote_queries_to_eval(integer) to service_role;

-- ---- la note d'un modèle --------------------------------------------------

-- Rejoue la recherche pour chaque photo d'évaluation et cherche le rang du
-- produit attendu.
--
-- Le seuil de similarité est volontairement à 0 ici, et pas à 0,25 comme en
-- production : on mesure la **capacité de classement** du modèle, pas le
-- réglage du seuil. Les deux se règlent séparément — un modèle peut bien
-- classer et mal se prêter à un seuil fixe, et confondre les deux fait
-- attribuer au modèle un défaut de réglage.
create or replace function public.evaluate_model_recall(
  p_model text,
  p_k integer default 5
) returns table (
  model text,
  examples integer,
  found integer,
  recall_at_k double precision,
  mrr double precision
)
language sql
stable
security definer
set search_path = public, extensions
as $$
  with ranked as (
    select
      ex.id as example_id,
      (
        select count(*) + 1
          from public.product_embeddings pe
          join public.products p on p.id = pe.product_id
         where pe.model = p_model
           and p.status = 'active'
           and p.is_supplier_verified
           -- Combien de produits sont **plus proches** que le bon : c'est
           -- la définition du rang, et elle se calcule sans trier.
           and (pe.embedding <=> ee.embedding)
               < (select pe2.embedding <=> ee.embedding
                    from public.product_embeddings pe2
                   where pe2.model = p_model
                     and pe2.product_id = ex.expected_product_id)
      ) as rank
      from public.ai_eval_examples ex
      join public.ai_eval_embeddings ee
        on ee.example_id = ex.id and ee.model = p_model
     -- Le produit attendu doit être indexé pour ce modèle, sinon la photo
     -- ne mesure rien : elle dit seulement que l'indexation est incomplète.
     where exists (
       select 1 from public.product_embeddings pe3
        where pe3.model = p_model and pe3.product_id = ex.expected_product_id
     )
  )
  select
    p_model,
    count(*)::integer,
    count(*) filter (where rank <= greatest(coalesce(p_k, 5), 1))::integer,
    (count(*) filter (where rank <= greatest(coalesce(p_k, 5), 1)))::double precision
      / nullif(count(*), 0),
    avg(1.0 / rank)::double precision
    from ranked;
$$;

revoke all on function public.evaluate_model_recall(text, integer) from public, anon, authenticated;
grant execute on function public.evaluate_model_recall(text, integer) to service_role;

-- ---- export du jeu d'entraînement ----------------------------------------

-- Ce que l'entraînement consomme, dans la forme où il le consomme.
--
-- Trois signaux, d'intensité croissante, et c'est volontaire : « a ouvert la
-- fiche » dit qu'un résultat était crédible, « a mis au panier » dit que
-- c'était le bon. Une perte contrastive peut pondérer ses paires ; si elle
-- traite tout pareil, le signal fort se noie dans le signal faible.
--
-- Les négatifs sont les candidats **proposés et non retenus** — les
-- négatifs difficiles dont `0086` explique la valeur. Ils arrivent déjà
-- classés par similarité décroissante : les premiers sont les plus
-- instructifs.
create or replace function public.export_training_pairs(
  p_since timestamptz default null,
  p_limit integer default 500
) returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(row order by created_at), '[]'::jsonb) from (
    select
      q.created_at,
      jsonb_build_object(
        'query_id', q.id,
        'image_path', q.image_path,
        'model', q.model,
        'created_at', q.created_at,
        'positives', coalesce((
          select jsonb_agg(distinct jsonb_build_object(
                   'product_id', pos.product_id,
                   'signal', pos.signal,
                   'weight', pos.weight
                 ))
            from (
              -- Clic explicite sur un résultat.
              select c.product_id, 'click' as signal, 1.0 as weight
                from public.visual_search_clicks c
               where c.query_id = q.id
              union all
              -- Mise au panier d'un candidat dans l'heure : l'intention la
              -- plus nette qu'on puisse observer sans attendre une
              -- commande. Déduit du journal d'activité (`0081`), déjà
              -- alimenté — rien de neuf à instrumenter.
              select a.product_id, 'cart_add', 3.0
                from public.user_activity_events a
               where a.user_id = q.user_id
                 and a.kind = 'cart_add'
                 and a.created_at between q.created_at and q.created_at + interval '1 hour'
                 and q.candidates @> jsonb_build_array(
                       jsonb_build_object('product_id', a.product_id))
            ) pos
        ), '[]'::jsonb),
        'negatives', coalesce((
          select jsonb_agg(cand.product_id order by cand.ord)
            from (
              select value ->> 'product_id' as product_id,
                     ordinality as ord
                from jsonb_array_elements(q.candidates) with ordinality
            ) cand
           where not exists (
             select 1 from public.visual_search_clicks c
              where c.query_id = q.id and c.product_id = cand.product_id
           )
        ), '[]'::jsonb)
      ) as row
      from public.visual_search_queries q
     where (p_since is null or q.created_at >= p_since)
       -- Une requête sans aucune étiquette n'apprend rien : ni paire
       -- positive, ni rien à quoi opposer les négatifs.
       and exists (select 1 from public.visual_search_clicks c where c.query_id = q.id)
       -- Le jeu d'évaluation reste hors de l'entraînement. Voir l'en-tête.
       and not exists (
         select 1 from public.ai_eval_examples e where e.image_path = q.image_path
       )
     order by q.created_at
     limit least(coalesce(p_limit, 500), 5000)
  ) s;
$$;

revoke all on function public.export_training_pairs(timestamptz, integer)
  from public, anon, authenticated;
grant execute on function public.export_training_pairs(timestamptz, integer) to service_role;

-- ---- état du dispositif ---------------------------------------------------

-- Une seule lecture pour savoir si l'entraînement est encore une idée ou
-- devient réalisable : combien d'exemples étiquetés, combien d'étalons,
-- quels modèles indexés.
--
-- Les seuils utiles, pour mémoire : en dessous de ~500 paires étiquetées, un
-- affinage sur-apprend et dégrade. Vers 2 000, il commence à battre le
-- modèle générique sur le domaine. C'est ce chiffre qu'il faut regarder
-- avant d'allumer un GPU.
create or replace function public.ai_training_readiness()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'labelled_queries', (
      select count(distinct c.query_id) from public.visual_search_clicks c
    ),
    'total_queries', (select count(*) from public.visual_search_queries),
    'eval_examples', (select count(*) from public.ai_eval_examples),
    'models', coalesce((
      select jsonb_agg(jsonb_build_object(
               'name', m.name,
               'role', m.role,
               'dim', m.dim,
               'provider', m.provider,
               'indexed_products', (
                 select count(*) from public.product_embeddings e where e.model = m.name
               )
             ) order by m.name)
        from public.ai_models m
    ), '[]'::jsonb),
    'indexable_products', (
      select count(*) from public.products p
       where p.status = 'active' and p.is_supplier_verified
         and coalesce(array_length(p.image_urls, 1), 0) > 0
    )
  );
$$;

revoke all on function public.ai_training_readiness() from public, anon, authenticated;
grant execute on function public.ai_training_readiness() to service_role;
