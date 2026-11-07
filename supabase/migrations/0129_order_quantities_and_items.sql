-- Une commande ne se compose plus que de ce qui est réellement en vente.
--
-- ===========================================================================
-- 1. ÉLEVÉ — les quantités négatives (signalé par l'audit)
-- ===========================================================================
--
-- `place_order` multipliait le prix par la quantité reçue, sans la regarder.
-- Mesuré le 25/10/2026, en client2, dans une transaction annulée :
--
--   boubou 45 000 FCFA × 1  +  sac 15 000 FCFA × −3
--   → total 0 FCFA, et le stock de sacs passe de 60 à 63
--
-- Le décrément de stock (`stock_quantity - v_quantity`) devenait un
-- incrément, et la garde `stock_quantity >= v_quantity` passait toujours.
-- `preview_promo_code` acceptait la même ligne, et pouvait donc valider un
-- code sur un panier qui n'existe pas.
--
-- Remède : un entier d'au moins 1, vérifié avant tout calcul, dans les deux
-- fonctions ; et des contraintes `check` sur les tables, pour qu'aucun
-- chemin futur ne puisse l'oublier.
--
-- ===========================================================================
-- 2. Ce que la même lecture a montré, et que l'audit n'avait pas vu
-- ===========================================================================
--
-- `place_order` est `security definer` : elle lit les produits hors RLS. Le
-- client décrivait son panier, et la fonction le croyait sur trois points
-- de plus. Mesuré dans la même transaction :
--
--   * un groupe au nom d'Artisanat Sikasso pouvait porter le boubou de
--     Bogolan Bamako. Le stock de Bogolan baissait sans que la boutique ne
--     voie jamais la commande, et Artisanat se voyait créditer la vente ;
--   * un produit en pause (ou en brouillon, ou d'une boutique supprimée ou
--     non vérifiée) se commandait encore, pourvu qu'on connaisse son
--     identifiant — celui d'un panier ancien, par exemple ;
--   * la livraison MTC passait sur un produit que la boutique ne confie pas
--     à MTC (`allows_mtc_delivery = false`).
--
-- Et les noms figés sur la commande (`product_name_snapshot`,
-- `variant_name_snapshot`, `supplier_name`) venaient du client : ce que le
-- fournisseur lit pour préparer le colis était ce que l'acheteur avait
-- voulu écrire. Ils viennent désormais de la base.

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
  -- `0129` : ce que la commande ne croit plus sur parole.
  v_group_supplier uuid;
  v_group_mode text;
  v_seen_suppliers uuid[] := '{}';
  v_product record;
  v_variant_name text;
begin
  if v_client_id is null then
    raise exception 'Vous devez être connecté pour passer commande.';
  end if;

  -- Le décrément de stock plus bas modifie un produit qui n'appartient
  -- jamais à l'acheteur — cf. le commentaire de tête de ce fichier.
  perform set_config('app.trusted_product_write', 'on', true);

  -- Une commande vide n'a rien à livrer ; une boutique sans article non
  -- plus. Le dire plutôt que d'enregistrer une commande à 0 FCFA.
  if jsonb_typeof(p_groups) is distinct from 'array' or jsonb_array_length(p_groups) = 0 then
    raise exception 'Une commande porte au moins un article.';
  end if;

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
    -- `for update` **avant** de compter : sans ce verrou, deux commandes
    -- simultanées du même client lisent toutes deux « jamais utilisé » et
    -- consomment chacune le code. Le plafond global tenait (son incrément
    -- est conditionnel), mais le « une fois par client » ne tenait pas.
    --
    -- Le verrou est pris ici et gardé jusqu'à la fin de la transaction : la
    -- seconde commande attend, puis recompte sur un instantané qui contient
    -- l'utilisation de la première.
    select supplier_id, min_order_fcfa, max_uses_per_client
      into v_code_supplier, v_code_min, v_code_per_client
      from public.promo_codes where id = v_code_id for update;
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

    -- La boutique et le mode de livraison du groupe, vérifiés une fois.
    -- Une même boutique ne revient pas dans un second groupe : son code
    -- promo y serait consommé deux fois.
    v_group_supplier := (v_group ->> 'supplier_id')::uuid;
    v_group_mode := v_group ->> 'delivery_mode';
    if v_group_supplier is null or v_group_supplier = any (v_seen_suppliers) then
      raise exception 'Chaque boutique n''apparaît qu''une fois dans une commande.';
    end if;
    v_seen_suppliers := v_seen_suppliers || v_group_supplier;
    if v_group_mode is null or v_group_mode not in ('self_delivery', 'mtc_delivery') then
      raise exception 'Mode de livraison inconnu : %.', coalesce(v_group_mode, 'aucun');
    end if;
    if jsonb_typeof(v_group -> 'items') is distinct from 'array'
       or jsonb_array_length(v_group -> 'items') = 0 then
      raise exception 'Une commande porte au moins un article.';
    end if;

    for v_item in select * from jsonb_array_elements(v_group -> 'items')
    loop
      v_variant_id := nullif(v_item ->> 'variant_id', '');

      -- La quantité d'abord (`0129`). Un entier d'au moins 1, rien d'autre :
      -- « -3 » faisait baisser le total et **remonter** le stock, puisque
      -- le décrément plus bas soustrayait un nombre négatif. Le motif refuse
      -- aussi « 1.5 », « 2e3 » et le vide, avant tout calcul.
      if coalesce(v_item ->> 'quantity', '') !~ '^[0-9]{1,6}$'
         or (v_item ->> 'quantity')::integer < 1 then
        raise exception 'Quantité invalide (%) : chaque article se commande au moins une fois.',
          coalesce(v_item ->> 'quantity', 'aucune');
      end if;
      v_quantity := (v_item ->> 'quantity')::integer;

      -- Le produit tel que la base le connaît, pas tel que le panier le
      -- décrit (`0129`). Cette fonction est `security definer` : elle voit
      -- les brouillons, les pauses et les boutiques supprimées, que le
      -- client, lui, ne voit pas.
      select p.supplier_id, p.name, p.city, p.weight_kg, p.category, p.status,
             p.is_supplier_verified, p.allows_self_delivery, p.allows_mtc_delivery,
             s.deleted_at is null as boutique_ouverte
        into v_product
        from public.products p
        join public.suppliers s on s.id = p.supplier_id
       where p.id = (v_item ->> 'product_id');
      if not found then
        raise exception 'Produit introuvable : %', (v_item ->> 'product_id');
      end if;
      -- Sans cette garde, un groupe au nom d'une boutique pouvait porter les
      -- produits d'une autre : le stock de la seconde baissait sans qu'elle
      -- voie la commande, et la première encaissait la vente.
      if v_product.supplier_id is distinct from v_group_supplier then
        raise exception 'Le produit « % » n''est pas vendu par cette boutique.', v_product.name;
      end if;
      if v_product.status <> 'active' or not v_product.is_supplier_verified
         or not v_product.boutique_ouverte then
        raise exception 'Le produit « % » n''est plus en vente.', v_product.name;
      end if;
      if v_group_mode = 'mtc_delivery' and not v_product.allows_mtc_delivery then
        raise exception 'Le produit « % » n''est pas proposé en livraison MTC.', v_product.name;
      end if;
      if v_group_mode = 'self_delivery' and not v_product.allows_self_delivery then
        raise exception 'Le produit « % » n''est pas livré par la boutique.', v_product.name;
      end if;

      -- Le prix part désormais de `effective_unit_price_fcfa` (`0062`) :
      -- même lecture qu'avant (produit ou variante), remises appliquées par
      -- la base. La quantité compte, puisqu'une remise peut en dépendre.
      v_unit_price := public.effective_unit_price_fcfa(
        v_item ->> 'product_id',
        v_variant_id,
        v_quantity
      );
      if v_unit_price is null then
        raise exception 'Produit introuvable : %', (v_item ->> 'product_id');
      end if;

      -- Les noms figés sur la commande sont ceux de la base : le fournisseur
      -- les lit pour préparer le colis, le client ne les choisit pas.
      v_variant_name := null;
      if v_variant_id is not null then
        select v.name into v_variant_name
          from public.product_variants v
         where v.id = v_variant_id and v.product_id = (v_item ->> 'product_id');
      end if;

      v_supplier_city := coalesce(v_supplier_city, v_product.city);
      v_total_weight_kg := v_total_weight_kg + v_product.weight_kg * v_quantity;
      v_categories := array_append(v_categories, v_product.category);

      v_group_subtotal := v_group_subtotal + v_unit_price * v_quantity;
      v_priced_items := v_priced_items || jsonb_build_object(
        'product_id', v_item ->> 'product_id',
        'variant_id', v_variant_id,
        'product_name_snapshot', v_product.name,
        'variant_name_snapshot', v_variant_name,
        'unit_price_fcfa_snapshot', v_unit_price,
        'quantity', v_quantity
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
      'supplier_id', v_group_supplier,
      -- Le nom de la boutique, lu chez elle (`0129`).
      'supplier_name', (select s.business_name from public.suppliers s where s.id = v_group_supplier),
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
    id, client_id, client_display_name_snapshot, status, total_fcfa,
    delivery_city,
    fulfillment_method, delivery_date, delivery_time_slot_label,
    is_priority, priority_fee_fcfa, supplier_message_type, supplier_message_text,
    supplier_message_voice_path, supplier_message_voice_duration_seconds,
    payment_method, payment_status, mobile_money_provider
  ) values (
    v_order_id, v_client_id, p_client_display_name_snapshot, 'pending', v_total,
    p_delivery_city,
    p_fulfillment_method::fulfillment_method, p_delivery_date, p_delivery_time_slot_label,
    p_is_priority, v_priority_fee,
    p_supplier_message_type::supplier_message_type, p_supplier_message_text,
    p_supplier_message_voice_path, p_supplier_message_voice_duration_seconds,
    p_payment_method::payment_method, 'pending_on_delivery'::payment_status, p_mobile_money_provider::mobile_money_provider
  );

  -- Les numéros et l'adresse à part, dans la table que seule
  -- `client_contact` lit (`0120`). Le numéro du compte sert de repli : une
  -- commande sans numéro joignable ne pourrait pas être livrée.
  insert into public.order_contacts (
    order_id, client_phone, courier_phone, alternate_phone,
    address_label, address_details, latitude, longitude
  ) values (
    v_order_id,
    coalesce(
      nullif(btrim(p_client_phone_snapshot), ''),
      (select p.phone_number from public.profiles p where p.id = v_client_id)
    ),
    nullif(btrim(p_courier_phone), ''),
    nullif(btrim(p_alternate_phone), ''),
    p_delivery_address_label,
    coalesce(p_delivery_details, ''),
    p_delivery_latitude,
    p_delivery_longitude
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

;

CREATE OR REPLACE FUNCTION public.preview_promo_code(p_code text, p_lines jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_client uuid := auth.uid();
  v_code_id text;
  v_code public.promo_codes%rowtype;
  v_supplier_ids uuid[];
  v_line jsonb;
  v_product_id text;
  v_variant_id text;
  v_quantity integer;
  v_base integer;
  v_effective integer;
  v_with_code integer;
  v_best integer;
  v_group_subtotal integer := 0;
  v_discount integer := 0;
  v_lines jsonb := '[]'::jsonb;
  v_used_by_client integer;
begin
  if v_client is null then
    return jsonb_build_object('valid', false, 'reason', 'Connectez-vous pour utiliser un code.');
  end if;

  select array_agg(distinct p.supplier_id) into v_supplier_ids
    from jsonb_array_elements(p_lines) l
    join public.products p on p.id = (l ->> 'product_id');

  v_code_id := public.resolve_promo_code(p_code, coalesce(v_supplier_ids, '{}'));
  if v_code_id is null then
    return jsonb_build_object(
      'valid', false,
      'reason', 'Code inconnu, expiré, ou sans effet sur les articles de ce panier.'
    );
  end if;
  select * into v_code from public.promo_codes where id = v_code_id;

  if v_code.max_uses is not null and v_code.uses_count >= v_code.max_uses then
    return jsonb_build_object('valid', false, 'reason', 'Ce code a atteint sa limite d''utilisation.');
  end if;

  select count(*) into v_used_by_client
    from public.promo_code_redemptions
   where promo_code_id = v_code_id and client_id = v_client;
  if v_used_by_client >= v_code.max_uses_per_client then
    return jsonb_build_object('valid', false, 'reason', 'Vous avez déjà utilisé ce code.');
  end if;

  -- Le panier de **ce** fournisseur : le minimum de commande s'entend chez
  -- lui, pas sur l'ensemble d'un panier multi-boutiques.
  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    v_product_id := v_line ->> 'product_id';
    v_variant_id := v_line ->> 'variant_id';
    -- Même règle que `place_order` (`0129`) : une quantité négative faisait
    -- passer un code sur un panier qui n'aurait jamais existé.
    if (v_line ->> 'quantity') is not null
       and ((v_line ->> 'quantity') !~ '^[0-9]{1,6}$' or (v_line ->> 'quantity')::integer < 1) then
      return jsonb_build_object(
        'valid', false,
        'reason', 'Quantité invalide : chaque article se commande au moins une fois.'
      );
    end if;
    v_quantity := coalesce((v_line ->> 'quantity')::integer, 1);

    if (select supplier_id from public.products where id = v_product_id)
       is distinct from v_code.supplier_id then
      continue;
    end if;

    if v_variant_id is null then
      select price_fcfa into v_base from public.products where id = v_product_id;
    else
      select price_fcfa into v_base from public.product_variants
       where id = v_variant_id and product_id = v_product_id;
    end if;
    if v_base is null then continue; end if;

    v_effective := public.effective_unit_price_fcfa(v_product_id, v_variant_id, v_quantity);
    v_group_subtotal := v_group_subtotal + v_effective * v_quantity;

    v_with_code := public.promo_code_unit_price_fcfa(v_code_id, v_product_id, v_base);
    if v_with_code is null then continue; end if;

    -- Pas de cumul : la meilleure des deux remises, pas leur somme.
    v_best := least(v_effective, v_with_code);
    if v_best >= v_effective then continue; end if;

    v_discount := v_discount + (v_effective - v_best) * v_quantity;
    v_lines := v_lines || jsonb_build_object(
      'product_id', v_product_id,
      'quantity', v_quantity,
      'unit_discount_fcfa', v_effective - v_best
    );
  end loop;

  if v_code.min_order_fcfa is not null and v_group_subtotal < v_code.min_order_fcfa then
    return jsonb_build_object(
      'valid', false,
      'reason', 'Ce code demande une commande d''au moins '
                || v_code.min_order_fcfa || ' FCFA chez ce vendeur.'
    );
  end if;

  if v_discount = 0 then
    return jsonb_build_object(
      'valid', false,
      'reason', 'Ce code n''améliore pas les remises déjà en cours sur ces articles.'
    );
  end if;

  return jsonb_build_object(
    'valid', true,
    'code', v_code.code,
    'percent', v_code.percent,
    'supplier_id', v_code.supplier_id,
    'discount_fcfa', v_discount,
    'lines', v_lines
  );
end;
$function$

;

-- ===========================================================================
-- 3. Les contraintes
-- ===========================================================================
--
-- `not valid` puis validation à part : une base qui porte déjà des lignes
-- fausses (une commande à « −3 sacs » passée avant ce correctif) ne doit pas
-- faire échouer la migration. La contrainte protège aussitôt toute nouvelle
-- ligne ; la validation des anciennes est tentée, et son échec seulement
-- signalé, avec la requête qui retrouve les lignes en cause.
alter table public.order_items
  drop constraint if exists order_items_quantity_positive,
  add constraint order_items_quantity_positive check (quantity > 0) not valid,
  drop constraint if exists order_items_unit_price_not_negative,
  add constraint order_items_unit_price_not_negative check (unit_price_fcfa_snapshot >= 0) not valid;

alter table public.cart_items
  drop constraint if exists cart_items_quantity_positive,
  add constraint cart_items_quantity_positive check (quantity > 0) not valid;

alter table public.promo_code_redemption_items
  drop constraint if exists promo_code_redemption_items_quantity_positive,
  add constraint promo_code_redemption_items_quantity_positive check (quantity > 0) not valid;

alter table public.order_supplier_groups
  drop constraint if exists order_supplier_groups_amounts_not_negative,
  add constraint order_supplier_groups_amounts_not_negative
    check (subtotal_fcfa >= 0 and delivery_fee_fcfa >= 0) not valid;

alter table public.orders
  drop constraint if exists orders_total_not_negative,
  add constraint orders_total_not_negative check (total_fcfa >= 0) not valid;

do $$
declare
  v_contrainte record;
begin
  for v_contrainte in
    select * from (values
      ('order_items', 'order_items_quantity_positive'),
      ('order_items', 'order_items_unit_price_not_negative'),
      ('cart_items', 'cart_items_quantity_positive'),
      ('promo_code_redemption_items', 'promo_code_redemption_items_quantity_positive'),
      ('order_supplier_groups', 'order_supplier_groups_amounts_not_negative'),
      ('orders', 'orders_total_not_negative')
    ) as c(tbl, nom)
  loop
    begin
      execute format('alter table public.%I validate constraint %I', v_contrainte.tbl, v_contrainte.nom);
    exception when check_violation then
      raise warning 'Des lignes de % violent déjà % : la contrainte protège les nouvelles, '
        'les anciennes sont à examiner (voir supabase/snippets/audit_commandes_negatives.sql).',
        v_contrainte.tbl, v_contrainte.nom;
    end;
  end loop;
end $$;

notify pgrst, 'reload schema';
