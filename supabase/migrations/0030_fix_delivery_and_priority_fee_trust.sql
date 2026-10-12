-- Suite de 0029 : `delivery_fee_fcfa` (par groupe) et `priority_fee_fcfa`
-- (au niveau commande) étaient, comme `unit_price_fcfa_snapshot` avant eux,
-- pris tels quels dans `p_groups`/`p_priority_fee_fcfa` sans aucune
-- vérification serveur. Un appel RPC direct pouvait donc aussi mettre ces
-- deux montants à 0 (ou n'importe quelle valeur) sans toucher au prix des
-- articles.
--
-- `delivery_fee_fcfa` n'a pas de colonne "prix de référence" comme
-- `products.price_fcfa` : c'est une formule (distance, poids, catégorie),
-- portée ici depuis `lib/features/orders/domain/delivery_pricing.dart`
-- (`computeHomeDeliveryFeeFcfa`) et `lib/core/utils/geo_distance.dart`
-- (`GeoDistance.haversineKm`) — ligne à ligne, pour que l'estimation
-- affichée au client à l'écran de checkout corresponde exactement à ce que
-- le serveur facture. **Si la formule Dart change, ces fonctions SQL
-- doivent changer avec elle.** `priority_fee_fcfa` est un forfait fixe
-- (`priorityOrderFeeFcfa` dans `checkout_providers.dart`) : validé contre
-- cette constante plutôt que recalculé.
--
-- `self_delivery` reste à 0 côté serveur (aucune formule ne s'applique —
-- c'est le fournisseur qui livre lui-même, MTC ne facture rien pour ça),
-- exactement comme le fait déjà `supabase_order_repository.dart` côté client.

create or replace function public.haversine_km(
  p_lat1 double precision, p_lon1 double precision,
  p_lat2 double precision, p_lon2 double precision
) returns double precision
language plpgsql
immutable
as $$
declare
  v_dlat double precision := radians(p_lat2 - p_lat1);
  v_dlon double precision := radians(p_lon2 - p_lon1);
  v_a double precision;
begin
  v_a := sin(v_dlat / 2) ^ 2
    + cos(radians(p_lat1)) * cos(radians(p_lat2)) * sin(v_dlon / 2) ^ 2;
  return 6371.0 * 2 * atan2(sqrt(v_a), sqrt(1 - v_a));
end;
$$;

-- Miroir de `MalianCity` (`lib/core/mock_data/malian_locations.dart`) :
-- même 6 villes, mêmes coordonnées, même repli sur Bamako pour toute ville
-- non reconnue (`orElse: () => MalianCity.bamako`).
create or replace function public.malian_city_coordinates(p_city text)
returns table (lat double precision, lon double precision)
language sql
immutable
as $$
  select
    case p_city
      when 'Bamako' then 12.6392 when 'Sikasso' then 11.3167
      when 'Ségou' then 13.4317 when 'Mopti' then 14.4843
      when 'Kayes' then 14.4469 when 'Koutiala' then 12.3912
      else 12.6392
    end,
    case p_city
      when 'Bamako' then -8.0029 when 'Sikasso' then -5.6667
      when 'Ségou' then -6.2157 when 'Mopti' then -4.1824
      when 'Kayes' then -11.4443 when 'Koutiala' then -5.4642
      else -8.0029
    end;
$$;

-- Miroir de `_categorySurchargeFcfa` (`delivery_pricing.dart`).
create or replace function public.product_category_surcharge_fcfa(p_category public.product_category)
returns integer
language sql
immutable
as $$
  select case p_category
    when 'materiaux_construction' then 500
    when 'electronique' then 300
    when 'alimentation' then 200
    when 'artisanat' then 100
    when 'textiles_bogolan' then 0
    when 'autre' then 100
  end;
$$;

-- Miroir de `computeHomeDeliveryFeeFcfa` (`delivery_pricing.dart`) :
-- base + distance (plafonnée) + poids (plafonné) + pire surcharge de
-- catégorie du groupe, arrondi puis borné à [1000, 4000] FCFA.
create or replace function public.compute_mtc_delivery_fee_fcfa(
  p_supplier_city text,
  p_dest_lat double precision,
  p_dest_lon double precision,
  p_total_weight_kg double precision,
  p_categories public.product_category[]
) returns integer
language plpgsql
immutable
as $$
declare
  v_supplier_lat double precision;
  v_supplier_lon double precision;
  v_distance_km double precision;
  v_distance_contribution double precision;
  v_weight_contribution double precision;
  v_category_surcharge integer := 0;
  v_category public.product_category;
  v_raw double precision;
begin
  select lat, lon into v_supplier_lat, v_supplier_lon
    from public.malian_city_coordinates(p_supplier_city);
  v_distance_km := public.haversine_km(v_supplier_lat, v_supplier_lon, p_dest_lat, p_dest_lon);

  v_distance_contribution := least(greatest(v_distance_km * 20.0, 0), 1500.0);
  v_weight_contribution := least(greatest(p_total_weight_kg * 25.0, 0), 1500.0);

  foreach v_category in array coalesce(p_categories, '{}') loop
    v_category_surcharge := greatest(v_category_surcharge, public.product_category_surcharge_fcfa(v_category));
  end loop;

  v_raw := 1000 + v_distance_contribution + v_weight_contribution + v_category_surcharge;
  return greatest(least(round(v_raw::numeric)::integer, 4000), 1000);
end;
$$;

create or replace function public.place_order(
  p_client_display_name_snapshot text,
  p_client_phone_snapshot text,
  -- [{supplier_id, supplier_name, delivery_mode, delivery_fee_fcfa,
  --   items: [{product_id, variant_id, product_name_snapshot,
  --            variant_name_snapshot, unit_price_fcfa_snapshot, quantity}]}]
  -- `unit_price_fcfa_snapshot`/`delivery_fee_fcfa` en entrée ne sont jamais
  -- utilisés pour l'argent — voir la boucle de re-pricing ci-dessous.
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
  -- Frais de livraison MTC : réputés depuis le produit rejoint pour le prix,
  -- jamais depuis `p_groups`.
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

  -- Re-pricing : le prix et les frais de livraison facturés viennent
  -- toujours du serveur (`products`/`product_variants` + la formule de
  -- frais ci-dessus), jamais du JSON envoyé par le client. Construit
  -- `v_priced_groups`, une copie de `p_groups` où `unit_price_fcfa_snapshot`
  -- et `delivery_fee_fcfa` ont été remplacés par les valeurs serveur — tout
  -- le reste de la fonction opère ensuite sur cette copie fiable plutôt que
  -- sur `p_groups`.
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

      -- Poids/catégorie/ville vivent sur `products`, jamais sur la variante
      -- (une variante ne change que prix/stock/photos).
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

    -- `self_delivery` : le fournisseur livre lui-même, MTC ne facture rien.
    -- `mtc_delivery` : formule distance/poids/catégorie (jamais le JSON client).
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

  -- Forfait fixe (`priorityOrderFeeFcfa`, `checkout_providers.dart`) —
  -- validé contre la constante serveur, jamais pris tel quel du client.
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

-- `place_order` est `security definer` ; les grants ne changent pas mais on
-- les répète ici pour que ce fichier reste autoporteur si rejoué seul.
revoke all on function public.place_order(
  text, text, jsonb, text, text, text, double precision, double precision, text, text, text,
  timestamptz, text, boolean, integer, text, text, text, integer, text, text, text
) from public, anon;
grant execute on function public.place_order(
  text, text, jsonb, text, text, text, double precision, double precision, text, text, text,
  timestamptz, text, boolean, integer, text, text, text, integer, text, text, text
) to authenticated;
