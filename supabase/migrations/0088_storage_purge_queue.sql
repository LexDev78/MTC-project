-- Supprimer un fichier ne se fait pas en SQL. Découvert par un test.
--
-- `0086` effaçait les photos de recherche en deux temps : la ligne de
-- `visual_search_queries`, puis la ligne de `storage.objects` correspondante.
-- Le second temps est refusé par la plateforme :
--
--   Direct deletion from storage tables is not allowed.
--   Use the Storage API instead. (42501)
--
-- Un garde-fou de Supabase, et un bon : supprimer la ligne laisserait le
-- blob orphelin dans le stockage objet, c'est-à-dire un fichier qui existe
-- encore mais dont plus rien ne garde la trace. Exactement le pire résultat
-- pour une fonction qui s'appelle « effacer mes photos ».
--
-- Mais le SQL reste le seul endroit où l'on sait **quoi** effacer, puisque
-- c'est lui qui connaît les règles (180 jours, sauf l'étalon ; tout, pour
-- qui le demande). Il enregistre donc l'intention, et un script qui parle à
-- l'API Storage l'exécute (`ml/purge_queries.py`).
--
-- Conséquence à assumer, et à dire : entre la demande et le passage du
-- script, le fichier existe encore. Il n'est accessible à personne — le
-- bucket est privé et sans policy client — mais il existe. Un effacement
-- vraiment immédiat demanderait que la base appelle une API HTTP, ce qui
-- ferait dépendre une suppression de la disponibilité d'un service.

create table public.storage_purge_queue (
  bucket_id text not null,
  object_path text not null,
  requested_at timestamptz not null default now(),
  primary key (bucket_id, object_path)
);

alter table public.storage_purge_queue enable row level security;

-- Aucune policy : la file est un outil d'exploitation. Les chemins qu'elle
-- contient appartiennent à des personnes dont ce n'est pas l'affaire.
grant select, insert, update, delete on public.storage_purge_queue to service_role;

create index storage_purge_queue_requested_idx
  on public.storage_purge_queue (requested_at);

-- ---- effacement à la demande ---------------------------------------------

-- Reprend `0086` : les lignes disparaissent tout de suite — c'est ce que la
-- personne demande et c'est ce qui la fait disparaître de toute lecture — et
-- les fichiers passent par la file.
create or replace function public.delete_my_visual_search_history()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deleted integer;
begin
  if auth.uid() is null then
    return 0;
  end if;

  -- L'inscription en file **avant** la suppression : après, les chemins
  -- seraient perdus, et avec eux la seule trace de ce qu'il reste à
  -- effacer.
  insert into public.storage_purge_queue (bucket_id, object_path)
  select 'visual-search-queries', q.image_path
    from public.visual_search_queries q
   where q.user_id = auth.uid()
  on conflict (bucket_id, object_path) do nothing;

  delete from public.visual_search_queries where user_id = auth.uid();
  get diagnostics v_deleted = row_count;

  return v_deleted;
end;
$$;

revoke all on function public.delete_my_visual_search_history() from public, anon;
grant execute on function public.delete_my_visual_search_history() to authenticated;

-- ---- purge par âge --------------------------------------------------------

create or replace function public.prune_visual_search_queries()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_retention interval := interval '180 days';
  v_deleted integer;
begin
  insert into public.storage_purge_queue (bucket_id, object_path)
  select 'visual-search-queries', q.image_path
    from public.visual_search_queries q
   where q.created_at < now() - v_retention
     -- L'étalon est conservé : le renouveler reviendrait à changer la règle
     -- au milieu de la mesure.
     and not exists (
       select 1 from public.ai_eval_examples e where e.image_path = q.image_path
     )
  on conflict (bucket_id, object_path) do nothing;

  delete from public.visual_search_queries q
   where q.created_at < now() - v_retention
     and not exists (
       select 1 from public.ai_eval_examples e where e.image_path = q.image_path
     );
  get diagnostics v_deleted = row_count;

  return v_deleted;
end;
$$;

revoke all on function public.prune_visual_search_queries() from public, anon, authenticated;

-- ---- remise à zéro entre deux tests --------------------------------------

-- `test_reset_and_seed()` repose sur un `truncate auth.users … cascade` :
-- tout ce qui pend à un compte ou à un produit disparaît avec lui. Les
-- requêtes conservées, leurs étiquettes, l'étalon et les empreintes sont
-- donc nettoyés sans rien ajouter.
--
-- Deux tables échappent à cette chaîne, faute de clé étrangère vers un
-- compte : la file de purge, et le registre des modèles. Sans ce
-- complément, un test qui vérifie le **contenu** de la file y trouverait
-- aussi ce que l'exécution précédente y a laissé — il passerait aujourd'hui
-- et échouerait au prochain test qui met un autre chemin en file.
create or replace function public.test_reset_ai_scratch()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- `where true` et non un `delete` nu : la plateforme refuse un DELETE
  -- sans clause WHERE (« DELETE requires a WHERE clause », 21000), garde-fou
  -- qui vaut aussi à l'intérieur d'une fonction.
  delete from public.storage_purge_queue where true;

  -- Les modèles fabriqués par les tests, et eux seuls : le modèle en
  -- service est posé par migration et doit survivre.
  --
  -- Les `not exists` ne sont pas de la prudence superflue : ils rendent la
  -- fonction indifférente à l'ordre d'appel. Appelée avant le `truncate`,
  -- elle ne ferait rien ; appelée après, elle nettoie. Dans les deux cas
  -- elle ne peut pas échouer sur une clé étrangère et faire tomber toute
  -- une suite pour une ligne de décor.
  delete from public.ai_models m
   where m.role <> 'serving'
     and not exists (
       select 1 from public.product_embeddings e where e.model = m.name
     )
     and not exists (
       select 1 from public.ai_eval_embeddings e where e.model = m.name
     )
     and not exists (
       select 1 from public.visual_search_queries q where q.model = m.name
     );
end;
$$;

revoke all on function public.test_reset_ai_scratch() from public, anon, authenticated;
-- Le harnais appelle avec la clé de service : `revoke … from public` lui
-- retire aussi le droit par défaut, d'où ce grant explicite — la convention
-- des autres aides de test (`0002`, `0004`, `0022`).
grant execute on function public.test_reset_ai_scratch() to service_role;
