-- Lot 5 — `placeOrder` et `updateGroupStatus` en RPC Postgres atomiques.
-- `orders`/`order_supplier_groups`/`order_items` n'ont aucune policy
-- INSERT/UPDATE (voir `0001_initial_schema.sql`) : ces deux fonctions
-- `security definer` sont le SEUL chemin d'écriture, ce qui règle aussi
-- le trou de RLS documenté au Lot 4 (un client ne peut pas décrémenter le
-- stock d'un produit dont il n'est pas propriétaire — la fonction, elle,
-- le peut, mais seulement dans le cadre étroit d'une commande cohérente).

create or replace function public.place_order(
  p_client_display_name_snapshot text,
  p_client_phone_snapshot text,
  -- [{supplier_id, supplier_name, delivery_mode, delivery_fee_fcfa,
  --   items: [{product_id, product_name_snapshot, unit_price_fcfa_snapshot, quantity}]}]
  p_groups jsonb,
  p_delivery_address_label text,
  p_delivery_city text,
  p_delivery_details text,
  p_delivery_latitude double precision,
  p_delivery_longitude double precision,
  p_fulfillment_method text default 'home_delivery',
  p_courier_phone text default null,
  p_alternate_phone text default null,
  p_delivery_date timestamptz default null,
  p_delivery_time_slot_label text default null,
  p_is_priority boolean default false,
  p_priority_fee_fcfa integer default 0,
  p_supplier_message_type text default 'none',
  p_supplier_message_text text default null,
  p_supplier_message_voice_path text default null,
  p_supplier_message_voice_duration_seconds integer default null,
  p_payment_method text default 'on_delivery',
  p_payment_status text default 'pending_on_delivery',
  p_mobile_money_provider text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_client_id uuid := auth.uid();
  v_order_id text := gen_random_uuid()::text;
  v_group jsonb;
  v_item jsonb;
  v_group_id text;
  v_group_subtotal integer;
  v_total integer := 0;
  v_current_stock integer;
  v_product_name text;
begin
  if v_client_id is null then
    raise exception 'Vous devez être connecté pour passer commande.';
  end if;

  -- Valide la disponibilité de CHAQUE ligne avant la moindre écriture —
  -- une commande n'est jamais créée à moitié si une ligne pose problème
  -- (même garantie que le pré-contrôle client dans `CheckoutController`,
  -- désormais aussi imposée côté serveur).
  for v_group in select * from jsonb_array_elements(p_groups)
  loop
    for v_item in select * from jsonb_array_elements(v_group -> 'items')
    loop
      select stock_quantity, name into v_current_stock, v_product_name
        from public.products where id = (v_item ->> 'product_id');
      if v_current_stock is null then
        raise exception 'Produit introuvable : %', (v_item ->> 'product_id');
      end if;
      if v_current_stock < (v_item ->> 'quantity')::integer then
        raise exception 'Stock insuffisant pour % : % disponible(s), % demandé(s).',
          v_product_name, v_current_stock, (v_item ->> 'quantity')::integer;
      end if;
    end loop;
  end loop;

  for v_group in select * from jsonb_array_elements(p_groups)
  loop
    select coalesce(sum((item ->> 'unit_price_fcfa_snapshot')::integer * (item ->> 'quantity')::integer), 0)
      into v_group_subtotal
      from jsonb_array_elements(v_group -> 'items') as item;
    v_total := v_total + v_group_subtotal + coalesce((v_group ->> 'delivery_fee_fcfa')::integer, 0);
  end loop;
  if p_is_priority then
    v_total := v_total + p_priority_fee_fcfa;
  end if;

  insert into public.orders (
    id, client_id, client_display_name_snapshot, client_phone_snapshot, status, total_fcfa,
    delivery_address_label, delivery_city, delivery_details, delivery_latitude, delivery_longitude,
    fulfillment_method, courier_phone, alternate_phone, delivery_date, delivery_time_slot_label,
    is_priority, priority_fee_fcfa, supplier_message_type, supplier_message_text,
    supplier_message_voice_path, supplier_message_voice_duration_seconds,
    payment_method, payment_status, mobile_money_provider
  ) values (
    v_order_id, v_client_id, p_client_display_name_snapshot, p_client_phone_snapshot, 'pending', v_total,
    p_delivery_address_label, p_delivery_city, p_delivery_details, p_delivery_latitude, p_delivery_longitude,
    p_fulfillment_method::fulfillment_method, p_courier_phone, p_alternate_phone, p_delivery_date, p_delivery_time_slot_label,
    p_is_priority, case when p_is_priority then p_priority_fee_fcfa else 0 end,
    p_supplier_message_type::supplier_message_type, p_supplier_message_text,
    p_supplier_message_voice_path, p_supplier_message_voice_duration_seconds,
    p_payment_method::payment_method, p_payment_status::payment_status, p_mobile_money_provider::mobile_money_provider
  );

  for v_group in select * from jsonb_array_elements(p_groups)
  loop
    v_group_id := gen_random_uuid()::text;
    select coalesce(sum((item ->> 'unit_price_fcfa_snapshot')::integer * (item ->> 'quantity')::integer), 0)
      into v_group_subtotal
      from jsonb_array_elements(v_group -> 'items') as item;

    insert into public.order_supplier_groups (
      id, order_id, supplier_id, supplier_name, delivery_mode, delivery_fee_fcfa, subtotal_fcfa, status
    ) values (
      v_group_id, v_order_id, (v_group ->> 'supplier_id')::uuid, v_group ->> 'supplier_name',
      (v_group ->> 'delivery_mode')::delivery_mode, coalesce((v_group ->> 'delivery_fee_fcfa')::integer, 0),
      v_group_subtotal, 'pending'
    );

    for v_item in select * from jsonb_array_elements(v_group -> 'items')
    loop
      insert into public.order_items (group_id, product_id, product_name_snapshot, unit_price_fcfa_snapshot, quantity)
      values (
        v_group_id, v_item ->> 'product_id', v_item ->> 'product_name_snapshot',
        (v_item ->> 'unit_price_fcfa_snapshot')::integer, (v_item ->> 'quantity')::integer
      );

      update public.products set stock_quantity = stock_quantity - (v_item ->> 'quantity')::integer
        where id = (v_item ->> 'product_id');

      insert into public.stock_movements (id, product_id, quantity_delta, reason)
      values (gen_random_uuid()::text, v_item ->> 'product_id', -(v_item ->> 'quantity')::integer, 'sale');
    end loop;
  end loop;

  return v_order_id;
end;
$$;

revoke all on function public.place_order(
  text, text, jsonb, text, text, text, double precision, double precision, text, text, text,
  timestamptz, text, boolean, integer, text, text, text, integer, text, text, text
) from public, anon;
grant execute on function public.place_order(
  text, text, jsonb, text, text, text, double precision, double precision, text, text, text,
  timestamptz, text, boolean, integer, text, text, text, integer, text, text, text
) to authenticated;

-- Mirror exact de `isValidTransition` (order_status_transitions.dart) +
-- de `_deriveOverallStatus` (InMemoryOrderDatasource) — un fournisseur
-- (ou le staff, sur le storefront MTC partagé) ne peut faire avancer que
-- SON PROPRE groupe, jamais un autre.
create or replace function public.update_order_group_status(
  p_order_id text,
  p_group_id text,
  p_status text,
  p_cancellation_reason text default null,
  p_cancelled_by text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_status public.order_status;
  v_group_supplier_id uuid;
  v_new_status public.order_status := p_status::public.order_status;
  v_overall public.order_status;
  v_forward_order constant public.order_status[] :=
    array['pending', 'confirmed', 'preparing', 'in_transit', 'delivered']::public.order_status[];
begin
  select status, supplier_id into v_current_status, v_group_supplier_id
    from public.order_supplier_groups
    where id = p_group_id and order_id = p_order_id;

  if v_current_status is null then
    raise exception 'Groupe fournisseur introuvable : %', p_group_id;
  end if;
  if v_group_supplier_id is distinct from public.operating_supplier_id() then
    raise exception 'Non autorisé à modifier ce groupe.';
  end if;

  if v_current_status = v_new_status
     or v_current_status = 'delivered' or v_current_status = 'cancelled' then
    raise exception 'Transition invalide : % → %.', v_current_status, v_new_status;
  end if;
  if v_new_status != 'cancelled'
     and array_position(v_forward_order, v_new_status) <= array_position(v_forward_order, v_current_status) then
    raise exception 'Transition invalide : % → %.', v_current_status, v_new_status;
  end if;

  update public.order_supplier_groups set
    status = v_new_status,
    cancellation_reason = case when v_new_status = 'cancelled' then p_cancellation_reason else null end,
    cancelled_by = case when v_new_status = 'cancelled' then p_cancelled_by::public.cancelled_by else null end
  where id = p_group_id;

  select
    case
      when bool_and(status = 'delivered') then 'delivered'
      when bool_or(status = 'cancelled') then 'cancelled'
      when bool_or(status = 'in_transit') then 'in_transit'
      when bool_or(status = 'preparing') then 'preparing'
      when bool_or(status = 'confirmed') then 'confirmed'
      else 'pending'
    end::public.order_status into v_overall
    from public.order_supplier_groups where order_id = p_order_id;

  update public.orders set status = v_overall where id = p_order_id;
end;
$$;

revoke all on function public.update_order_group_status(text, text, text, text, text) from public, anon;
grant execute on function public.update_order_group_status(text, text, text, text, text) to authenticated;

-- Realtime : les 3 méthodes `watch...` de `OrderRepository` en ont besoin
-- (plusieurs parties — client, fournisseur(s), staff — doivent voir les
-- changements des autres, contrairement au Lot 4 où un simple ré-appel
-- après sa propre écriture suffisait). `order_supplier_groups`/`order_items`
-- n'ont pas besoin d'être ajoutées séparément : `update_order_group_status`
-- met toujours aussi à jour la ligne `orders` correspondante (statut
-- global recalculé), donc écouter `orders` seule suffit à détecter tout
-- changement pertinent et à redéclencher la requête imbriquée complète.
alter publication supabase_realtime add table public.orders;
