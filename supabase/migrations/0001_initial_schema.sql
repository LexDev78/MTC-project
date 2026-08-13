-- MTC — schéma initial (Lot 1 de BACKEND_MIGRATION_PROGRESS.md)
-- Voir /Users/solomon/.claude/plans/purrfect-swimming-fog.md pour le détail
-- des décisions d'architecture. Toutes les tables sauf `tracking` (jamais
-- persisté, simulation live côté Dart) sont créées ici.
--
-- Conventions :
--   - `profiles.id` et `suppliers.id` sont des `uuid` (= `auth.users.id`
--     pour un fournisseur tiers ; un uuid fixe pour le storefront MTC
--     partagé — voir `operating_supplier_id()` plus bas).
--   - Toutes les autres entités métier gardent des id `text`, fournis par
--     l'app (`IdGenerator.next()`, déjà au format uuid-v4, ou un slug
--     littéral pour les données de seed) — jamais générés par la base.
--   - Les valeurs d'enum sont en snake_case ; le mapping vers les enums
--     Dart (camelCase) se fait via `@JsonValue` au Lot 2.

create extension if not exists pgcrypto;

-- ============================================================================
-- 1. Enums
-- ============================================================================

create type public.account_role as enum ('client', 'supplier_tiers', 'supplier_principal');
create type public.verification_status as enum ('unverified', 'pending', 'verified', 'rejected');
create type public.staff_role as enum ('agent', 'admin');
create type public.supplier_legal_type as enum ('company', 'individual');
create type public.supplier_type as enum ('tiers', 'principal');

create type public.product_category as enum (
  'textiles_bogolan', 'artisanat', 'electronique', 'alimentation',
  'materiaux_construction', 'autre'
);
create type public.product_region as enum ('chine', 'europe', 'afrique_hors_mali', 'mali', 'autre');
create type public.product_status as enum ('draft', 'active', 'paused', 'archived');
create type public.stock_movement_reason as enum (
  'manual_adjustment', 'sale', 'restock', 'returned', 'correction'
);

create type public.order_status as enum (
  'pending', 'confirmed', 'preparing', 'in_transit', 'delivered', 'cancelled'
);
create type public.delivery_mode as enum ('self_delivery', 'mtc_delivery');
create type public.cancelled_by as enum ('client', 'supplier', 'mtc');
create type public.fulfillment_method as enum ('pickup_point', 'home_delivery');
create type public.supplier_message_type as enum ('none', 'text', 'voice');
create type public.payment_method as enum ('now', 'on_delivery');
create type public.payment_status as enum ('paid', 'pending_on_delivery');
create type public.mobile_money_provider as enum ('orange_money', 'moov_money');

create type public.chat_attachment_type as enum ('none', 'image', 'voice');
create type public.comment_attachment_type as enum ('none', 'image', 'voice');

create type public.kyc_review_status as enum (
  'draft', 'submitted', 'under_review', 'approved', 'rejected'
);
create type public.supplier_document_type as enum (
  'rccm_certificate', 'entreprenant_declaration', 'articles_of_association',
  'tax_id', 'manager_id_card', 'proof_of_address', 'national_id_front',
  'national_id_back', 'selfie_with_id'
);

create type public.notification_type as enum (
  'new_order', 'new_message', 'low_stock', 'kyc_decision', 'payout_decision', 'new_review'
);
create type public.payout_status as enum ('requested', 'processing', 'paid', 'rejected');

-- ============================================================================
-- 2. Tables
-- ============================================================================

-- ---- profiles --------------------------------------------------------------
-- Créée par `handle_new_user()` (déclenché sur `auth.users`), jamais insérée
-- directement par l'app. `default_address_id` référence `addresses` ajoutée
-- après la création de cette table (dépendance croisée).
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role public.account_role not null,
  username_or_phone text not null unique,
  display_name text not null,
  phone_number text not null,
  created_at timestamptz not null default now(),
  default_address_id text,
  staff_role public.staff_role,
  constraint staff_role_matches_role check ((role = 'supplier_principal') = (staff_role is not null))
);

-- ---- suppliers --------------------------------------------------------------
-- Pour un fournisseur tiers, `id == profiles.id` (posé par `handle_new_user`).
-- Le storefront MTC (`supplier_type = 'principal'`) est le seul `id` non lié
-- à un `profiles.id` précis — partagé par tout le staff (agents/admins).
create table public.suppliers (
  id uuid primary key,
  business_name text not null,
  supplier_type public.supplier_type not null,
  city text not null,
  rating_average double precision not null default 0,
  rating_count integer not null default 0,
  product_count integer not null default 0,
  verification_status public.verification_status,
  avatar_url text,
  legal_type public.supplier_legal_type,
  description text,
  banner_url text,
  full_address text,
  address_latitude double precision,
  address_longitude double precision,
  public_phone_numbers text[] not null default '{}',
  delivery_zones text[] not null default '{}',
  opening_hours_label text,
  is_open boolean not null default true
);

-- ---- addresses --------------------------------------------------------------
create table public.addresses (
  id text primary key default gen_random_uuid()::text,
  user_id uuid not null references public.profiles (id) on delete cascade,
  label text not null,
  city text not null,
  details text not null,
  latitude double precision not null,
  longitude double precision not null
);

alter table public.profiles
  add constraint profiles_default_address_id_fkey
  foreign key (default_address_id) references public.addresses (id) on delete set null;

-- ---- products / stock -------------------------------------------------------
create table public.products (
  id text primary key,
  supplier_id uuid not null references public.suppliers (id),
  supplier_name text not null,
  supplier_type public.supplier_type not null,
  name text not null,
  description text not null,
  category public.product_category not null,
  price_fcfa integer not null,
  stock_quantity integer not null,
  image_urls text[] not null default '{}',
  city text not null,
  rating_average double precision not null default 0,
  rating_count integer not null default 0,
  allows_self_delivery boolean not null default true,
  allows_mtc_delivery boolean not null default true,
  created_at timestamptz not null default now(),
  weight_kg double precision not null,
  is_supplier_verified boolean not null default true,
  sizes text[] not null default '{}',
  colors text[] not null default '{}',
  region public.product_region not null default 'mali',
  status public.product_status not null default 'active',
  low_stock_threshold integer,
  compare_at_price_fcfa integer
);

create table public.stock_movements (
  id text primary key,
  product_id text not null references public.products (id) on delete cascade,
  quantity_delta integer not null,
  reason public.stock_movement_reason not null,
  occurred_at timestamptz not null default now(),
  note text
);

-- ---- cart / favorites ---------------------------------------------------
create table public.cart_items (
  id text primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  product_id text not null references public.products (id) on delete cascade,
  supplier_id uuid not null references public.suppliers (id),
  product_name_snapshot text not null,
  unit_price_fcfa_snapshot integer not null,
  quantity integer not null,
  added_at timestamptz not null default now()
);

create table public.favorites (
  id text primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  product_id text not null references public.products (id) on delete cascade,
  created_at timestamptz not null default now()
);

-- ---- orders -------------------------------------------------------------
create table public.orders (
  id text primary key,
  client_id uuid not null references public.profiles (id),
  client_display_name_snapshot text not null,
  client_phone_snapshot text not null,
  status public.order_status not null,
  placed_at timestamptz not null default now(),
  total_fcfa integer not null,
  delivery_address_label text not null,
  delivery_city text not null,
  delivery_details text not null,
  delivery_latitude double precision not null,
  delivery_longitude double precision not null,
  fulfillment_method public.fulfillment_method not null default 'home_delivery',
  courier_phone text,
  alternate_phone text,
  delivery_date timestamptz,
  delivery_time_slot_label text,
  is_priority boolean not null default false,
  priority_fee_fcfa integer not null default 0,
  supplier_message_type public.supplier_message_type not null default 'none',
  supplier_message_text text,
  supplier_message_voice_path text,
  supplier_message_voice_duration_seconds integer,
  payment_method public.payment_method not null default 'on_delivery',
  payment_status public.payment_status not null default 'pending_on_delivery',
  mobile_money_provider public.mobile_money_provider
);

create table public.order_supplier_groups (
  id text primary key,
  order_id text not null references public.orders (id) on delete cascade,
  supplier_id uuid not null references public.suppliers (id),
  supplier_name text not null,
  delivery_mode public.delivery_mode not null,
  delivery_fee_fcfa integer not null,
  subtotal_fcfa integer not null,
  status public.order_status not null,
  cancellation_reason text,
  cancelled_by public.cancelled_by
);

-- `id` est une clé technique interne (jamais lue/écrite côté Dart —
-- `OrderItem` n'a pas de champ `id`), l'ordre des lignes n'a pas de sens
-- métier propre en dehors du groupe auquel elles appartiennent.
create table public.order_items (
  id text primary key default gen_random_uuid()::text,
  group_id text not null references public.order_supplier_groups (id) on delete cascade,
  product_id text not null references public.products (id),
  product_name_snapshot text not null,
  unit_price_fcfa_snapshot integer not null,
  quantity integer not null
);

-- Points de retrait fixes MTC — table présente pour la complétude du schéma
-- ; aucune donnée de seed aujourd'hui (le mock in-memory n'en seedait pas
-- non plus).
create table public.pickup_points (
  id text primary key,
  name text not null,
  city text not null,
  address text not null,
  latitude double precision not null,
  longitude double precision not null
);

-- ---- chat -----------------------------------------------------------------
create table public.chat_conversations (
  id text primary key,
  client_id uuid not null references public.profiles (id),
  client_display_name_snapshot text not null,
  supplier_id uuid not null references public.suppliers (id),
  supplier_name text not null,
  last_message_preview text not null default '',
  last_message_at timestamptz not null default now(),
  unread_count_client integer not null default 0,
  unread_count_supplier integer not null default 0
);

-- `sender_id` n'a pas de FK : un message peut venir d'un client
-- (`profiles.id`) ou du storefront MTC partagé (`suppliers.id` seul, sans
-- `profiles.id` propre) — même chevauchement documenté que
-- `notifications.user_id`.
create table public.chat_messages (
  id text primary key,
  conversation_id text not null references public.chat_conversations (id) on delete cascade,
  sender_id uuid not null,
  text text not null,
  sent_at timestamptz not null default now(),
  is_read boolean not null default false,
  product_id text references public.products (id),
  product_name_snapshot text,
  product_image_snapshot text,
  product_price_fcfa_snapshot integer,
  attachment_type public.chat_attachment_type not null default 'none',
  attachment_path text,
  voice_duration_seconds integer
);

-- ---- comments ---------------------------------------------------------------
-- `author_id` : même chevauchement que `chat_messages.sender_id`, pas de FK.
create table public.product_comments (
  id text primary key,
  product_id text not null references public.products (id) on delete cascade,
  supplier_id uuid not null references public.suppliers (id),
  author_id uuid not null,
  author_name text not null,
  created_at timestamptz not null default now(),
  text text not null,
  is_supplier boolean not null default false,
  parent_id text references public.product_comments (id) on delete cascade,
  attachment_type public.comment_attachment_type not null default 'none',
  attachment_path text,
  voice_duration_seconds integer
);

create table public.comment_likes (
  comment_id text not null references public.product_comments (id) on delete cascade,
  user_id uuid not null,
  primary key (comment_id, user_id)
);

-- Vue d'hydratation : `ProductComment.likedByUserIds` (Set<String> côté
-- Dart) reconstruit en un seul appel PostgREST plutôt qu'une requête
-- séparée par commentaire. `security_invoker` pour que la RLS des tables
-- sous-jacentes s'applique à l'appelant, pas au propriétaire de la vue.
create view public.product_comments_with_likes
  with (security_invoker = true) as
  select
    c.*,
    coalesce(array_agg(l.user_id) filter (where l.user_id is not null), '{}') as liked_by_user_ids
  from public.product_comments c
  left join public.comment_likes l on l.comment_id = c.id
  group by c.id;

-- ---- reviews ------------------------------------------------------------
create table public.reviews (
  id text primary key,
  order_id text not null references public.orders (id),
  supplier_group_id text not null references public.order_supplier_groups (id),
  client_id uuid not null references public.profiles (id),
  supplier_id uuid not null references public.suppliers (id),
  stars integer not null check (stars between 1 and 5),
  comment text not null,
  created_at timestamptz not null default now(),
  supplier_reply text,
  supplier_replied_at timestamptz,
  unique (order_id, supplier_group_id)
);

-- ---- supplier onboarding (KYC) -------------------------------------------
-- Les deux variantes de l'union scellée `SupplierKyc` (company/individual)
-- sont aplaties dans une seule table, discriminée par `legal_type` — même
-- logique que `SupplierTiersUser`/`suppliers`.
create table public.supplier_kyc (
  id text primary key,
  supplier_id uuid not null references public.suppliers (id),
  legal_type public.supplier_legal_type not null,
  status public.kyc_review_status not null,
  created_at timestamptz not null default now(),
  submitted_at timestamptz,
  reviewed_at timestamptz,
  reviewed_by_staff_id uuid references public.profiles (id),
  rejection_reason text,
  -- variante "company"
  rccm_number text,
  tax_id text,
  legal_representative_name text,
  registered_address text,
  -- variante "individual"
  consent_accepted boolean,
  consent_accepted_at timestamptz,
  consent_policy_version text
);

create table public.supplier_documents (
  id text primary key,
  kyc_id text not null references public.supplier_kyc (id) on delete cascade,
  type public.supplier_document_type not null,
  file_path text not null,
  uploaded_at timestamptz not null default now()
);

-- ---- supplier finance -----------------------------------------------------
create table public.supplier_finance_settings (
  supplier_id uuid primary key references public.suppliers (id),
  commission_rate_percent double precision not null default 10.0
);

create table public.payout_requests (
  id text primary key,
  supplier_id uuid not null references public.suppliers (id),
  amount_fcfa integer not null,
  status public.payout_status not null,
  requested_at timestamptz not null default now(),
  method public.mobile_money_provider not null,
  payout_destination text not null,
  processed_at timestamptz,
  rejection_reason text
);

-- ---- notifications ----------------------------------------------------------
-- `user_id` : pas de FK — reçoit soit un `profiles.id` (client, ou
-- fournisseur tiers dont l'id coïncide avec son `supplierId`), soit le
-- `suppliers.id` partagé MTC pour le staff (chevauchement documenté dans le
-- plan, reproduit tel quel côté RLS plus bas).
create table public.notifications (
  id text primary key,
  user_id uuid not null,
  type public.notification_type not null,
  title text not null,
  body text not null,
  created_at timestamptz not null default now(),
  is_read boolean not null default false
);

-- ============================================================================
-- 3. operating_supplier_id() — miroir exact de operatingSupplierIdProvider
-- ============================================================================
-- `security definer` + `search_path` figé : appelée depuis les policies RLS
-- d'autres tables, une fonction `security invoker` re-déclencherait la RLS
-- de `profiles` à cet instant (récursion) — pattern documenté Supabase.
create or replace function public.operating_supplier_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select case (select role from public.profiles where id = auth.uid())
    when 'supplier_tiers' then auth.uid()
    when 'supplier_principal' then '3331cbb4-0a65-5f94-9812-fe4270e50fe2'::uuid
    else null
  end;
$$;

-- Petit utilitaire RLS : vrai si l'utilisateur connecté est un membre du
-- staff MTC (agent ou admin), peu importe lequel.
create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles where id = auth.uid() and staff_role is not null
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles where id = auth.uid() and staff_role = 'admin'
  );
$$;

-- Vrai si l'utilisateur connecté a laissé un avis pour ce fournisseur —
-- utilisé pour autoriser la propagation de la moyenne recalculée
-- (`ReviewController.submit`) vers `suppliers`/`products`, un cas où
-- l'auteur de l'écriture (le client) n'est ni le propriétaire de la ligne
-- ni un membre du staff.
create or replace function public.has_reviewed_supplier(p_supplier_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.reviews r
    where r.supplier_id = p_supplier_id and r.client_id = auth.uid()
  );
$$;

-- `orders` et `order_supplier_groups` ont chacune une policy qui doit
-- consulter l'autre table (un fournisseur voit une commande via son
-- groupe ; un client voit un groupe via sa commande) — évaluées telles
-- quelles, ces deux policies se redéclenchent mutuellement (« infinite
-- recursion detected in policy »), même mécanisme documenté plus haut pour
-- `operating_supplier_id()`/`profiles`. Ces deux fonctions `security
-- definer` cassent le cycle en lisant l'autre table hors RLS.
create or replace function public.order_client_id(p_order_id text)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select client_id from public.orders where id = p_order_id;
$$;

create or replace function public.order_has_group_for_supplier(p_order_id text, p_supplier_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.order_supplier_groups
    where order_id = p_order_id and supplier_id = p_supplier_id
  );
$$;

-- ============================================================================
-- 4. handle_new_user() — trigger sur auth.users
-- ============================================================================
-- Lit `raw_user_meta_data` (passé via `options.data` au `signUp` côté Dart,
-- Lot 3) pour créer `profiles` (+ `suppliers` pour un tiers) dans la même
-- transaction que l'inscription.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  meta jsonb := new.raw_user_meta_data;
  v_role public.account_role := (meta ->> 'role')::public.account_role;
begin
  insert into public.profiles (id, role, username_or_phone, display_name, phone_number, staff_role)
  values (
    new.id,
    v_role,
    meta ->> 'username_or_phone',
    meta ->> 'display_name',
    meta ->> 'phone_number',
    case when v_role = 'supplier_principal' then (meta ->> 'staff_role')::public.staff_role else null end
  );

  if v_role = 'supplier_tiers' then
    insert into public.suppliers (id, business_name, supplier_type, city, verification_status, legal_type)
    values (
      new.id,
      meta ->> 'business_name',
      'tiers',
      meta ->> 'city',
      'unverified',
      (meta ->> 'legal_type')::public.supplier_legal_type
    );
  end if;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================================
-- 5. Row Level Security
-- ============================================================================

alter table public.profiles enable row level security;
alter table public.suppliers enable row level security;
alter table public.addresses enable row level security;
alter table public.products enable row level security;
alter table public.stock_movements enable row level security;
alter table public.cart_items enable row level security;
alter table public.favorites enable row level security;
alter table public.orders enable row level security;
alter table public.order_supplier_groups enable row level security;
alter table public.order_items enable row level security;
alter table public.pickup_points enable row level security;
alter table public.chat_conversations enable row level security;
alter table public.chat_messages enable row level security;
alter table public.product_comments enable row level security;
alter table public.comment_likes enable row level security;
alter table public.reviews enable row level security;
alter table public.supplier_kyc enable row level security;
alter table public.supplier_documents enable row level security;
alter table public.supplier_finance_settings enable row level security;
alter table public.payout_requests enable row level security;
alter table public.notifications enable row level security;

-- ---- profiles : chacun ne voit/modifie que sa propre ligne ----------------
create policy "profiles_select_own" on public.profiles
  for select using (id = auth.uid());
create policy "profiles_update_own" on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- ---- suppliers : lecture publique (catalogue), écriture par le
-- propriétaire (tiers = lui-même, principal = tout le staff via
-- operating_supplier_id()) ------------------------------------------------
create policy "suppliers_select_public" on public.suppliers
  for select using (true);
-- Le staff a aussi le droit d'écrire ici : `updateSupplierVerificationStatus`
-- (AuthRepository, décision KYC) modifie la ligne d'UN AUTRE fournisseur.
-- Un client qui vient de laisser un avis aussi : `SupplierRepository.recordReview`
-- (`ReviewController.submit`) recalcule la moyenne du fournisseur concerné,
-- pas la sienne.
create policy "suppliers_update_own" on public.suppliers
  for update using (
    id = public.operating_supplier_id()
    or public.is_staff()
    or public.has_reviewed_supplier(id)
  )
  with check (
    id = public.operating_supplier_id()
    or public.is_staff()
    or public.has_reviewed_supplier(id)
  );

-- ---- addresses : owner-only -------------------------------------------
create policy "addresses_all_own" on public.addresses
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---- products : lecture publique restreinte aux fiches actives d'un
-- fournisseur vérifié (même invariant que `ProductRepository.watchProducts`
-- appliquait côté Dart dans le mock — désormais imposé par Postgres),
-- + le fournisseur propriétaire voit toujours tout son propre catalogue
-- (brouillons compris, `watchMyProducts`). Écriture par le propriétaire ;
-- le staff peut aussi modifier `is_supplier_verified` (décision KYC,
-- `ProductRepository.updateSupplierVerification`) et un client ayant laissé
-- un avis peut aussi recalculer `rating_average`/`rating_count`
-- (`ProductRepository.updateSupplierRating`) — ni l'un ni l'autre n'est le
-- propriétaire du produit.
create policy "products_select_public" on public.products
  for select using (
    (status = 'active' and is_supplier_verified = true)
    or supplier_id = public.operating_supplier_id()
  );
create policy "products_write_own" on public.products
  for all using (supplier_id = public.operating_supplier_id())
  with check (supplier_id = public.operating_supplier_id());
create policy "products_update_verification_staff" on public.products
  for update using (public.is_staff()) with check (public.is_staff());
create policy "products_update_rating_reviewer" on public.products
  for update using (public.has_reviewed_supplier(supplier_id))
  with check (public.has_reviewed_supplier(supplier_id));

-- ---- stock_movements : visible/modifiable par le fournisseur propriétaire
-- du produit concerné -------------------------------------------------------
create policy "stock_movements_all_own_product" on public.stock_movements
  for all using (
    exists (
      select 1 from public.products p
      where p.id = product_id and p.supplier_id = public.operating_supplier_id()
    )
  )
  with check (
    exists (
      select 1 from public.products p
      where p.id = product_id and p.supplier_id = public.operating_supplier_id()
    )
  );

-- ---- cart_items / favorites : owner-only --------------------------------
create policy "cart_items_all_own" on public.cart_items
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "favorites_all_own" on public.favorites
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---- orders : le client voit ses commandes, un fournisseur voit celles où
-- il a un groupe, un admin voit tout (watchAllOrders, admin uniquement) ---
create policy "orders_select_visible" on public.orders
  for select using (
    client_id = auth.uid()
    or public.order_has_group_for_supplier(id, public.operating_supplier_id())
    or public.is_admin()
  );

-- ---- order_supplier_groups : porte sa PROPRE RLS — la frontière de
-- confidentialité qu'impose déjà `SupplierOrderView` côté Dart est
-- désormais imposée par Postgres lui-même. Pas de policy UPDATE ici
-- volontairement : `updateGroupStatus` passe exclusivement par la RPC
-- `update_order_group_status()` (Lot 5, `0003_orders_rpc.sql`), qui valide
-- la transition avant d'écrire — un PATCH REST direct ne peut pas
-- contourner cette validation.
create policy "order_supplier_groups_select_visible" on public.order_supplier_groups
  for select using (
    supplier_id = public.operating_supplier_id()
    or public.order_client_id(order_id) = auth.uid()
    or public.is_admin()
  );

-- ---- order_items : visibilité héritée du groupe parent -------------------
create policy "order_items_select_visible" on public.order_items
  for select using (
    exists (
      select 1 from public.order_supplier_groups g
      where g.id = group_id
        and (
          g.supplier_id = public.operating_supplier_id()
          or public.order_client_id(g.order_id) = auth.uid()
          or public.is_admin()
        )
    )
  );

-- ---- pickup_points : lecture publique, écriture admin uniquement --------
create policy "pickup_points_select_public" on public.pickup_points
  for select using (true);
create policy "pickup_points_write_admin" on public.pickup_points
  for all using (public.is_admin()) with check (public.is_admin());

-- ---- chat : visible par les deux participants -----------------------------
create policy "chat_conversations_all_participants" on public.chat_conversations
  for all using (client_id = auth.uid() or supplier_id = public.operating_supplier_id())
  with check (client_id = auth.uid() or supplier_id = public.operating_supplier_id());

create policy "chat_messages_select_participants" on public.chat_messages
  for select using (
    exists (
      select 1 from public.chat_conversations c
      where c.id = conversation_id
        and (c.client_id = auth.uid() or c.supplier_id = public.operating_supplier_id())
    )
  );
create policy "chat_messages_insert_participants" on public.chat_messages
  for insert with check (
    (sender_id = auth.uid() or sender_id = public.operating_supplier_id())
    and exists (
      select 1 from public.chat_conversations c
      where c.id = conversation_id
        and (c.client_id = auth.uid() or c.supplier_id = public.operating_supplier_id())
    )
  );
create policy "chat_messages_update_participants" on public.chat_messages
  for update using (
    exists (
      select 1 from public.chat_conversations c
      where c.id = conversation_id
        and (c.client_id = auth.uid() or c.supplier_id = public.operating_supplier_id())
    )
  );

-- ---- product_comments : Q&A publique, écriture par son auteur -----------
create policy "product_comments_select_public" on public.product_comments
  for select using (true);
create policy "product_comments_insert_own" on public.product_comments
  for insert with check (author_id = auth.uid() or author_id = public.operating_supplier_id());

create policy "comment_likes_select_public" on public.comment_likes
  for select using (true);
create policy "comment_likes_toggle_own" on public.comment_likes
  for all using (user_id = auth.uid() or user_id = public.operating_supplier_id())
  with check (user_id = auth.uid() or user_id = public.operating_supplier_id());

-- ---- reviews : lecture publique (page fournisseur), création réservée au
-- client d'une commande livrée, réponse réservée au fournisseur concerné --
create policy "reviews_select_public" on public.reviews
  for select using (true);
create policy "reviews_insert_own_delivered" on public.reviews
  for insert with check (
    client_id = auth.uid()
    and exists (
      select 1 from public.order_supplier_groups g
      join public.orders o on o.id = g.order_id
      where g.id = supplier_group_id
        and g.order_id = order_id
        and o.client_id = auth.uid()
        and g.status = 'delivered'
    )
  );
create policy "reviews_update_own_supplier" on public.reviews
  for update using (supplier_id = public.operating_supplier_id())
  with check (supplier_id = public.operating_supplier_id());

-- ---- supplier_kyc / supplier_documents : staff-elevated — le fournisseur
-- propriétaire gère son dossier, tout membre du staff peut le consulter et
-- le décider (approve/reject), pas seulement l'admin. ---------------------
create policy "supplier_kyc_all_owner_or_staff" on public.supplier_kyc
  for all using (supplier_id = public.operating_supplier_id() or public.is_staff())
  with check (supplier_id = public.operating_supplier_id() or public.is_staff());

create policy "supplier_documents_all_owner_or_staff" on public.supplier_documents
  for all using (
    exists (
      select 1 from public.supplier_kyc k
      where k.id = kyc_id and (k.supplier_id = public.operating_supplier_id() or public.is_staff())
    )
  )
  with check (
    exists (
      select 1 from public.supplier_kyc k
      where k.id = kyc_id and (k.supplier_id = public.operating_supplier_id() or public.is_staff())
    )
  );

-- ---- supplier_finance_settings : lecture propriétaire+staff, écriture
-- staff uniquement (override de commission) ---------------------------------
create policy "supplier_finance_settings_select" on public.supplier_finance_settings
  for select using (supplier_id = public.operating_supplier_id() or public.is_staff());
create policy "supplier_finance_settings_write_staff" on public.supplier_finance_settings
  for insert with check (public.is_staff());
create policy "supplier_finance_settings_update_staff" on public.supplier_finance_settings
  for update using (public.is_staff()) with check (public.is_staff());

-- ---- payout_requests : le fournisseur voit/crée les siens, l'admin voit
-- tout (watchAllPayoutRequests, admin uniquement, pas agent) et décide ----
create policy "payout_requests_select" on public.payout_requests
  for select using (supplier_id = public.operating_supplier_id() or public.is_admin());
create policy "payout_requests_insert_own" on public.payout_requests
  for insert with check (supplier_id = public.operating_supplier_id());
create policy "payout_requests_update_admin" on public.payout_requests
  for update using (public.is_admin()) with check (public.is_admin());

-- ---- notifications : reproduit le chevauchement documenté de `user_id` --
create policy "notifications_select_own" on public.notifications
  for select using (user_id = auth.uid() or user_id = public.operating_supplier_id());
create policy "notifications_update_own" on public.notifications
  for update using (user_id = auth.uid() or user_id = public.operating_supplier_id());

-- ============================================================================
-- 6. Grants
-- ============================================================================
-- Contrairement à une hypothèse initiale, une base Supabase locale fraîche
-- n'accorde PAS automatiquement de privilèges au niveau table sur de
-- nouvelles tables `public.*` à `anon`/`authenticated` — sans ceci,
-- PostgREST répond "permission denied for table X" avant même que la RLS
-- ne soit évaluée. La RLS (section 5) reste le véritable garde-fou
-- ligne-par-ligne ; ces GRANT ne font que lever le blocage au niveau table.

grant usage on schema public to anon, authenticated;

-- Lecture publique (catalogue, Q&A produit, avis, points de retrait) —
-- accessible même sans compte, comme dans le mock actuel.
grant select on
  public.products, public.suppliers, public.product_comments,
  public.comment_likes, public.product_comments_with_likes,
  public.reviews, public.pickup_points
  to anon;

-- Tout le reste passe par un compte connecté ; la RLS de chaque table
-- (section 5) restreint ensuite précisément quelles lignes/opérations
-- sont réellement permises.
grant select, insert, update, delete on
  public.profiles, public.suppliers, public.addresses, public.products,
  public.stock_movements, public.cart_items, public.favorites,
  public.orders, public.order_supplier_groups, public.order_items,
  public.pickup_points, public.chat_conversations, public.chat_messages,
  public.product_comments, public.comment_likes, public.reviews,
  public.supplier_kyc, public.supplier_documents,
  public.supplier_finance_settings, public.payout_requests, public.notifications
  to authenticated;

grant select on public.product_comments_with_likes to authenticated;

-- ============================================================================
-- 7. Storage — buckets + policies
-- ============================================================================
-- Les entités stockent le CHEMIN objet, jamais une URL résolue. Convention
-- de chemin : premier segment = identifiant du propriétaire/regroupement
-- (supplier_id, conversation_id, order_id, auth.uid()...), résolu à
-- l'affichage via getPublicUrl/createSignedUrl (câblage réel au Lot 9).

insert into storage.buckets (id, name, public) values
  ('kyc-documents', 'kyc-documents', false),
  ('product-images', 'product-images', true),
  ('supplier-branding', 'supplier-branding', true),
  ('chat-attachments', 'chat-attachments', false),
  ('comment-attachments', 'comment-attachments', true),
  ('order-messages', 'order-messages', false)
on conflict (id) do nothing;

-- kyc-documents (privé) : dossier = supplier_id, propriétaire ou staff.
create policy "kyc_documents_owner_or_staff" on storage.objects
  for all using (
    bucket_id = 'kyc-documents'
    and (
      (storage.foldername(name))[1] = public.operating_supplier_id()::text
      or public.is_staff()
    )
  )
  with check (
    bucket_id = 'kyc-documents'
    and (
      (storage.foldername(name))[1] = public.operating_supplier_id()::text
      or public.is_staff()
    )
  );

-- product-images / supplier-branding (publics en lecture) : dossier =
-- supplier_id, écriture réservée au fournisseur propriétaire.
create policy "product_images_public_read" on storage.objects
  for select using (bucket_id = 'product-images');
create policy "product_images_owner_write" on storage.objects
  for insert with check (
    bucket_id = 'product-images' and (storage.foldername(name))[1] = public.operating_supplier_id()::text
  );
create policy "product_images_owner_update" on storage.objects
  for update using (
    bucket_id = 'product-images' and (storage.foldername(name))[1] = public.operating_supplier_id()::text
  );
create policy "product_images_owner_delete" on storage.objects
  for delete using (
    bucket_id = 'product-images' and (storage.foldername(name))[1] = public.operating_supplier_id()::text
  );

create policy "supplier_branding_public_read" on storage.objects
  for select using (bucket_id = 'supplier-branding');
create policy "supplier_branding_owner_write" on storage.objects
  for insert with check (
    bucket_id = 'supplier-branding' and (storage.foldername(name))[1] = public.operating_supplier_id()::text
  );
create policy "supplier_branding_owner_update" on storage.objects
  for update using (
    bucket_id = 'supplier-branding' and (storage.foldername(name))[1] = public.operating_supplier_id()::text
  );
create policy "supplier_branding_owner_delete" on storage.objects
  for delete using (
    bucket_id = 'supplier-branding' and (storage.foldername(name))[1] = public.operating_supplier_id()::text
  );

-- chat-attachments (privé) : dossier = conversation_id, réservé aux deux
-- participants de cette conversation.
create policy "chat_attachments_participants" on storage.objects
  for all using (
    bucket_id = 'chat-attachments'
    and exists (
      select 1 from public.chat_conversations c
      where c.id = (storage.foldername(name))[1]
        and (c.client_id = auth.uid() or c.supplier_id = public.operating_supplier_id())
    )
  )
  with check (
    bucket_id = 'chat-attachments'
    and exists (
      select 1 from public.chat_conversations c
      where c.id = (storage.foldername(name))[1]
        and (c.client_id = auth.uid() or c.supplier_id = public.operating_supplier_id())
    )
  );

-- comment-attachments (public en lecture, Q&A publique) : écriture par
-- l'auteur authentifié.
create policy "comment_attachments_public_read" on storage.objects
  for select using (bucket_id = 'comment-attachments');
create policy "comment_attachments_author_write" on storage.objects
  for insert with check (
    bucket_id = 'comment-attachments'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or (storage.foldername(name))[1] = public.operating_supplier_id()::text
    )
  );

-- order-messages (privé, notes vocales client→fournisseur) : dossier =
-- order_id, réservé au client de la commande, aux fournisseurs y ayant un
-- groupe, et à l'admin.
create policy "order_messages_visible" on storage.objects
  for all using (
    bucket_id = 'order-messages'
    and exists (
      select 1 from public.orders o
      where o.id = (storage.foldername(name))[1]
        and (
          o.client_id = auth.uid()
          or exists (
            select 1 from public.order_supplier_groups g
            where g.order_id = o.id and g.supplier_id = public.operating_supplier_id()
          )
          or public.is_admin()
        )
    )
  )
  with check (
    bucket_id = 'order-messages'
    and exists (
      select 1 from public.orders o
      where o.id = (storage.foldername(name))[1]
        and (
          o.client_id = auth.uid()
          or exists (
            select 1 from public.order_supplier_groups g
            where g.order_id = o.id and g.supplier_id = public.operating_supplier_id()
          )
          or public.is_admin()
        )
    )
  );
