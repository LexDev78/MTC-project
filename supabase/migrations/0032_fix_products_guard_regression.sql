-- Corrige une régression introduite par le garde-fou colonnes de 0031
-- (`guard_products_reviewer_columns`) : détecté par la suite de tests
-- complète (`checkout_flow_test.dart`, `notification_hooks_test.dart`,
-- `payment_and_supplier_message_test.dart` échouaient tous), pas par les
-- tests ciblés lancés après 0029/0030 — d'où l'intérêt de la suite
-- complète avant de considérer un correctif terminé.
--
-- Le garde-fou bloque tout UPDATE sur `products` qui touche autre chose que
-- `rating_average`/`rating_count`, sauf pour le propriétaire
-- (`operating_supplier_id()`) ou le staff. Mais deux écritures internes
-- légitimes ne passent ni par l'un ni par l'autre :
--   - `place_order` décrémente `stock_quantity` — appelé par le CLIENT qui
--     achète, jamais le fournisseur propriétaire du produit.
--   - `increment_product_view` incrémente `view_count` — appelable par
--     n'importe quel visiteur authentifié, jamais restreint au propriétaire.
-- Les deux sont déjà des RPC `security definer` avec leur propre logique
-- bornée (décrément conditionnel atomique pour l'un, `+1` pour l'autre) —
-- le garde-fou n'a pas besoin de les revalider, seulement de savoir qu'il
-- peut leur faire confiance. Remède : un flag local à la transaction
-- (`set_config(..., true)`, jamais persistant au-delà de l'appel RPC en
-- cours, sûr avec le pooling PgBouncer en mode transaction), posé par ces
-- deux fonctions et vérifié par le garde-fou.

create or replace function public.guard_products_reviewer_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null
     or public.is_staff()
     or old.supplier_id = public.operating_supplier_id()
     or current_setting('app.trusted_product_write', true) = 'on'
  then
    return new;
  end if;

  if to_jsonb(new) is distinct from (to_jsonb(old) || jsonb_build_object(
    'rating_average', new.rating_average,
    'rating_count', new.rating_count
  )) then
    raise exception 'Non autorisé à modifier ce produit au-delà de sa note.';
  end if;
  return new;
end;
$$;

create or replace function public.increment_product_view(p_product_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform set_config('app.trusted_product_write', 'on', true);
  update public.products set view_count = view_count + 1 where id = p_product_id;
end;
$$;

create or replace function public.place_order(
  p_client_display_name_snapshot text,
  p_client_phone_snapshot text,
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
  v_unit_price integer;
  v_priced_groups jsonb := '[]'::jsonb;
  v_priced_items jsonb;
  v_item_city text;
  v_item_weight_kg double precision;
  v_item_category public.product_category;
  v_supplier_city text;
  v_total_weight_kg double precision;
  v_categories public.product_category[];
  v_delivery_fee integer;
  v_priority_fee integer;
begin
  if v_client_id is null then
    raise exception 'Vous devez être connecté pour passer commande.';
  end if;

  -- Le décrément de stock plus bas modifie un produit qui n'appartient
  -- jamais à l'acheteur — cf. le commentaire de tête de ce fichier.
  perform set_config('app.trusted_product_write', 'on', true);

  for v_group in select * from jsonb_array_elements(p_groups)
  loop
    v_priced_items := '[]'::jsonb;
    v_group_subtotal := 0;
    v_total_weight_kg := 0;
    v_categories := '{}';
    v_supplier_city := null;

    for v_item in select * from jsonb_array_elements(v_group -> 'items')
    loop
      v_variant_id := v_item ->> 'variant_id';
      if v_variant_id is null then
        select price_fcfa into v_unit_price
          from public.products where id = (v_item ->> 'product_id');
      else
        select price_fcfa into v_unit_price
          from public.product_variants
          where id = v_variant_id and product_id = (v_item ->> 'product_id');
      end if;
      if v_unit_price is null then
        raise exception 'Produit introuvable : %', (v_item ->> 'product_id');
      end if;

      select city, weight_kg, category into v_item_city, v_item_weight_kg, v_item_category
        from public.products where id = (v_item ->> 'product_id');
      v_supplier_city := coalesce(v_supplier_city, v_item_city);
      v_total_weight_kg := v_total_weight_kg + v_item_weight_kg * (v_item ->> 'quantity')::integer;
      v_categories := array_append(v_categories, v_item_category);

      v_group_subtotal := v_group_subtotal + v_unit_price * (v_item ->> 'quantity')::integer;
      v_priced_items := v_priced_items || jsonb_build_object(
        'product_id', v_item ->> 'product_id',
        'variant_id', v_variant_id,
        'product_name_snapshot', v_item ->> 'product_name_snapshot',
        'variant_name_snapshot', v_item ->> 'variant_name_snapshot',
        'unit_price_fcfa_snapshot', v_unit_price,
        'quantity', (v_item ->> 'quantity')::integer
      );
    end loop;

    if (v_group ->> 'delivery_mode') = 'mtc_delivery' then
      v_delivery_fee := public.compute_mtc_delivery_fee_fcfa(
        v_supplier_city, p_delivery_latitude, p_delivery_longitude,
        v_total_weight_kg, v_categories
      );
    else
      v_delivery_fee := 0;
    end if;

    v_total := v_total + v_group_subtotal + v_delivery_fee;
    v_priced_groups := v_priced_groups || jsonb_build_object(
      'supplier_id', v_group ->> 'supplier_id',
      'supplier_name', v_group ->> 'supplier_name',
      'delivery_mode', v_group ->> 'delivery_mode',
      'delivery_fee_fcfa', v_delivery_fee,
      'subtotal_fcfa', v_group_subtotal,
      'items', v_priced_items
    );
  end loop;

  v_priority_fee := case when p_is_priority then 1000 else 0 end;
  v_total := v_total + v_priority_fee;

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
    p_is_priority, v_priority_fee,
    p_supplier_message_type::supplier_message_type, p_supplier_message_text,
    p_supplier_message_voice_path, p_supplier_message_voice_duration_seconds,
    p_payment_method::payment_method, p_payment_status::payment_status, p_mobile_money_provider::mobile_money_provider
  );

  for v_group in select * from jsonb_array_elements(v_priced_groups)
  loop
    v_group_id := gen_random_uuid()::text;

    insert into public.order_supplier_groups (
      id, order_id, supplier_id, supplier_name, delivery_mode, delivery_fee_fcfa, subtotal_fcfa, status
    ) values (
      v_group_id, v_order_id, (v_group ->> 'supplier_id')::uuid, v_group ->> 'supplier_name',
      (v_group ->> 'delivery_mode')::delivery_mode, (v_group ->> 'delivery_fee_fcfa')::integer,
      (v_group ->> 'subtotal_fcfa')::integer, 'pending'
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

revoke all on function public.place_order(
  text, text, jsonb, text, text, text, double precision, double precision, text, text, text,
  timestamptz, text, boolean, integer, text, text, text, integer, text, text, text
) from public, anon;
grant execute on function public.place_order(
  text, text, jsonb, text, text, text, double precision, double precision, text, text, text,
  timestamptz, text, boolean, integer, text, text, text, integer, text, text, text
) to authenticated;
