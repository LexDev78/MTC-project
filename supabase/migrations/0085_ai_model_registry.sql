-- Deux modèles dans la même base, pour que changer de modèle cesse d'être un
-- pari.
--
-- `0081` a figé une hypothèse qui tenait tant qu'il n'y avait qu'un modèle :
-- `product_embeddings` a `product_id` pour clé primaire, donc **une seule
-- empreinte par produit**. Tant qu'on appelle Voyage, c'est juste. Le jour
-- où l'on veut comparer un modèle maison au modèle externe, cette clé
-- interdit la seule méthode honnête : indexer le catalogue avec les deux,
-- mesurer, puis basculer. Elle impose à la place de remplacer les vecteurs
-- en place et de découvrir après coup si le nouveau modèle est meilleur —
-- sans moyen de revenir en arrière autrement qu'en repayant une indexation
-- complète.
--
-- D'où ce fichier : la clé devient (produit, modèle), et un registre dit
-- lequel sert. Le reste de l'application ne change pas — elle envoie une
-- photo, elle reçoit des produits.
--
-- ## Pourquoi une seule colonne vectorielle suffit pour tous les modèles
--
-- Un modèle maison ne sortira pas 1024 dimensions. EmbeddingGemma 2 en sort
-- 768, un CLIP affiné 512 ou 768. La colonne est typée `vector(1024)` et un
-- type pgvector ne se négocie pas par ligne.
--
-- On complète donc les vecteurs plus courts par des zéros. Ce n'est pas un
-- bricolage : **le remplissage par zéros ne change pas la similarité
-- cosinus**. Si a' = [a, 0…0] et b' = [b, 0…0], alors a'·b' = a·b, ‖a'‖ =
-- ‖a‖ et ‖b'‖ = ‖b‖ — donc cos(a',b') = cos(a,b). L'égalité est exacte en
-- arithmétique réelle ; en `float32`, l'ordre d'accumulation introduit un
-- écart de l'ordre de 1e-7 — la précision du type lui-même, très loin de ce
-- qui déplacerait un classement. Un modèle 768 rempli à 1024 donne donc les
-- mêmes résultats qu'en 768 natif, pour le seul coût de l'espace disque.
--
-- Tronquer, en revanche, change le vecteur. Un modèle au-delà de 1024
-- dimensions demandera donc une vraie migration, et `pad_embedding` le dit
-- au lieu de couper en silence.
--
-- Comparer deux modèles entre eux n'aurait aucun sens — leurs espaces sont
-- indépendants. La clé primaire composite et le filtre `model` des
-- fonctions de recherche sont là pour que cela ne puisse pas arriver par
-- accident.

-- ---- registre des modèles -------------------------------------------------

create table public.ai_models (
  name text primary key,

  -- `check` plutôt qu'un enum, comme `user_activity_events.kind` (`0081`) :
  -- un second usage (reclassement, description automatique) ne doit pas
  -- demander un `alter type`.
  kind text not null check (kind in ('embedding')),

  -- Dimension **native** du modèle, avant remplissage. C'est elle qui dit
  -- combien de valeurs un vecteur de ce modèle doit porter : une sortie de
  -- taille inattendue signale un changement de modèle côté fournisseur, et
  -- on préfère le refus à un vecteur silencieusement faux.
  dim integer not null check (dim between 2 and 1024),

  provider text not null check (provider in ('voyage', 'self_hosted')),

  -- `serving` : celui qui répond aux clients. `candidate` : indexé en
  -- parallèle, mesuré, invisible pour l'app. `retired` : gardé pour
  -- pouvoir revenir en arrière sans réindexer.
  role text not null check (role in ('serving', 'candidate', 'retired')),

  notes text,
  created_at timestamptz not null default now()
);

-- Un seul modèle servant par usage, garanti par la base et non par
-- convention : deux modèles `serving` et la recherche répondrait tantôt
-- l'un tantôt l'autre, sans que rien ne le signale.
create unique index ai_models_single_serving_idx
  on public.ai_models (kind) where role = 'serving';

alter table public.ai_models enable row level security;

-- Lisible par tous les comptes connectés : l'app n'en a pas besoin
-- aujourd'hui, mais un écran de diagnostic ou un en-tête de résultats
-- (« reconnaissance v2 ») le lira, et un nom de modèle n'est pas un secret.
-- Aucune policy d'écriture : le registre se modifie par migration ou par
-- `service_role`, c'est-à-dire par l'exploitant.
create policy "ai_models_select_all" on public.ai_models
  for select to authenticated using (true);

grant select on public.ai_models to authenticated;
grant select, insert, update, delete on public.ai_models to service_role;

insert into public.ai_models (name, kind, dim, provider, role, notes) values (
  'voyage-multimodal-3.5', 'embedding', 1024, 'voyage', 'serving',
  'Modèle externe de départ. Facturé à l''appel, clé côté serveur uniquement.'
);

-- ---- quel modèle sert -----------------------------------------------------

-- Lu par les fonctions edge au lieu d'être codé dans leur source : basculer
-- sur un autre modèle devient une ligne de SQL, pas un redéploiement — et
-- le retour en arrière la même.
create or replace function public.serving_embedding_model()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select name from public.ai_models
   where kind = 'embedding' and role = 'serving'
   limit 1;
$$;

revoke all on function public.serving_embedding_model() from public, anon;
grant execute on function public.serving_embedding_model() to authenticated, service_role;

-- ---- remplissage ----------------------------------------------------------

-- Porte la règle expliquée en tête de fichier, en un seul endroit : aucune
-- fonction d'écriture ne doit pouvoir l'oublier.
create or replace function public.pad_embedding(
  p_values real[],
  p_target integer default 1024
) returns extensions.vector
language plpgsql
immutable
set search_path = public, extensions
as $$
declare
  v_dim integer := coalesce(array_length(p_values, 1), 0);
begin
  if v_dim = 0 then
    raise exception 'Empreinte vide : rien à enregistrer.';
  end if;

  -- Tronquer changerait le vecteur, donc les classements, donc les
  -- mesures — en silence. Mieux vaut un échec visible et une migration.
  if v_dim > p_target then
    raise exception
      'Empreinte de % dimensions pour une colonne de % : tronquer changerait le vecteur, il faut élargir la colonne.',
      v_dim, p_target;
  end if;

  if v_dim = p_target then
    return p_values::extensions.vector;
  end if;
  return (p_values || array_fill(0::real, array[p_target - v_dim]))::extensions.vector;
end;
$$;

revoke all on function public.pad_embedding(real[], integer) from public, anon, authenticated;
grant execute on function public.pad_embedding(real[], integer) to service_role;

-- ---- une empreinte par (produit, modèle) ---------------------------------

alter table public.product_embeddings
  drop constraint product_embeddings_pkey;

alter table public.product_embeddings
  -- Dimension native du vecteur avant remplissage. Sans elle, impossible de
  -- distinguer un modèle 768 d'un modèle 1024 dont les 256 dernières
  -- valeurs seraient nulles.
  add column dim integer not null default 1024,
  add constraint product_embeddings_pkey primary key (product_id, model),
  add constraint product_embeddings_model_fkey
    foreign key (model) references public.ai_models (name) on update cascade;

-- Le registre comme garde-fou : une faute de frappe dans le nom du modèle
-- créerait un troisième espace vectoriel, qui ne ressortirait jamais d'une
-- recherche et ne manquerait à personne — le pire des échecs, celui qui ne
-- se voit pas.

-- L'index cosinus de `0081` reste valable : il ordonne, le `where model`
-- filtre. Tant qu'un modèle domine la table, c'est le bon compromis.
--
-- Quand deux modèles y tiennent une part comparable, la recherche filtrée
-- parcourt un graphe où la moitié des voisins appartient à l'autre espace
-- et peut rendre moins de lignes que demandé. Le remède est un index
-- partiel par modèle, à poser hors transaction (voir
-- `supabase/production/indexes_concurrently.sql`) :
--
--   create index concurrently product_embeddings_<slug>_cosine_idx
--     on public.product_embeddings using hnsw (embedding extensions.vector_cosine_ops)
--     where model = '<nom>';

-- ---- écriture et lecture, par modèle --------------------------------------

-- Les signatures changent : `real[]` au lieu de `vector(1024)`, et le modèle
-- devient un paramètre. On supprime les anciennes au lieu de les surcharger
-- — deux fonctions de même nom aux paramètres homonymes rendent la
-- résolution PostgREST ambiguë, et l'erreur ne se verrait qu'à l'appel.
drop function if exists public.upsert_product_embedding(text, extensions.vector, text, text);
drop function if exists public.search_products_by_embedding(extensions.vector, integer, double precision);
drop function if exists public.products_needing_embedding(integer);

create or replace function public.upsert_product_embedding(
  p_product_id text,
  p_embedding real[],
  p_model text,
  p_source_image_url text
) returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_dim integer := coalesce(array_length(p_embedding, 1), 0);
  v_expected integer;
begin
  select dim into v_expected from public.ai_models
   where name = p_model and kind = 'embedding';
  if v_expected is null then
    raise exception 'Modèle inconnu du registre : % (voir public.ai_models).', p_model;
  end if;

  -- Un modèle qui change sa sortie sans changer de nom est un piège : les
  -- anciens vecteurs et les nouveaux cohabiteraient dans la même colonne
  -- sans être comparables.
  if v_dim <> v_expected then
    raise exception
      'Le modèle % est déclaré à % dimensions, le vecteur en porte %.',
      p_model, v_expected, v_dim;
  end if;

  insert into public.product_embeddings
    (product_id, model, dim, embedding, source_image_url, updated_at)
  values (
    p_product_id, p_model, v_dim,
    public.pad_embedding(p_embedding), p_source_image_url, now()
  )
  on conflict (product_id, model) do update
     set embedding = excluded.embedding,
         dim = excluded.dim,
         source_image_url = excluded.source_image_url,
         updated_at = now();
end;
$$;

revoke all on function public.upsert_product_embedding(text, real[], text, text)
  from public, anon, authenticated;
grant execute on function public.upsert_product_embedding(text, real[], text, text)
  to service_role;

-- Reprend `0084` avec deux changements : le vecteur arrive en `real[]` (donc
-- rempli ici) et la recherche est cantonnée à un modèle. Le reste — filtres
-- de visibilité, seuil, plafond — est inchangé, et pour les mêmes raisons.
create or replace function public.search_products_by_embedding(
  p_embedding real[],
  p_model text default null,
  p_limit integer default 24,
  p_min_similarity double precision default 0.25
) returns table (product_id text, similarity double precision)
language sql
stable
security definer
set search_path = public, extensions
as $$
  with q as (
    select public.pad_embedding(p_embedding) as vec,
           coalesce(p_model, public.serving_embedding_model()) as model
  )
  select e.product_id, 1 - (e.embedding <=> q.vec) as similarity
    from public.product_embeddings e
    join public.products p on p.id = e.product_id
   cross join q
   where e.model = q.model
     and p.status = 'active'
     and p.is_supplier_verified
     and 1 - (e.embedding <=> q.vec) >= p_min_similarity
   order by e.embedding <=> q.vec
   limit least(coalesce(p_limit, 24), 50);
$$;

revoke all on function public.search_products_by_embedding(real[], text, integer, double precision)
  from public, anon, authenticated;
grant execute on function public.search_products_by_embedding(real[], text, integer, double precision)
  to service_role;

-- « À indexer » devient une question par modèle : un catalogue entièrement
-- indexé pour Voyage est entièrement à indexer pour un modèle candidat.
-- C'est ce qui permet de préparer la bascule en tâche de fond, sans toucher
-- à ce qui sert.
create or replace function public.products_needing_embedding(
  p_limit integer default 50,
  p_model text default null
)
returns table (product_id text, name text, description text, image_url text)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.name, p.description, p.image_urls[1]
    from public.products p
    left join public.product_embeddings e
      on e.product_id = p.id
     and e.model = coalesce(p_model, public.serving_embedding_model())
   where p.status = 'active'
     and p.is_supplier_verified
     and coalesce(array_length(p.image_urls, 1), 0) > 0
     and (e.product_id is null or e.source_image_url is distinct from p.image_urls[1])
   order by p.created_at desc
   limit least(coalesce(p_limit, 50), 200);
$$;

revoke all on function public.products_needing_embedding(integer, text)
  from public, anon, authenticated;
grant execute on function public.products_needing_embedding(integer, text) to service_role;
