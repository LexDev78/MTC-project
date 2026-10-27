-- Garder de quoi entraîner un modèle plus tard.
--
-- C'est la seule partie de ce chantier qui soit **irréversible**. Les deux
-- autres (registre des modèles, jeu d'évaluation) peuvent s'ajouter
-- n'importe quand. Pas celle-ci : aujourd'hui une recherche par photo
-- calcule une empreinte, la compare, et jette la photo. Chaque recherche
-- qui passe sans être conservée est un exemple d'entraînement perdu pour
-- toujours — et un modèle maison ne se construit que là-dessus.
--
-- Ce qu'il faut pour entraîner, et qui est exactement ce que cette
-- migration retient :
--
--  * la photo de la requête — c'est l'entrée du modèle ;
--  * le produit que la personne a réellement ouvert — c'est l'étiquette.
--    Pas « le produit le plus proche selon Voyage » : cela n'apprendrait
--    qu'à imiter Voyage, erreurs comprises ;
--  * les autres produits proposés et **non** retenus. Ce sont les
--    « négatifs difficiles », et ils valent plus que des négatifs tirés au
--    hasard : un modèle apprend en séparant ce qui se ressemble, pas en
--    distinguant un pagne d'une brouette.
--
-- L'empreinte de la requête est conservée en plus de la photo. Elle ne sert
-- pas à l'entraînement (elle est propre au modèle du jour) mais à rejouer un
-- **classement** différent sur d'anciennes requêtes — changer le seuil, le
-- nombre de résultats, la pondération — sans repayer un appel au modèle.
--
-- ## Vie privée
--
-- On conserve des photos prises par des personnes. Elles sont dans un
-- bucket privé, illisible par tout compte client ; seule la clé de service
-- y accède. Elles s'effacent au bout de 180 jours, et chacun peut effacer
-- les siennes à la demande (`delete_my_visual_search_history`). 180 jours
-- plutôt que les 90 du journal d'activité parce qu'un jeu d'entraînement se
-- constitue lentement, et qu'une photo de produit engage moins que
-- l'historique de navigation. Si cet arbitrage doit changer, il tient en une
-- constante dans `prune_visual_search_queries`.

-- ---- où vivent les photos de requête -------------------------------------

-- Privé, contrairement à `review-media` (`0061`) qui accompagne un avis
-- public : une photo de recherche n'est destinée à personne d'autre qu'au
-- modèle. Même plafond que la fonction edge (4 Mo), pour que le refus arrive
-- avant le téléversement et non après.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'visual-search-queries', 'visual-search-queries', false, 4194304,
  array['image/jpeg', 'image/png', 'image/webp']
) on conflict (id) do nothing;

-- Aucune policy : ni lecture ni écriture pour `anon` et `authenticated`.
-- C'est la fonction edge, avec la clé de service, qui dépose la photo —
-- l'app ne la téléverse pas elle-même, elle l'envoie déjà dans le corps de
-- la requête de recherche. Laisser le client écrire dans ce bucket
-- ouvrirait la porte à y déposer n'importe quoi en dehors de toute
-- recherche.

-- ---- la requête et ce qu'elle a proposé ----------------------------------

create table public.visual_search_queries (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null references public.profiles (id) on delete cascade,

  image_path text not null,

  -- Quel modèle a répondu. Indispensable à la relecture : un classement
  -- médiocre n'a pas le même sens selon le modèle qui l'a produit.
  model text not null references public.ai_models (name) on update cascade,

  -- Rempli à 1024 comme le catalogue (`0085`). `null` accepté : une
  -- requête peut être conservée pour sa photo seule.
  embedding extensions.vector(1024),

  -- `[{"product_id": "...", "similarity": 0.42}, …]`, dans l'ordre rendu.
  -- Du jsonb plutôt qu'une table fille : on ne lit jamais ces lignes
  -- séparément, elles n'ont de sens qu'ensemble, et le rang est porté par
  -- la position dans le tableau.
  candidates jsonb not null default '[]'::jsonb,

  created_at timestamptz not null default now()
);

-- La seule lecture par le client : « mes recherches », du plus récent au
-- plus ancien. Sert aussi à la purge par âge.
create index visual_search_queries_user_idx
  on public.visual_search_queries (user_id, created_at desc);

create index visual_search_queries_created_idx
  on public.visual_search_queries (created_at);

alter table public.visual_search_queries enable row level security;

-- Voir ses propres recherches, et pouvoir les effacer. Aucune policy
-- d'insertion ni de mise à jour : écrire ici est réservé à la fonction edge
-- (clé de service). Si un client pouvait insérer, il pourrait fabriquer des
-- requêtes et des étiquettes — c'est-à-dire empoisonner le jeu
-- d'entraînement, et donc le modèle qu'on en tirera.
create policy "visual_search_queries_select_own" on public.visual_search_queries
  for select using (user_id = auth.uid());

create policy "visual_search_queries_delete_own" on public.visual_search_queries
  for delete using (user_id = auth.uid());

grant select, delete on public.visual_search_queries to authenticated;
grant select, insert, update, delete on public.visual_search_queries to service_role;

-- ---- l'étiquette ----------------------------------------------------------

-- Le produit effectivement ouvert depuis les résultats. C'est la donnée la
-- plus précieuse du dispositif : elle dit ce que la personne cherchait,
-- quand le modèle ne faisait que deviner.
create table public.visual_search_clicks (
  query_id uuid not null references public.visual_search_queries (id) on delete cascade,
  product_id text not null references public.products (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (query_id, product_id)
);

alter table public.visual_search_clicks enable row level security;

-- Lecture par le propriétaire de la requête, pas d'écriture directe :
-- l'insertion passe par `record_visual_search_click`, qui vérifie que le
-- produit figurait bien dans les résultats. Sans cette vérification,
-- n'importe qui pourrait associer n'importe quel produit à n'importe quelle
-- photo.
create policy "visual_search_clicks_select_own" on public.visual_search_clicks
  for select using (
    exists (
      select 1 from public.visual_search_queries q
       where q.id = query_id and q.user_id = auth.uid()
    )
  );

grant select on public.visual_search_clicks to authenticated;
grant select, insert, update, delete on public.visual_search_clicks to service_role;

-- ---- écriture de la requête ----------------------------------------------

-- Réservée à `service_role` : c'est la fonction edge qui appelle, elle seule
-- connaît l'empreinte et les candidats, et elle a déjà validé le jeton de
-- l'appelant. `p_user_id` est donc l'identité **vérifiée** transmise par la
-- fonction, pas une valeur venue du client.
create or replace function public.record_visual_search_query(
  p_user_id uuid,
  p_image_path text,
  p_model text,
  p_embedding real[],
  p_candidates jsonb
) returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_id uuid;
begin
  insert into public.visual_search_queries
    (user_id, image_path, model, embedding, candidates)
  values (
    p_user_id,
    p_image_path,
    p_model,
    case when p_embedding is null then null else public.pad_embedding(p_embedding) end,
    coalesce(p_candidates, '[]'::jsonb)
  )
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.record_visual_search_query(uuid, text, text, real[], jsonb)
  from public, anon, authenticated;
grant execute on function public.record_visual_search_query(uuid, text, text, real[], jsonb)
  to service_role;

-- ---- écriture de l'étiquette ---------------------------------------------

-- Appelée par l'app quand on ouvre un résultat. Deux vérifications, et la
-- seconde est celle qui compte : le produit doit avoir figuré dans les
-- candidats de cette requête. C'est ce qui empêche de fabriquer des
-- étiquettes arbitraires depuis un compte client ordinaire.
--
-- Silencieuse comme `log_activity_event` (`0081`) : ouvrir une fiche produit
-- doit réussir même si la trace échoue. Une étiquette perdue coûte un
-- exemple ; une erreur remontée à l'écran coûte la navigation.
create or replace function public.record_visual_search_click(
  p_query_id uuid,
  p_product_id text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return;
  end if;

  if not exists (
    select 1 from public.visual_search_queries q
     where q.id = p_query_id
       and q.user_id = auth.uid()
       and q.candidates @> jsonb_build_array(jsonb_build_object('product_id', p_product_id))
  ) then
    return;
  end if;

  insert into public.visual_search_clicks (query_id, product_id)
  values (p_query_id, p_product_id)
  on conflict (query_id, product_id) do nothing;
end;
$$;

revoke all on function public.record_visual_search_click(uuid, text) from public, anon;
grant execute on function public.record_visual_search_click(uuid, text) to authenticated;

-- ---- effacement ----------------------------------------------------------

-- Effacer ses propres photos de recherche. La policy `delete_own` suffirait
-- pour les lignes, mais pas pour les fichiers : il faut retirer les deux, et
-- une fonction est le seul endroit où l'on peut s'en assurer.
--
-- Réserve honnête : supprimer la ligne de `storage.objects` rend le fichier
-- inaccessible par l'API, mais sur l'hébergé le blob peut survivre dans le
-- stockage objet jusqu'à un nettoyage de niveau stockage. Pour une purge
-- réellement complète, passer par l'API Storage — `ml/purge_queries.py`.
create or replace function public.delete_my_visual_search_history()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_paths text[];
  v_deleted integer;
begin
  if auth.uid() is null then
    return 0;
  end if;

  select array_agg(image_path) into v_paths
    from public.visual_search_queries where user_id = auth.uid();

  delete from public.visual_search_queries where user_id = auth.uid();
  get diagnostics v_deleted = row_count;

  if v_paths is not null then
    delete from storage.objects
     where bucket_id = 'visual-search-queries' and name = any (v_paths);
  end if;

  return v_deleted;
end;
$$;

revoke all on function public.delete_my_visual_search_history() from public, anon;
grant execute on function public.delete_my_visual_search_history() to authenticated;

-- Purge par âge, appelée par la même tâche planifiée que
-- `prune_activity_events` (`0081`).
--
-- Les requêtes promues au jeu d'évaluation (`0087`) sont **conservées** :
-- c'est l'étalon qui sert à comparer les modèles, et le renouveler chaque
-- semestre reviendrait à changer la règle au milieu de la mesure.
create or replace function public.prune_visual_search_queries()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_retention interval := interval '180 days';
  v_paths text[];
  v_deleted integer;
begin
  select array_agg(q.image_path) into v_paths
    from public.visual_search_queries q
   where q.created_at < now() - v_retention
     and not exists (
       select 1 from public.ai_eval_examples e where e.image_path = q.image_path
     );

  delete from public.visual_search_queries q
   where q.created_at < now() - v_retention
     and not exists (
       select 1 from public.ai_eval_examples e where e.image_path = q.image_path
     );
  get diagnostics v_deleted = row_count;

  if v_paths is not null then
    delete from storage.objects
     where bucket_id = 'visual-search-queries' and name = any (v_paths);
  end if;

  return v_deleted;
end;
$$;

revoke all on function public.prune_visual_search_queries() from public, anon, authenticated;
