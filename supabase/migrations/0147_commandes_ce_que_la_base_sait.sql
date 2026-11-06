-- 0147 — Une commande dit ce que la base sait, pas ce que l'appelant
-- déclare (trouvé en corrigeant l'audit du 27/10/2026, le 05/11/2026).
--
--  * `place_order` n'est ouvert qu'aux comptes clients (`0146`).
--  * Le nom du client figé sur la commande — et poussé à la boutique dans
--    « Nouvelle commande » — venait du paramètre : on commandait sous le nom
--    « Service client MTC ». Il vient désormais du profil, ce que l'app
--    envoyait de toute façon (`checkout_controller.dart`, `user.displayName`).
--  * Une ligne sans variante sur un produit qui en a prenait le prix de la
--    moins chère, sans dire laquelle préparer : elle prend désormais la
--    variante par défaut, à son prix, et n'est refusée que sans elle.
--  * La course MTC se payait au départ de `products.city`, que la boutique
--    écrit sur chaque produit (constaté : 4 000 → 1 000 FCFA pour 277 km et
--    100 kg). Elle part de la ville de la boutique, et le devis affiché au
--    client (`fetch_pricing_inputs`) prend la même : le prix annoncé reste le
--    prix payé. Le poids, lui, reste déclaré par la boutique — rien en base
--    ne peut le vérifier ; c'est au retrait que le livreur le constate.
--  * `update_order_group_status` écrivait `cancelled_by` tel que reçu : une
--    boutique annulait « au nom du client », sans que le client soit averti
--    (`notify_order_status_change` se tait quand c'est le client qui
--    annule). La base le déduit de l'appelant.
--
-- Les deux fonctions sont reprises de leur définition en vigueur (après
-- `0129` et `0112`), ces passages seuls changés.

CREATE OR REPLACE FUNCTION public.place_order(p_client_display_name_snapshot text, p_client_phone_snapshot text, p_groups jsonb, p_delivery_address_label text, p_delivery_city text, p_delivery_details text, p_delivery_latitude double precision, p_delivery_longitude double precision, p_fulfillment_method text DEFAULT 'home_delivery'::text, p_courier_phone text DEFAULT NULL::text, p_alternate_phone text DEFAULT NULL::text, p_delivery_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_delivery_time_slot_label text DEFAULT NULL::text, p_is_priority boolean DEFAULT false, p_priority_fee_fcfa integer DEFAULT 0, p_supplier_message_type text DEFAULT 'none'::text, p_supplier_message_text text DEFAULT NULL::text, p_supplier_message_voice_path text DEFAULT NULL::text, p_supplier_message_voice_duration_seconds integer DEFAULT NULL::integer, p_payment_method text DEFAULT 'on_delivery'::text, p_payment_status text DEFAULT 'pending_on_delivery'::text, p_mobile_money_provider text DEFAULT NULL::text, p_promo_code text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_client_id uuid := auth.uid();
  -- Le nom figé sur la commande est celui du profil, pas celui que
  -- l'appelant écrit (`0147`) : la boutique le lit, et la notification
  -- « Nouvelle commande » le lui pousse.
  v_client_name text := coalesce(
    (select nullif(btrim(p.display_name), '') from public.profiles p where p.id = auth.uid()),
    'Client');
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
  -- Un livreur, une boutique ou le staff ne commandent pas (`0146`) : sans
  -- cette garde, un livreur commandait, se faisait proposer sa propre
  -- course, la clôturait avec le code du client et se notait.
  if not public.is_client() then
    raise exception 'Seul un compte client passe commande.' using errcode = '42501';
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
             p.has_variants, s.city as supplier_city,
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
      -- Un produit à variantes se commande par variante (`0147`) : sans elle,
      -- la ligne prenait le prix de la moins chère (l'agrégat du produit),
      -- ne disait pas laquelle préparer, et l'annulation rendait le stock au
      -- produit au lieu de la variante. Une ligne qui n'en dit rien — un
      -- panier rempli avant les variantes, par exemple — prend la variante
      -- par défaut de la boutique, à son vrai prix ; sans variante par
      -- défaut, le client choisit.
      if v_product.has_variants and v_variant_id is null then
        select v.id into v_variant_id
          from public.product_variants v
         where v.product_id = (v_item ->> 'product_id') and v.is_default
         order by v.display_order, v.id
         limit 1;
        if v_variant_id is null then
          raise exception 'Choisissez une variante pour « % ».', v_product.name;
        end if;
      end if;
      if not v_product.has_variants and v_variant_id is not null then
        raise exception 'Le produit « % » n''a pas de variante.', v_product.name;
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

      -- Le trajet part de la boutique, pas de la ville que la boutique écrit
      -- sur chaque produit (`0147`) : `products.city` baissait le prix de la
      -- course MTC à volonté. Même ville que celle du devis
      -- (`fetch_pricing_inputs`).
      v_supplier_city := coalesce(v_supplier_city, v_product.supplier_city, v_product.city);
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
    v_order_id, v_client_id, v_client_name, 'pending', v_total,
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
        v_client_name,
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
      v_client_name || ' — '
        || jsonb_array_length(v_group -> 'items') || ' article(s)',
      v_order_id
    );
  end loop;

  return v_order_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.update_order_group_status(p_order_id text, p_group_id text, p_status text, p_cancellation_reason text DEFAULT NULL::text, p_cancelled_by text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_current_status public.order_status;
  v_group_supplier_id uuid;
  v_order_client_id uuid;
  v_new_status public.order_status := p_status::public.order_status;
  v_forward_order constant public.order_status[] :=
    array['pending', 'confirmed', 'preparing', 'in_transit', 'delivered']::public.order_status[];
begin
  select g.status, g.supplier_id, o.client_id
    into v_current_status, v_group_supplier_id, v_order_client_id
    from public.order_supplier_groups g
    join public.orders o on o.id = g.order_id
    where g.id = p_group_id and g.order_id = p_order_id;

  if v_current_status is null then
    raise exception 'Groupe fournisseur introuvable : %', p_group_id;
  end if;

  if v_group_supplier_id is distinct from public.operating_supplier_id() then
    if v_order_client_id is distinct from auth.uid()
       or v_new_status != 'cancelled'
       or v_current_status != 'pending' then
      raise exception 'Non autorisé à modifier ce groupe.';
    end if;
  end if;

  if v_current_status = v_new_status
     or v_current_status = 'delivered' or v_current_status = 'cancelled' then
    raise exception 'Transition invalide : % → %.', v_current_status, v_new_status;
  end if;
  if v_new_status != 'cancelled'
     and array_position(v_forward_order, v_new_status)
         != array_position(v_forward_order, v_current_status) + 1 then
    raise exception 'Transition invalide : % → %.', v_current_status, v_new_status;
  end if;

  -- Qui annule se lit sur l'appelant, pas sur le paramètre (`0147`) : une
  -- boutique qui refusait une commande la signait « client » (ou « mtc »)
  -- et le client n'était pas averti. `p_cancelled_by` reste dans la
  -- signature pour les versions de l'app déjà installées, et ne sert plus.
  update public.order_supplier_groups set
    status = v_new_status,
    cancellation_reason = case when v_new_status = 'cancelled' then p_cancellation_reason else null end,
    cancelled_by = case
      when v_new_status <> 'cancelled' then null
      when v_group_supplier_id is not distinct from public.operating_supplier_id()
        then 'supplier'::public.cancelled_by
      else 'client'::public.cancelled_by
    end
  where id = p_group_id;

  -- Le résumé de la commande (`orders.status`) suit : le déclencheur
  -- `order_supplier_groups_sync_order_status` le recalcule (`0112`).
end;
$function$;

-- Le devis : la ville de la boutique, comme `place_order`. Reprise de `0068`,
-- cette clé seule changée.
create or replace function public.fetch_pricing_inputs(p_product_ids text[])
 returns jsonb
 language sql
 stable
 set search_path to 'public'
as $function$
  select coalesce(jsonb_object_agg(p.id, jsonb_build_object(
           'price_fcfa', p.price_fcfa,
           'weight_kg', p.weight_kg,
           'category', p.category,
           'city', coalesce((select s.city from public.suppliers s where s.id = p.supplier_id), p.city),
           'supplier_id', p.supplier_id,
           'supplier_name', p.supplier_name,
           'allows_self_delivery', p.allows_self_delivery,
           'allows_mtc_delivery', p.allows_mtc_delivery,
           'stock_quantity', p.stock_quantity,
           'variants', coalesce((
             select jsonb_object_agg(v.id, jsonb_build_object(
                      'price_fcfa', v.price_fcfa,
                      'stock_quantity', v.stock_quantity
                    ))
               from public.product_variants v where v.product_id = p.id
           ), '{}'::jsonb),
           'promotions', coalesce((
             select jsonb_agg(to_jsonb(pr))
               from public.product_promotions pr where pr.product_id = p.id
           ), '[]'::jsonb)
         )), '{}'::jsonb)
    from public.products p
   where p.id = any(p_product_ids);
$function$;
