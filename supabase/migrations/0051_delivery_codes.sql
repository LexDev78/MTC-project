-- Les deux accusés d'une course : un QR chez le fournisseur pour le retrait,
-- un chez le client pour la remise. Chacun à usage unique.
--
-- Ce que ces codes prouvent : que le livreur **était sur place**. Toute la
-- conception découle de là.
--
--  * Le code vit dans sa propre table et non dans une colonne de
--    `deliveries` : la policy de cette table-là laisse le livreur lire sa
--    course en entier, donc y ranger le code le lui donnerait. Une table à
--    part a ses propres règles, et elles **excluent le livreur**. S'il
--    pouvait lire le code, il lui suffirait de l'envoyer sans bouger — le
--    scan ne prouverait plus rien du tout.
--  * 32 octets aléatoires : deviner un code est hors de portée, donc pas
--    besoin de limiter les tentatives.
--  * L'ordre est imposé par le statut de la course, pas par l'app : on ne
--    peut pas accuser une remise avant d'avoir accusé le retrait.
--  * Un code consommé ne l'est qu'une fois, sous verrou — deux scans
--    simultanés ne peuvent pas passer tous les deux.
--  * Un code faux et un code déjà utilisé renvoient le **même** message :
--    rien n'indique à un curieux lequel des deux il a trouvé.

create type public.delivery_code_kind as enum ('pickup', 'delivery');

create table public.delivery_codes (
  delivery_id text not null references public.deliveries (id) on delete cascade,
  kind public.delivery_code_kind not null,
  code text not null,
  consumed_at timestamptz,
  consumed_by uuid references public.couriers (id),
  created_at timestamptz not null default now(),
  primary key (delivery_id, kind)
);

create unique index delivery_codes_code_idx on public.delivery_codes (code);

alter table public.delivery_codes enable row level security;

-- Chacun ne voit que le code qu'il doit montrer : le fournisseur celui du
-- retrait, le client celui de la remise. Le livreur, lui, n'a de policy
-- d'aucune sorte ici — c'est l'intention, pas un oubli.
create policy "delivery_codes_select_owner" on public.delivery_codes
  for select using (
    public.is_staff()
    or (
      kind = 'pickup'
      and exists (
        select 1 from public.deliveries d
        join public.order_supplier_groups g on g.id = d.supplier_group_id
        where d.id = delivery_codes.delivery_id
          and g.supplier_id = public.operating_supplier_id()
      )
    )
    or (
      kind = 'delivery'
      and exists (
        select 1 from public.deliveries d
        join public.orders o on o.id = d.order_id
        where d.id = delivery_codes.delivery_id and o.client_id = auth.uid()
      )
    )
  );

-- Lecture seule pour tout le monde : les deux écritures qui comptent
-- (création, consommation) passent par des fonctions `security definer`.
grant select on public.delivery_codes to authenticated;

-- ============================================================================
-- Création des codes en même temps que la course
-- ============================================================================
-- Reprend `create_delivery_for_group()` (`0046`, garde du point de retrait
-- ajoutée en `0050`) en y ajoutant la génération des deux codes.
create or replace function public.create_delivery_for_group()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_delivery_id text;
  v_has_pickup_point boolean;
begin
  if new.delivery_mode <> 'mtc_delivery' then return new; end if;
  if new.status <> 'in_transit' or old.status = 'in_transit' then return new; end if;

  select s.full_address is not null
         and trim(s.full_address) <> ''
         and s.address_latitude is not null
         and s.address_longitude is not null
    into v_has_pickup_point
    from public.suppliers s
   where s.id = new.supplier_id;

  if not coalesce(v_has_pickup_point, false) then
    raise exception 'Renseignez l''adresse de retrait de votre boutique avant de confier une commande à la livraison MTC.';
  end if;

  if exists (select 1 from public.deliveries where supplier_group_id = new.id) then
    return new;
  end if;

  insert into public.deliveries (order_id, supplier_group_id)
  values (new.order_id, new.id)
  returning id into v_delivery_id;

  -- Les deux codes dès maintenant : le fournisseur doit pouvoir afficher le
  -- sien avant même qu'un livreur soit trouvé, pour préparer le colis.
  insert into public.delivery_codes (delivery_id, kind, code) values
    (v_delivery_id, 'pickup', encode(gen_random_bytes(32), 'hex')),
    (v_delivery_id, 'delivery', encode(gen_random_bytes(32), 'hex'));

  perform public.offer_delivery_to_next_courier(v_delivery_id);
  return new;
end;
$$;

-- ============================================================================
-- Scan : le livreur présente un code, le serveur décide
-- ============================================================================
-- Renvoie le nouveau statut de la course.
create or replace function public.scan_delivery_code(
  p_delivery_id text,
  p_code text
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delivery public.deliveries;
  v_kind public.delivery_code_kind;
  v_new_status public.delivery_status;
begin
  select * into v_delivery from public.deliveries where id = p_delivery_id for update;
  if v_delivery is null or v_delivery.courier_id is distinct from auth.uid() then
    raise exception 'Cette course ne vous est pas confiée.';
  end if;

  -- L'étape attendue se déduit du statut, jamais d'un paramètre : l'app ne
  -- choisit pas ce qu'elle accuse.
  v_kind := case v_delivery.status
    when 'accepted' then 'pickup'::public.delivery_code_kind
    when 'picked_up' then 'delivery'::public.delivery_code_kind
    else null
  end;
  if v_kind is null then
    raise exception 'Cette course n''attend aucun scan.';
  end if;

  update public.delivery_codes
     set consumed_at = now(), consumed_by = auth.uid()
   where delivery_id = p_delivery_id
     and kind = v_kind
     and code = p_code
     and consumed_at is null;

  -- Code faux, code d'une autre étape, ou code déjà utilisé : même réponse.
  -- Distinguer les cas renseignerait qui cherche à en abuser.
  if not found then
    raise exception 'Code invalide ou déjà utilisé.';
  end if;

  v_new_status := case v_kind
    when 'pickup' then 'picked_up'::public.delivery_status
    else 'delivered'::public.delivery_status
  end;

  update public.deliveries
     set status = v_new_status,
         picked_up_at = case when v_kind = 'pickup' then now() else picked_up_at end,
         delivered_at = case when v_kind = 'delivery' then now() else delivered_at end
   where id = p_delivery_id;

  -- La remise accusée clôt aussi la commande côté client et fournisseur :
  -- c'est le même événement, et le laisser « en livraison » obligerait
  -- quelqu'un à cliquer ailleurs pour dire ce que le scan vient de prouver.
  if v_kind = 'delivery' then
    update public.order_supplier_groups
       set status = 'delivered'
     where id = v_delivery.supplier_group_id;
  end if;

  return v_new_status::text;
end;
$$;

revoke all on function public.scan_delivery_code(text, text) from public, anon;
grant execute on function public.scan_delivery_code(text, text) to authenticated;

-- Lecture du statut d'un groupe sans session, pour les tests.
create or replace function public.test_fetch_group_status(p_group_id text)
returns text
language sql
security definer
set search_path = public
as $$
  select status::text from public.order_supplier_groups where id = p_group_id;
$$;

revoke all on function public.test_fetch_group_status(text) from public, anon, authenticated;
