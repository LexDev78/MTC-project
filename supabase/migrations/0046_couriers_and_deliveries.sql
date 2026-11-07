-- Socle de l'interface livreur (étape 1/3) : qui sont les livreurs, et
-- quelles courses leur sont proposées.
--
-- Les QR à usage unique (retrait chez le fournisseur, remise au client) et
-- le suivi temps réel sur la carte arrivent dans les migrations suivantes —
-- ce fichier s'arrête à « une course existe, elle est proposée à un livreur,
-- il l'accepte ou la refuse ».
--
-- Choix d'attribution : **au plus proche d'abord**. Une course n'est jamais
-- offerte à tout le monde en même temps — elle est proposée à un livreur à
-- la fois, en commençant par celui dont la dernière position connue est la
-- plus proche du fournisseur, avec une fenêtre de réponse. Passé ce délai,
-- ou sur un refus, elle passe au suivant. Deux livreurs ne peuvent donc
-- jamais accepter la même course, sans verrou ni course de vitesse.

create type public.courier_status as enum ('pending', 'approved', 'rejected', 'suspended');
create type public.delivery_status as enum (
  'offered', 'accepted', 'picked_up', 'delivered', 'cancelled'
);

-- ============================================================================
-- 1. Livreurs
-- ============================================================================
-- Créée par `handle_new_user()` à l'inscription, comme `suppliers` — jamais
-- insérée directement par l'app. Un livreur s'inscrit librement mais reste
-- `pending` : tant qu'un agent MTC ne l'a pas approuvé, aucune course ne lui
-- est proposée (il manipule la marchandise, parfois l'argent).
create table public.couriers (
  id uuid primary key references public.profiles (id) on delete cascade,
  status public.courier_status not null default 'pending',
  city text not null,
  vehicle_label text,
  -- « En ligne » est déclaratif : le livreur l'active quand il prend son
  -- service. Sans position connue, il n'est de toute façon pas proposable
  -- (voir `offer_delivery_to_next_courier`).
  is_online boolean not null default false,
  last_latitude double precision,
  last_longitude double precision,
  last_position_at timestamptz,
  reviewed_at timestamptz,
  reviewed_by_staff_id uuid references public.profiles (id),
  rejection_reason text,
  created_at timestamptz not null default now()
);

create index couriers_available_idx on public.couriers (status, is_online);

-- ============================================================================
-- 2. Courses
-- ============================================================================
-- Une course par groupe fournisseur livré par MTC — c'est le groupe, pas la
-- commande, qui a un point de retrait unique (`order_supplier_groups`, une
-- commande peut en contenir plusieurs, chez des fournisseurs différents).
create table public.deliveries (
  id text primary key default gen_random_uuid()::text,
  order_id text not null references public.orders (id) on delete cascade,
  supplier_group_id text not null unique
    references public.order_supplier_groups (id) on delete cascade,
  status public.delivery_status not null default 'offered',

  -- Livreur qui a accepté. Null tant que personne n'a dit oui.
  courier_id uuid references public.couriers (id),

  -- Proposition en cours : un seul livreur à la fois, avec une date
  -- d'expiration. `declined_courier_ids` garde ceux qui ont refusé ou laissé
  -- passer, pour ne pas leur reproposer la même course en boucle.
  offered_to_courier_id uuid references public.couriers (id),
  offered_at timestamptz,
  offer_expires_at timestamptz,
  declined_courier_ids uuid[] not null default '{}',

  accepted_at timestamptz,
  picked_up_at timestamptz,
  delivered_at timestamptz,
  created_at timestamptz not null default now()
);

create index deliveries_offered_to_idx on public.deliveries (offered_to_courier_id)
  where status = 'offered';
create index deliveries_courier_idx on public.deliveries (courier_id);

-- ============================================================================
-- 3. Helpers
-- ============================================================================
create or replace function public.is_courier()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'livreur'
  );
$$;

-- La distance à vol d'oiseau se calcule avec `public.haversine_km`, déjà
-- définie par `0030_fix_delivery_and_priority_fee_trust.sql` (où elle sert à
-- recalculer les frais de livraison côté serveur) — une seule formule pour
-- les deux usages, plutôt qu'une deuxième qui divergerait.

-- ============================================================================
-- 4. Création du compte livreur à l'inscription
-- ============================================================================
-- Reprend `handle_new_user()` (0001) en ajoutant la branche `livreur`. Même
-- forme que la branche `supplier_tiers` juste au-dessus.
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
  elsif v_role = 'livreur' then
    insert into public.couriers (id, status, city, vehicle_label)
    values (new.id, 'pending', coalesce(meta ->> 'city', 'Bamako'), meta ->> 'vehicle_label');
  end if;

  return new;
end;
$$;

-- ============================================================================
-- 5. RLS
-- ============================================================================
alter table public.couriers enable row level security;
alter table public.deliveries enable row level security;

-- Un livreur voit et modifie sa propre fiche (se mettre en ligne, pousser sa
-- position) ; le staff voit tout le monde et décide des validations.
create policy "couriers_select_self_or_staff" on public.couriers
  for select using (id = auth.uid() or public.is_staff());

create policy "couriers_update_self" on public.couriers
  for update using (id = auth.uid()) with check (id = auth.uid());

create policy "couriers_update_staff" on public.couriers
  for update using (public.is_staff()) with check (public.is_staff());

-- Une course est visible du livreur à qui elle est proposée, de celui qui
-- l'a acceptée, du client dont c'est la commande, du fournisseur concerné et
-- du staff. Les écritures, elles, passent exclusivement par les RPC
-- ci-dessous : aucune policy `update` pour les livreurs, sinon rien
-- n'empêcherait d'écrire `status = 'delivered'` à la main.
create policy "deliveries_select_participants" on public.deliveries
  for select using (
    public.is_staff()
    or courier_id = auth.uid()
    or offered_to_courier_id = auth.uid()
    or exists (
      select 1 from public.orders o
      where o.id = deliveries.order_id and o.client_id = auth.uid()
    )
    or exists (
      select 1 from public.order_supplier_groups g
      where g.id = deliveries.supplier_group_id
        and g.supplier_id = public.operating_supplier_id()
    )
  );

grant select on public.couriers to authenticated;
grant update (is_online, last_latitude, last_longitude, last_position_at)
  on public.couriers to authenticated;
grant select on public.deliveries to authenticated;

-- ============================================================================
-- 6. Attribution : proposer au plus proche, puis au suivant
-- ============================================================================
-- Appelée par le trigger de création de course, puis à chaque refus ou
-- expiration. `security definer` : le classement lit la position de livreurs
-- que l'appelant n'a pas le droit de voir.
create or replace function public.offer_delivery_to_next_courier(p_delivery_id text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delivery public.deliveries;
  v_lat double precision;
  v_lon double precision;
  v_courier_id uuid;
begin
  select * into v_delivery from public.deliveries where id = p_delivery_id for update;
  if v_delivery is null or v_delivery.status <> 'offered' then
    return null;
  end if;

  select s.address_latitude, s.address_longitude into v_lat, v_lon
    from public.order_supplier_groups g
    join public.suppliers s on s.id = g.supplier_id
   where g.id = v_delivery.supplier_group_id;

  -- Un livreur sans position connue n'est pas classable : il ne reçoit
  -- aucune proposition tant qu'il n'a pas transmis la sienne (ce que fait
  -- l'app dès qu'il se met en ligne).
  select c.id into v_courier_id
    from public.couriers c
   where c.status = 'approved'
     and c.is_online
     and c.last_latitude is not null
     and c.last_longitude is not null
     and not (c.id = any (v_delivery.declined_courier_ids))
     -- Pas deux courses en cours pour le même livreur.
     and not exists (
       select 1 from public.deliveries d
        where d.courier_id = c.id and d.status in ('accepted', 'picked_up')
     )
   order by case
     when v_lat is null or v_lon is null then 0
     else public.haversine_km(v_lat, v_lon, c.last_latitude, c.last_longitude)
   end
   limit 1;

  if v_courier_id is null then
    -- Personne de disponible : la course reste `offered` sans destinataire,
    -- prête à être reproposée au prochain appel (nouveau livreur en ligne,
    -- relance côté staff).
    update public.deliveries
       set offered_to_courier_id = null, offered_at = null, offer_expires_at = null
     where id = p_delivery_id;
    return null;
  end if;

  update public.deliveries
     set offered_to_courier_id = v_courier_id,
         offered_at = now(),
         offer_expires_at = now() + interval '2 minutes'
   where id = p_delivery_id;

  insert into public.notifications (id, user_id, type, title, body, reference_id)
  values (
    gen_random_uuid()::text,
    v_courier_id,
    'delivery_offer',
    'Nouvelle course',
    'Une livraison vous est proposée.',
    p_delivery_id
  );

  return v_courier_id;
end;
$$;

-- Une course naît quand le fournisseur remet son groupe à la livraison MTC.
--
-- `in_transit` est l'état existant le plus proche de « prêt, à récupérer » :
-- le flux de statuts (0001) n'a pas d'étape intermédiaire entre `preparing`
-- et `in_transit`, et en ajouter une changerait ce que voient le client et
-- le fournisseur partout ailleurs. Le passage réel en main du livreur est
-- marqué par `picked_up` sur la course, pas par le statut du groupe.
create or replace function public.create_delivery_for_group()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delivery_id text;
begin
  if new.delivery_mode <> 'mtc_delivery' then return new; end if;
  if new.status <> 'in_transit' or old.status = 'in_transit' then return new; end if;
  if exists (select 1 from public.deliveries where supplier_group_id = new.id) then
    return new;
  end if;

  insert into public.deliveries (order_id, supplier_group_id)
  values (new.order_id, new.id)
  returning id into v_delivery_id;

  perform public.offer_delivery_to_next_courier(v_delivery_id);
  return new;
end;
$$;

create trigger order_supplier_groups_create_delivery
  after update of status on public.order_supplier_groups
  for each row execute function public.create_delivery_for_group();

-- ============================================================================
-- 7. Accepter / refuser
-- ============================================================================
create or replace function public.accept_delivery(p_delivery_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delivery public.deliveries;
begin
  select * into v_delivery from public.deliveries where id = p_delivery_id for update;
  if v_delivery is null then
    raise exception 'Course introuvable.';
  end if;
  -- Le trio de garde : la course doit être encore ouverte, m'être proposée à
  -- moi, et la fenêtre ne doit pas être passée. Sans la dernière, un livreur
  -- qui laisse traîner une notification acceptée dix minutes plus tard
  -- volerait une course déjà proposée à un autre.
  if v_delivery.status <> 'offered'
     or v_delivery.offered_to_courier_id is distinct from auth.uid()
     or v_delivery.offer_expires_at < now() then
    raise exception 'Cette course ne vous est plus proposée.';
  end if;

  update public.deliveries
     set status = 'accepted',
         courier_id = auth.uid(),
         accepted_at = now(),
         offered_to_courier_id = null,
         offer_expires_at = null
   where id = p_delivery_id;
end;
$$;

create or replace function public.decline_delivery(p_delivery_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delivery public.deliveries;
begin
  select * into v_delivery from public.deliveries where id = p_delivery_id for update;
  if v_delivery is null or v_delivery.offered_to_courier_id is distinct from auth.uid() then
    raise exception 'Cette course ne vous est pas proposée.';
  end if;

  update public.deliveries
     set declined_courier_ids = array_append(declined_courier_ids, auth.uid()),
         offered_to_courier_id = null,
         offered_at = null,
         offer_expires_at = null
   where id = p_delivery_id;

  perform public.offer_delivery_to_next_courier(p_delivery_id);
end;
$$;

-- Relance : passe au livreur suivant toute course dont la fenêtre de réponse
-- est écoulée. Appelée par l'app livreur à l'ouverture de sa liste — pas de
-- planificateur côté base, qui demanderait `pg_cron` pour un besoin que le
-- premier livreur qui ouvre l'app couvre déjà.
create or replace function public.reoffer_expired_deliveries()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delivery record;
  v_count integer := 0;
begin
  for v_delivery in
    select id, offered_to_courier_id from public.deliveries
     where status = 'offered'
       and (offer_expires_at is null or offer_expires_at < now())
  loop
    if v_delivery.offered_to_courier_id is not null then
      update public.deliveries
         set declined_courier_ids =
               array_append(declined_courier_ids, v_delivery.offered_to_courier_id),
             offered_to_courier_id = null
       where id = v_delivery.id;
    end if;
    perform public.offer_delivery_to_next_courier(v_delivery.id);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke all on function public.offer_delivery_to_next_courier(text) from public, anon, authenticated;
revoke all on function public.accept_delivery(text) from public, anon;
revoke all on function public.decline_delivery(text) from public, anon;
revoke all on function public.reoffer_expired_deliveries() from public, anon;
grant execute on function public.accept_delivery(text) to authenticated;
grant execute on function public.decline_delivery(text) to authenticated;
grant execute on function public.reoffer_expired_deliveries() to authenticated;

-- Le client suivra la course en direct (étape 3) : la table doit être
-- publiée pour que Realtime pousse ses changements.
alter publication supabase_realtime add table public.deliveries;
