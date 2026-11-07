-- `place_order` devient sensible aux variantes : chaque item de
-- `p_groups` peut porter un `variant_id` optionnel (item legacy sans
-- variante = `variant_id` absent/null, comportement inchangé). Remplace
-- aussi la double passe "vérifier puis écrire" (avec une fenêtre de race
-- non verrouillée entre les deux) par une mise à jour conditionnelle
-- atomique en une seule passe : comme tout le corps de la fonction
-- s'exécute déjà dans une transaction implicite, un `raise exception` non
-- capturé annule tout ce que l'appel a fait (y compris les décréments de
-- stock déjà appliqués plus tôt dans la même boucle) — la garantie
-- "tout ou rien" est donc préservée, tout en fermant la race que les
-- variantes auraient aggravée (plus de compteurs de stock indépendants).
--
-- Voir /Users/solomon/.claude/plans/sunny-splashing-token.md section 2.

create or replace function public.place_order(
  p_client_display_name_snapshot text,
  p_client_phone_snapshot text,
  -- [{supplier_id, supplier_name, delivery_mode, delivery_fee_fcfa,
  --   items: [{product_id, variant_id, product_name_snapshot,
  --            variant_name_snapshot, unit_price_fcfa_snapshot, quantity}]}]
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
  v_variant_id text;
  v_quantity integer;
begin
  if v_client_id is null then
    raise exception 'Vous devez être connecté pour passer commande.';
  end if;

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
      v_variant_id := v_item ->> 'variant_id';
      v_quantity := (v_item ->> 'quantity')::integer;

      if v_variant_id is null then
        update public.products
          set stock_quantity = stock_quantity - v_quantity
          where id = (v_item ->> 'product_id') and stock_quantity >= v_quantity
          returning stock_quantity into v_current_stock;
      else
        update public.product_variants
          set stock_quantity = stock_quantity - v_quantity
          where id = v_variant_id and product_id = (v_item ->> 'product_id')
            and stock_quantity >= v_quantity
          returning stock_quantity into v_current_stock;
      end if;

      if v_current_stock is null then
        if not exists (select 1 from public.products where id = (v_item ->> 'product_id')) then
          raise exception 'Produit introuvable : %', (v_item ->> 'product_id');
        end if;
        raise exception 'Stock insuffisant pour % : % demandé(s).',
          v_item ->> 'product_name_snapshot', v_quantity;
      end if;

      insert into public.order_items (
        group_id, product_id, variant_id, product_name_snapshot,
        variant_name_snapshot, unit_price_fcfa_snapshot, quantity
      ) values (
        v_group_id, v_item ->> 'product_id', v_variant_id, v_item ->> 'product_name_snapshot',
        v_item ->> 'variant_name_snapshot', (v_item ->> 'unit_price_fcfa_snapshot')::integer, v_quantity
      );

      insert into public.stock_movements (id, product_id, variant_id, quantity_delta, reason)
      values (gen_random_uuid()::text, v_item ->> 'product_id', v_variant_id, -v_quantity, 'sale');
    end loop;
  end loop;

  return v_order_id;
end;
$$;
