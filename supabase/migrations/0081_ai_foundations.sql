-- Socle commun aux deux fonctionnalités d'IA : le journal d'activité qui
-- nourrit les suggestions, et l'espace vectoriel qui portera la recherche
-- par photo.
--
-- Pourquoi un journal, alors que `products.view_count` existe déjà (`0014`) ?
-- Parce que ce compteur est un **agrégat** : il dit qu'un produit a été vu
-- 340 fois, jamais *par qui*. Or « proposer selon l'activité de
-- l'utilisateur » demande exactement l'inverse — la trace par personne. Les
-- deux cohabitent : le compteur reste la métrique du fournisseur, le journal
-- devient la mémoire du client.
--
-- Trois tables, trois durées de vie différentes :
--
--  * `user_activity_events` — éphémère. 90 jours, puis effacé : au-delà, un
--    produit consulté ne dit plus rien des envies du moment, et conserver
--    indéfiniment la navigation de quelqu'un est un risque qu'aucune
--    suggestion ne justifie.
--  * `ai_usage_counters` — journalier. Un appel d'IA coûte de l'argent à
--    chaque photo ; sans plafond par compte, un client (ou un script) vide
--    le budget du mois en une après-midi.
--  * `product_embeddings` — durable, et **jamais lisible par un client**.
--    Aucune policy de lecture : les vecteurs ne sortent pas de la base, les
--    comparaisons se font dans les fonctions ci-dessous. Exposer la table
--    livrerait l'empreinte de tout le catalogue à qui sait lire du JSON,
--    pour un bénéfice nul côté application — même raisonnement que les
--    codes promo non énumérables (`0071`).

create extension if not exists vector with schema extensions;

-- Pour la recherche texte : `unaccent` fait correspondre « bogolan » à
-- « bògòlan », `pg_trgm` rattrape les fautes de frappe. La recherche actuelle
-- est un `ilike` strict (`supabase_product_datasource.dart`) qui rate les
-- deux ; ils sont posés ici parce que la recherche par photo retombe sur une
-- recherche texte avec les mots-clés détectés, et doit tolérer la même
-- approximation.
create extension if not exists unaccent with schema extensions;
create extension if not exists pg_trgm with schema extensions;

-- ---- journal d'activité ---------------------------------------------------

create table public.user_activity_events (
  id bigserial primary key,

  -- Posé par `log_activity_event`, jamais par l'app : voir la fonction.
  user_id uuid not null references public.profiles (id) on delete cascade,

  -- Volontairement un `check` et non un `enum` : ajouter un signal plus tard
  -- ne doit pas demander un `alter type` (qui ne peut pas tourner dans la
  -- même transaction que son usage sur certaines versions).
  kind text not null check (kind in ('product_view', 'search', 'category_open', 'cart_add')),

  -- Un seul des trois est renseigné, selon `kind`. `on delete cascade` sur le
  -- produit : un produit retiré du catalogue ne doit pas laisser de trace qui
  -- le ferait ressortir en suggestion.
  product_id text references public.products (id) on delete cascade,
  category text,
  query text check (query is null or length(query) <= 120),

  created_at timestamptz not null default now(),

  constraint activity_payload_matches_kind check (
    case kind
      when 'product_view'  then product_id is not null
      when 'cart_add'      then product_id is not null
      when 'category_open' then category is not null
      when 'search'        then query is not null
    end
  )
);

-- L'index sert la seule lecture qui existe : « les N derniers événements de
-- cette personne ». `created_at desc` dans l'index évite le tri.
create index user_activity_recent_idx
  on public.user_activity_events (user_id, created_at desc);

-- Pour la jointure de co-achat et le nettoyage par âge.
create index user_activity_product_idx
  on public.user_activity_events (product_id) where product_id is not null;

alter table public.user_activity_events enable row level security;

-- Lecture de sa propre trace uniquement — un client doit pouvoir savoir ce
-- que l'application retient de lui. Pas de policy d'écriture du tout :
-- l'insertion passe par `log_activity_event`, qui estampille `user_id`
-- lui-même. Sans ça, n'importe quelle session pourrait écrire des
-- événements au nom d'un autre compte et téléguider ses suggestions.
create policy "activity_select_own" on public.user_activity_events
  for select using (user_id = auth.uid());

-- ---- plafonds d'appels d'IA ----------------------------------------------

create table public.ai_usage_counters (
  user_id uuid not null references public.profiles (id) on delete cascade,
  feature text not null check (feature in ('visual_search')),
  day date not null default current_date,
  calls integer not null default 0,
  primary key (user_id, feature, day)
);

alter table public.ai_usage_counters enable row level security;

-- Lecture seule, et de son propre compteur : l'écran de recherche par photo
-- affiche « 7 recherches restantes aujourd'hui » plutôt que de laisser le
-- client découvrir le plafond en se faisant refuser.
create policy "ai_usage_select_own" on public.ai_usage_counters
  for select using (user_id = auth.uid());

-- ---- empreintes de produits ----------------------------------------------

create table public.product_embeddings (
  product_id text primary key references public.products (id) on delete cascade,

  -- 1024 dimensions : la sortie par défaut de `voyage-multimodal-3.5`, le
  -- modèle retenu (Anthropic ne publie pas d'API d'embeddings et renvoie
  -- vers Voyage AI). Figé dans le type de la colonne — changer de modèle
  -- pour une autre dimension demandera une migration, ce qui est préférable
  -- à une table qui accepte silencieusement deux espaces vectoriels
  -- incomparables.
  embedding extensions.vector(1024) not null,

  -- Quel modèle a produit ce vecteur, et depuis quelle image. Les deux
  -- servent au ré-indexage : quand le modèle change ou que le fournisseur
  -- remplace sa photo, on sait quelles lignes sont périmées.
  model text not null,
  source_image_url text not null,

  updated_at timestamptz not null default now()
);

-- HNSW plutôt qu'IVFFlat : il ne demande pas de choisir un nombre de listes
-- à l'avance (donc pas de ré-indexage quand le catalogue grossit) et reste
-- correct sur une table encore petite, là où IVFFlat dégrade tant qu'il n'a
-- pas assez de lignes par liste. `cosine` parce que les vecteurs Voyage sont
-- normalisés : la distance cosinus y est la mesure prévue.
create index product_embeddings_cosine_idx
  on public.product_embeddings
  using hnsw (embedding extensions.vector_cosine_ops);

alter table public.product_embeddings enable row level security;

-- Aucune policy, délibérément : ni lecture ni écriture pour les clients.
-- `service_role` (la fonction edge qui indexe) contourne la RLS, et les
-- comparaisons passent par des fonctions `security definer`.

-- ---- écriture du journal --------------------------------------------------

-- `security definer` pour la même raison que `increment_product_view`
-- (`0014`) : l'app n'a aucun droit d'écriture sur la table, et c'est la
-- fonction qui pose `user_id` depuis `auth.uid()`. Un client ne peut donc
-- décrire que sa propre activité.
--
-- Silencieuse par construction : un `return` plutôt qu'un `raise` quand
-- l'appelant n'est pas connecté ou que le produit n'existe plus. Journaliser
-- est un effet de bord du parcours, jamais sa raison d'être — une trace qui
-- échoue ne doit pas faire remonter une erreur sur une fiche produit qui,
-- elle, s'est affichée correctement.
create or replace function public.log_activity_event(
  p_kind text,
  p_product_id text default null,
  p_category text default null,
  p_query text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    return;
  end if;

  -- Le produit a pu disparaître entre l'affichage et l'appel.
  if p_product_id is not null
     and not exists (select 1 from public.products where id = p_product_id) then
    return;
  end if;

  insert into public.user_activity_events (user_id, kind, product_id, category, query)
  values (
    v_user_id,
    p_kind,
    p_product_id,
    p_category,
    -- Tronqué plutôt que rejeté : la contrainte de longueur protège la
    -- table, elle n'a pas à faire échouer une recherche un peu longue.
    case when p_query is null then null else left(btrim(p_query), 120) end
  );
exception
  -- `p_kind` inconnu, incohérence payload/kind : la trace est perdue, le
  -- parcours continue.
  when check_violation then return;
end;
$$;

revoke all on function public.log_activity_event(text, text, text, text) from public, anon;
grant execute on function public.log_activity_event(text, text, text, text) to authenticated;

-- ---- consommation d'un appel d'IA ----------------------------------------

-- Incrémente et tranche en une seule instruction : le `on conflict` rend
-- l'opération atomique, donc deux photos envoyées en même temps ne peuvent
-- pas lire le même compteur et dépasser le plafond à deux (la course que
-- `0080` a dû corriger ailleurs).
--
-- Renvoie le nombre d'appels **restants**, ou -1 si le plafond est atteint.
-- Un entier plutôt qu'une exception : l'appelant affiche un message, il ne
-- gère pas un échec.
create or replace function public.consume_ai_quota(
  p_feature text,
  p_daily_limit integer default 20
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_calls integer;
begin
  if v_user_id is null then
    return -1;
  end if;

  insert into public.ai_usage_counters (user_id, feature, day, calls)
  values (v_user_id, p_feature, current_date, 1)
  on conflict (user_id, feature, day) do update
     set calls = public.ai_usage_counters.calls + 1
   where public.ai_usage_counters.calls < p_daily_limit
  returning calls into v_calls;

  -- Pas de ligne renvoyée = le `where` du `do update` a bloqué : plafond
  -- atteint.
  if v_calls is null then
    return -1;
  end if;

  return p_daily_limit - v_calls;
end;
$$;

revoke all on function public.consume_ai_quota(text, integer) from public, anon;
grant execute on function public.consume_ai_quota(text, integer) to authenticated;

-- ---- purge ----------------------------------------------------------------

-- Appelée par une tâche planifiée (pg_cron en hébergé), pas par un trigger :
-- supprimer à chaque insertion ferait payer le ménage à chaque consultation
-- de fiche. 90 jours, pour les raisons données en tête de fichier.
create or replace function public.prune_activity_events()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deleted integer;
begin
  delete from public.user_activity_events
   where created_at < now() - interval '90 days';
  get diagnostics v_deleted = row_count;

  -- Les compteurs d'hier ne servent plus : le plafond est journalier.
  delete from public.ai_usage_counters where day < current_date - 7;

  return v_deleted;
end;
$$;

revoke all on function public.prune_activity_events() from public, anon, authenticated;
