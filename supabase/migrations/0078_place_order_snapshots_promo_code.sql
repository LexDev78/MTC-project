-- `place_order` fige le code utilisé sur l'utilisation.
--
-- Suite de `0077` : sans cela, la colonne resterait vide pour toute
-- commande future, et le client reverrait une remise sans code.
--
-- Reprise de la définition en vigueur, à cet ajout près.

CREATE OR REPLACE FUNCTION public.place_order(p_client_display_name_snapshot text, p_client_phone_snapshot text, p_groups jsonb, p_delivery_address_label text, p_delivery_city text, p_delivery_details text, p_delivery_latitude double precision, p_delivery_longitude double precision, p_fulfillment_method text DEFAULT 'home_delivery'::text, p_courier_phone text DEFAULT NULL::text, p_alternate_phone text DEFAULT NULL::text, p_delivery_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_delivery_time_slot_label text DEFAULT NULL::text, p_is_priority boolean DEFAULT false, p_priority_fee_fcfa integer DEFAULT 0, p_supplier_message_type text DEFAULT 'none'::text, p_supplier_message_text text DEFAULT NULL::text, p_supplier_message_voice_path text DEFAULT NULL::text, p_supplier_message_voice_duration_seconds integer DEFAULT NULL::integer, p_payment_method text DEFAULT 'on_delivery'::text, p_payment_status text DEFAULT 'pending_on_delivery'::text, p_mobile_money_provider text DEFAULT NULL::text, p_promo_code text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  -- Code promo (`0073`) : résolu une fois, appliqué groupe par groupe.
  v_code_id text;
  v_code_supplier uuid;
  v_code_min integer;
  v_code_per_client integer;
  v_supplier_ids uuid[];
  v_base_price integer;
  v_code_price integer;
  v_group_discount integer;
  v_promo_items jsonb;
  v_adjusted_items jsonb;
  v_consumed_code text;
  v_redemption_id text;
begin
  if v_client_id is null then
    raise exception 'Vous devez être connecté pour passer commande.';
  end if;

  -- Le décrément de stock plus bas modifie un produit qui n'appartient
  -- jamais à l'acheteur — cf. le commentaire de tête de ce fichier.
  perform set_config('app.trusted_product_write', 'on', true);

  -- Un code refusé fait échouer la commande, au lieu d'être ignoré : le
  -- client l'a saisi et vu son effet sur l'écran de paiement. Passer outre
  -- en silence lui prélèverait plus que ce qui était annoncé.
  if coalesce(btrim(p_promo_code), '') <> '' then
    select array_agg(distinct (g ->> 'supplier_id')::uuid) into v_supplier_ids
      from jsonb_array_elements(p_groups) g;
    v_code_id := public.resolve_promo_code(p_promo_code, coalesce(v_supplier_ids, '{}'));
    if v_code_id is null then
      raise exception 'Code promo inconnu, expiré, ou sans effet sur ce panier.';
    end if;
    select supplier_id, min_order_fcfa, max_uses_per_client
      into v_code_supplier, v_code_min, v_code_per_client
      from public.promo_codes where id = v_code_id;
    if (
      select count(*) from public.promo_code_redemptions
       where promo_code_id = v_code_id and client_id = v_client_id
    ) >= v_code_per_client then
      raise exception 'Vous avez déjà utilisé ce code promo.';
    end if;
  end if;

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
      -- Le prix part désormais de `effective_unit_price_fcfa` (`0062`) :
      -- même lecture qu'avant (produit ou variante), remises appliquées par
      -- la base. La quantité compte, puisqu'une remise peut en dépendre.
      v_unit_price := public.effective_unit_price_fcfa(
        v_item ->> 'product_id',
        v_variant_id,
        (v_item ->> 'quantity')::integer
      );
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

    -- Le code s'applique **après** le calcul du sous-total : le minimum de
    -- commande s'apprécie sur ce que le client dépense chez ce vendeur, et
    -- la remise ligne par ligne est la meilleure des deux, jamais leur
    -- somme (`0072`).
    v_group_discount := 0;
    v_promo_items := '[]'::jsonb;
    if v_code_id is not null
       and (v_group ->> 'supplier_id')::uuid = v_code_supplier
       and (v_code_min is null or v_group_subtotal >= v_code_min)
    then
      v_adjusted_items := '[]'::jsonb;
      for v_item in select * from jsonb_array_elements(v_priced_items)
      loop
        v_variant_id := v_item ->> 'variant_id';
        v_quantity := (v_item ->> 'quantity')::integer;
        v_unit_price := (v_item ->> 'unit_price_fcfa_snapshot')::integer;

        if v_variant_id is null then
          select price_fcfa into v_base_price
            from public.products where id = (v_item ->> 'product_id');
        else
          select price_fcfa into v_base_price
            from public.product_variants
            where id = v_variant_id and product_id = (v_item ->> 'product_id');
        end if;

        v_code_price := public.promo_code_unit_price_fcfa(
          v_code_id, v_item ->> 'product_id', v_base_price
        );
        if v_code_price is not null and v_code_price < v_unit_price then
          v_group_discount := v_group_discount
            + (v_unit_price - v_code_price) * v_quantity;
          v_promo_items := v_promo_items || jsonb_build_object(
            'product_id', v_item ->> 'product_id',
            'product_name_snapshot', v_item ->> 'product_name_snapshot',
            'quantity', v_quantity,
            'unit_discount_fcfa', v_unit_price - v_code_price
          );
          v_item := jsonb_set(
            v_item, '{unit_price_fcfa_snapshot}', to_jsonb(v_code_price)
          );
        end if;
        v_adjusted_items := v_adjusted_items || v_item;
      end loop;
      v_priced_items := v_adjusted_items;
      v_group_subtotal := v_group_subtotal - v_group_discount;
    end if;

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
      'promo_discount_fcfa', v_group_discount,
      'promo_items', v_promo_items,
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

    -- Consommation du code : écriture **conditionnelle**, pas un simple
    -- incrément. Deux clients qui paient en même temps liraient le même
    -- compteur et dépasseraient le plafond ; ici le second ne trouve pas de
    -- ligne à mettre à jour et sa commande est refusée.
    if v_code_id is not null
       and coalesce((v_group ->> 'promo_discount_fcfa')::integer, 0) > 0 then
      update public.promo_codes
         set uses_count = uses_count + 1
       where id = v_code_id
         and (max_uses is null or uses_count < max_uses)
      returning id into v_consumed_code;

      if v_consumed_code is null then
        raise exception 'Ce code promo a atteint sa limite d''utilisation.';
      end if;

      insert into public.promo_code_redemptions (
        id, promo_code_id, order_id, supplier_group_id, client_id,
        client_display_name_snapshot, discount_fcfa, code_snapshot
      ) values (
        gen_random_uuid()::text, v_code_id, v_order_id, v_group_id, v_client_id,
        p_client_display_name_snapshot,
        (v_group ->> 'promo_discount_fcfa')::integer,
        -- Figé : le fournisseur peut renommer ou supprimer son code, la
        -- commande passée doit rester lisible.
        (select code from public.promo_codes where id = v_code_id)
      ) returning id into v_redemption_id;

      insert into public.promo_code_redemption_items (
        id, redemption_id, product_id, product_name_snapshot,
        quantity, unit_discount_fcfa
      )
      select gen_random_uuid()::text, v_redemption_id, i ->> 'product_id',
             i ->> 'product_name_snapshot', (i ->> 'quantity')::integer,
             (i ->> 'unit_discount_fcfa')::integer
        from jsonb_array_elements(v_group -> 'promo_items') i;
    end if;

    -- Le fournisseur est prévenu ici et non par l'app (`0064`) : la
    -- notification part dans la transaction qui crée la commande, donc elle
    -- ne peut plus manquer parce qu'un appel a échoué après coup — ni être
    -- forgée par un compte qui n'a rien commandé.
    insert into public.notifications (id, user_id, type, title, body, reference_id)
    values (
      gen_random_uuid()::text,
      (v_group ->> 'supplier_id')::uuid,
      'new_order',
      'Nouvelle commande',
      coalesce(p_client_display_name_snapshot, 'Un client') || ' — '
        || jsonb_array_length(v_group -> 'items') || ' article(s)',
      v_order_id
    );
  end loop;

  return v_order_id;
end;
$function$
