-- 0139 — Une commande livrée par la boutique elle-même se clôt par le
-- client, plus par la boutique seule (audit du 27/10/2026, faille 3).
--
-- En livraison MTC, la course se clôt quand le livreur scanne le code du
-- client (`0051`, `0054`, `guard_mtc_delivery_completion`). En livraison
-- par la boutique (`self_delivery`), la boutique passait le groupe à
-- « livrée » d'un geste, par `update_order_group_status`. Deux abus en
-- découlaient :
--
--  * l'argent : une commande payée d'avance compte comme encaissée par MTC
--    dès qu'elle est livrée (`supplier_ledger`, `0131`) — la boutique
--    pouvait demander le versement d'une vente qu'elle n'avait pas remise ;
--  * les avis : un complice commandait, la boutique « livrait », le
--    complice notait 5★ (voir aussi `0138`).
--
-- Désormais, comme pour MTC, la remise se prouve :
--
--  * par le code du client : il l'affiche (QR), la boutique le scanne
--    (`confirm_self_delivery_by_code`). 32 octets aléatoires, à usage
--    unique, et la même réponse pour un code faux ou déjà servi — les
--    choix de `0051` ;
--  * ou par le client lui-même, d'un bouton « J'ai reçu ma commande »
--    (`confirm_self_delivery_received`) — pour la remise sans téléphone
--    sous la main, ou après coup.
--
-- Un déclencheur refuse tout autre passage à « livrée » d'un groupe
-- `self_delivery`, quel que soit le chemin : c'est la règle elle-même, pas
-- une vérification de plus dans une fonction parmi d'autres.
--
-- Les commandes déjà livrées ne changent pas. Celles en cours se
-- terminent par l'un des deux chemins.

-- ---------------------------------------------------------- 1. la remise
create table if not exists public.self_delivery_handovers (
  group_id text primary key
    references public.order_supplier_groups (id) on delete cascade,
  code text not null unique,
  created_at timestamptz not null default now(),
  confirmed_at timestamptz,
  confirmed_by text check (confirmed_by in ('client', 'code')),
  check ((confirmed_at is null) = (confirmed_by is null))
);

-- Aucune policy, aucun droit : le code ne se lit que par
-- `fetch_self_delivery_code` (le client de la commande), et la boutique ne
-- le voit jamais — sinon elle « scannerait » sans être allée chez lui.
alter table public.self_delivery_handovers enable row level security;
revoke all on public.self_delivery_handovers from public, anon, authenticated;

-- --------------------------------------------- 2. le garde-fou du passage
create or replace function public.guard_self_delivery_completion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status <> 'delivered' or old.status = 'delivered'
     or new.delivery_mode <> 'self_delivery' then
    return new;
  end if;
  -- Hors de toute session (semis, script d'exploitation) : pas d'humain à
  -- qui demander une preuve.
  if auth.uid() is null then
    return new;
  end if;
  if exists (
    select 1 from public.self_delivery_handovers h
     where h.group_id = new.id and h.confirmed_at is not null
  ) then
    return new;
  end if;
  raise exception
    'La remise se confirme avec le code du client, ou par le client lui-même dans l''app.';
end;
$$;

revoke all on function public.guard_self_delivery_completion() from public, anon, authenticated;

drop trigger if exists order_supplier_groups_guard_self_completion on public.order_supplier_groups;
create trigger order_supplier_groups_guard_self_completion
  before update of status on public.order_supplier_groups
  for each row execute function public.guard_self_delivery_completion();

-- ------------------------------------------------ 3. le code, côté client
-- Créé à la première demande : un groupe peut naître, être annulé, ou
-- n'être jamais livré, et il n'y a pas de raison de tirer un code d'avance.
create or replace function public.fetch_self_delivery_code(p_group_id text)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_client uuid := auth.uid();
  v_group public.order_supplier_groups;
  v_code text;
  v_confirmed timestamptz;
begin
  select g.* into v_group
    from public.order_supplier_groups g
    join public.orders o on o.id = g.order_id
   where g.id = p_group_id and o.client_id = v_client;

  -- Le groupe d'un autre et un groupe qui n'existe pas : même réponse.
  if v_group.id is null then
    raise exception 'Commande introuvable, ou elle n''est pas la vôtre.';
  end if;
  if v_group.delivery_mode <> 'self_delivery' then
    raise exception 'Cette commande est livrée par MTC : son code est sur la course.';
  end if;
  -- Pas de code avant que la commande parte (la boutique ne le scanne qu'en
  -- livraison), ni une fois tout fini.
  if v_group.status <> 'in_transit' then
    return null;
  end if;

  insert into public.self_delivery_handovers (group_id, code)
  values (p_group_id, encode(gen_random_bytes(32), 'hex'))
  on conflict (group_id) do nothing;

  select code, confirmed_at into v_code, v_confirmed
    from public.self_delivery_handovers where group_id = p_group_id;
  if v_confirmed is not null then
    return null;
  end if;
  return v_code;
end;
$$;

revoke all on function public.fetch_self_delivery_code(text) from public, anon;
grant execute on function public.fetch_self_delivery_code(text) to authenticated;

-- ------------------------------------------- 4. la boutique scanne le code
create or replace function public.confirm_self_delivery_by_code(p_group_id text, p_code text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group public.order_supplier_groups;
  v_handover public.self_delivery_handovers;
begin
  select * into v_group from public.order_supplier_groups where id = p_group_id for update;

  if v_group.id is null
     or v_group.supplier_id is distinct from public.operating_supplier_id() then
    raise exception 'Commande introuvable.';
  end if;
  if not public.supplier_can('orders') then
    raise exception 'Vous n''avez pas accès aux commandes de cette boutique.';
  end if;
  if v_group.delivery_mode <> 'self_delivery' then
    raise exception 'Cette commande est livrée par MTC : c''est le livreur qui scanne.';
  end if;
  if v_group.status <> 'in_transit' then
    raise exception 'Passez d''abord la commande « en cours de livraison ».';
  end if;

  select * into v_handover
    from public.self_delivery_handovers where group_id = p_group_id for update;

  -- Code faux, code d'un autre groupe, code déjà servi, ou client qui n'a
  -- encore jamais affiché le sien : une seule réponse, comme en `0051`.
  if v_handover.group_id is null
     or v_handover.confirmed_at is not null
     or p_code is null
     or v_handover.code <> p_code then
    raise exception 'Code de remise invalide.';
  end if;

  update public.self_delivery_handovers
     set confirmed_at = now(), confirmed_by = 'code'
   where group_id = p_group_id;

  update public.order_supplier_groups set status = 'delivered' where id = p_group_id;
end;
$$;

revoke all on function public.confirm_self_delivery_by_code(text, text) from public, anon;
grant execute on function public.confirm_self_delivery_by_code(text, text) to authenticated;

-- ---------------------------------------- 5. le client confirme lui-même
create or replace function public.confirm_self_delivery_received(p_group_id text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_client uuid := auth.uid();
  v_group public.order_supplier_groups;
begin
  select g.* into v_group
    from public.order_supplier_groups g
    join public.orders o on o.id = g.order_id
   where g.id = p_group_id and o.client_id = v_client
   for update of g;

  if v_group.id is null then
    raise exception 'Commande introuvable, ou elle n''est pas la vôtre.';
  end if;
  if v_group.delivery_mode <> 'self_delivery' then
    raise exception 'Cette commande est livrée par MTC : la remise se fait avec le livreur.';
  end if;
  if v_group.status = 'delivered' then
    return;  -- Déjà fait (double appui, deux appareils) : rien à refaire.
  end if;
  -- Seulement une commande partie : confirmer une commande que la boutique
  -- vient d'accepter la clôturait sans rien recevoir — avis 1★ ouvert,
  -- commission due par la boutique, annulation fermée, stock perdu
  -- (contre-vérification du 06/11/2026). Une remise en boutique passe aussi
  -- par « en cours de livraison », puis le code.
  if v_group.status <> 'in_transit' then
    raise exception 'Vous pourrez confirmer la réception une fois la commande en route.';
  end if;

  insert into public.self_delivery_handovers (group_id, code, confirmed_at, confirmed_by)
  values (p_group_id, encode(gen_random_bytes(32), 'hex'), now(), 'client')
  on conflict (group_id) do update
    set confirmed_at = coalesce(self_delivery_handovers.confirmed_at, now()),
        confirmed_by = coalesce(self_delivery_handovers.confirmed_by, 'client');

  update public.order_supplier_groups set status = 'delivered' where id = p_group_id;

  -- La boutique apprend que c'est fini. Le client, lui, reçoit déjà
  -- l'avis de changement de statut (`notify_order_status_change`).
  insert into public.notifications (id, user_id, type, title, body, reference_id)
  values (
    gen_random_uuid()::text, v_group.supplier_id, 'order_status_update',
    'Réception confirmée',
    'Le client a confirmé avoir reçu sa commande.',
    v_group.order_id
  );
end;
$$;

revoke all on function public.confirm_self_delivery_received(text) from public, anon;
grant execute on function public.confirm_self_delivery_received(text) to authenticated;
