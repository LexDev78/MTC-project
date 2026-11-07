-- Le numéro et l'adresse du client ne regardent que celui qui livre.
--
-- Jusqu'ici ils vivaient dans `orders`, que lisent en entier le client, chaque
-- boutique de la commande, le livreur et l'administration. Une boutique
-- dont MTC livre le colis voyait donc le numéro du client, et toute boutique
-- gardait numéro et adresse indéfiniment, commande livrée comprise.
--
-- La règle voulue :
--
--   * le client voit toujours les siens ;
--   * le numéro ne se montre qu'à celui qui livre : le livreur qui a accepté
--     la course, ou la boutique quand elle livre elle-même ;
--   * l'adresse se montre à la boutique tant que sa part de commande est en
--     cours, et au livreur à qui la course est proposée ou confiée ;
--   * une fois la part livrée ou annulée, plus rien : ni numéro ni adresse,
--     pour la boutique comme pour le livreur. Il reste le nom, et la
--     discussion dans l'application.
--
-- Postgres ne filtre pas les colonnes ligne par ligne : une policy montre une
-- commande entière ou rien. Les coordonnées passent donc dans une table à
-- part, `order_contacts`, que personne ne lit directement (RLS sans aucune
-- policy, aucun droit pour `anon` ni `authenticated`). La seule lecture est
-- `client_contact(orders)`, une colonne calculée que PostgREST sert à côté de
-- la commande (`select=*,client_contact`) et qui ne rend que ce que la règle
-- autorise à celui qui demande.
--
-- La ville reste dans `orders` : elle ne désigne personne, et l'historique du
-- livreur s'en sert pour reconnaître un trajet (`0060`).
--
-- Le passage se fait sans perte : les coordonnées sont copiées, comparées
-- ligne à ligne à l'original, et les colonnes ne sont retirées de `orders`
-- que si tout concorde.

create table public.order_contacts (
  order_id text primary key references public.orders (id) on delete cascade,
  -- Le numéro du compte au moment de la commande.
  client_phone text not null,
  -- Le numéro donné pour la livraison, quand il diffère ; c'est lui qu'on
  -- appelle en premier.
  courier_phone text,
  alternate_phone text,
  address_label text not null,
  address_details text not null,
  latitude double precision not null,
  longitude double precision not null
);

alter table public.order_contacts enable row level security;
-- Aucune policy, et aucun droit : même un `grant` posé plus tard par erreur
-- ne rendrait aucune ligne. Tout passe par `client_contact`.
revoke all on public.order_contacts from public, anon, authenticated;

insert into public.order_contacts (
  order_id, client_phone, courier_phone, alternate_phone,
  address_label, address_details, latitude, longitude
)
select id, client_phone_snapshot, courier_phone, alternate_phone,
       delivery_address_label, delivery_details, delivery_latitude, delivery_longitude
  from public.orders;

do $$
declare
  v_ecarts integer;
begin
  if (select count(*) from public.order_contacts) <> (select count(*) from public.orders) then
    raise exception 'Copie incomplète des coordonnées : rien n''est retiré de orders.';
  end if;
  select count(*) into v_ecarts
    from public.orders o
    join public.order_contacts c on c.order_id = o.id
   where c.client_phone is distinct from o.client_phone_snapshot
      or c.courier_phone is distinct from o.courier_phone
      or c.alternate_phone is distinct from o.alternate_phone
      or c.address_label is distinct from o.delivery_address_label
      or c.address_details is distinct from o.delivery_details
      or c.latitude is distinct from o.delivery_latitude
      or c.longitude is distinct from o.delivery_longitude;
  if v_ecarts <> 0 then
    raise exception '% commande(s) copiée(s) de travers : rien n''est retiré de orders.', v_ecarts;
  end if;
end;
$$;

alter table public.orders
  drop column client_phone_snapshot,
  drop column courier_phone,
  drop column alternate_phone,
  drop column delivery_address_label,
  drop column delivery_details,
  drop column delivery_latitude,
  drop column delivery_longitude;

-- ---- place_order : la commande d'un côté, les coordonnées de l'autre ----

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
$function$;

-- ---- le jeu de démonstration suit le même partage ----

CREATE OR REPLACE FUNCTION public.test_reset_and_seed()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
begin
  -- Un seul TRUNCATE ... CASCADE suffit : chaque autre table applicative
  -- référence (directement ou transitivement) `auth.users` ou `suppliers`,
  -- sauf `notifications` (aucune FK entrante), listée ici explicitement.
  -- `pickup_points` faisait partie de cette liste avant d'être supprimée
  -- (`0023_drop_dead_columns.sql` — table jamais réellement utilisée, le
  -- picker de retrait lit une liste statique en dur côté Dart).
  truncate table auth.users, public.suppliers, public.notifications cascade;

  -- ------------------------------------------------------------------------
  -- 1. Comptes (auth.users + auth.identities -> handle_new_user() en cascade)
  -- ------------------------------------------------------------------------
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token, email_change, email_change_token_new
  ) values
    (
      '00000000-0000-0000-0000-000000000000',
      '04060d99-e34d-520e-8b75-631ff4d3c10c', 'authenticated', 'authenticated',
      'client1@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"client","username_or_phone":"client1","display_name":"Awa Traoré","phone_number":"+22370000001"}',
      '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      '3355adef-385d-5eee-a565-815c8cf8e4d3', 'authenticated', 'authenticated',
      'client2@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"client","username_or_phone":"client2","display_name":"Moussa Diarra","phone_number":"+22370000002"}',
      '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'authenticated', 'authenticated',
      'fournisseur1@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"supplier_tiers","username_or_phone":"fournisseur1","display_name":"Ibrahima Coulibaly","phone_number":"+22376000001","business_name":"Bogolan Bamako","city":"Bamako","legal_type":"company"}',
      '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      'b6b1daf0-1c8e-583f-939f-687991d429ca', 'authenticated', 'authenticated',
      'fournisseur2@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"supplier_tiers","username_or_phone":"fournisseur2","display_name":"Fatoumata Keita","phone_number":"+22376000002","business_name":"Artisanat Sikasso","city":"Sikasso","legal_type":"company"}',
      '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      'bc82e68c-b1d9-538a-a8ed-8393a5ba739f', 'authenticated', 'authenticated',
      'fournisseur3@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"supplier_tiers","username_or_phone":"fournisseur3","display_name":"Aïssata Sangaré","phone_number":"+22376000003","business_name":"Couture Kayes","city":"Kayes","legal_type":"individual"}',
      '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      'deb94bf5-bddb-5399-8010-3b0264c98f1a', 'authenticated', 'authenticated',
      'fournisseur4@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"supplier_tiers","username_or_phone":"fournisseur4","display_name":"Seydou Traoré","phone_number":"+22376000004","business_name":"Fruits Niono","city":"Niono","legal_type":"company"}',
      '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      '0354c601-5e09-57b6-a23c-affaa5acf0d0', 'authenticated', 'authenticated',
      'agent1@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"supplier_principal","username_or_phone":"agent1","display_name":"Agent MTC","phone_number":"+22378000001","staff_role":"agent"}',
      '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      '2358888a-b13d-56f8-858b-a0c63831b512', 'authenticated', 'authenticated',
      'admin1@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"supplier_principal","username_or_phone":"admin1","display_name":"Admin MTC","phone_number":"+22378000002","staff_role":"admin"}',
      '', '', '', ''
    ),
    -- fournisseur5-8 : les 4 fournisseurs tiers "de remplissage" du
    -- catalogue (multi-fournisseur), sans dossier KYC dans la narration —
    -- mais Lot 5+ a besoin de vraies sessions pour eux aussi (vue commande
    -- côté fournisseur, chat, avis...), donc ils passent par le même
    -- trigger `handle_new_user()` que fournisseur1-4 plutôt que d'être
    -- insérés directement dans `suppliers` (voir section 2 plus bas).
    (
      '00000000-0000-0000-0000-000000000000',
      'dbff9b88-4829-5eed-b15a-78c33431553f', 'authenticated', 'authenticated',
      'fournisseur5@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"supplier_tiers","username_or_phone":"fournisseur5","display_name":"Oumar Diallo","phone_number":"+22376000005","business_name":"Electro Bamako","city":"Bamako","legal_type":"company"}',
      '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      '2c66294c-e1d7-59f1-925c-5ab6703827f3', 'authenticated', 'authenticated',
      'fournisseur6@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"supplier_tiers","username_or_phone":"fournisseur6","display_name":"Mariam Coulibaly","phone_number":"+22376000006","business_name":"Alimentation Ségou","city":"Ségou","legal_type":"company"}',
      '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      '01e2be08-764b-5ea6-8a32-a1b5152497b1', 'authenticated', 'authenticated',
      'fournisseur7@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"supplier_tiers","username_or_phone":"fournisseur7","display_name":"Sekou Traoré","phone_number":"+22376000007","business_name":"Matériaux Koutiala","city":"Koutiala","legal_type":"company"}',
      '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      'b8e6fcc1-ef1c-5248-8ffa-5de27e9beebb', 'authenticated', 'authenticated',
      'fournisseur8@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"supplier_tiers","username_or_phone":"fournisseur8","display_name":"Aminata Konaté","phone_number":"+22376000008","business_name":"Tissus Mopti","city":"Mopti","legal_type":"company"}',
      '', '', '', ''
    );

  insert into auth.identities (
    id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  )
  select
    gen_random_uuid(), u.id::text, u.id,
    jsonb_build_object('sub', u.id::text, 'email', u.email),
    'email', now(), now(), now()
  from auth.users u
  where u.id in (
    '04060d99-e34d-520e-8b75-631ff4d3c10c', '3355adef-385d-5eee-a565-815c8cf8e4d3',
    'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'b6b1daf0-1c8e-583f-939f-687991d429ca',
    'bc82e68c-b1d9-538a-a8ed-8393a5ba739f', 'deb94bf5-bddb-5399-8010-3b0264c98f1a',
    '0354c601-5e09-57b6-a23c-affaa5acf0d0', '2358888a-b13d-56f8-858b-a0c63831b512',
    'dbff9b88-4829-5eed-b15a-78c33431553f', '2c66294c-e1d7-59f1-925c-5ab6703827f3',
    '01e2be08-764b-5ea6-8a32-a1b5152497b1', 'b8e6fcc1-ef1c-5248-8ffa-5de27e9beebb'
  );

  -- ------------------------------------------------------------------------
  -- 2. suppliers — complète les 9 fournisseurs
  -- ------------------------------------------------------------------------
  update public.suppliers set
    rating_average = 4.6, rating_count = 132, product_count = 4, verification_status = 'verified'
    where id = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3';

  update public.suppliers set
    rating_average = 0, rating_count = 0, product_count = 3, verification_status = 'pending'
    where id = 'b6b1daf0-1c8e-583f-939f-687991d429ca';

  update public.suppliers set
    rating_average = 0, rating_count = 0, product_count = 0, verification_status = 'unverified'
    where id = 'bc82e68c-b1d9-538a-a8ed-8393a5ba739f';

  update public.suppliers set
    rating_average = 0, rating_count = 0, product_count = 0, verification_status = 'rejected'
    where id = 'deb94bf5-bddb-5399-8010-3b0264c98f1a';

  -- fournisseur5-8 (Electro Bamako, Alimentation Ségou, Matériaux Koutiala,
  -- Tissus Mopti) : `suppliers` déjà créé par `handle_new_user()` ci-dessus
  -- (section 1) — complète juste les stats, comme pour fournisseur1-4.
  update public.suppliers set
    rating_average = 4.2, rating_count = 54, product_count = 4, verification_status = 'verified'
    where id = 'dbff9b88-4829-5eed-b15a-78c33431553f';

  update public.suppliers set
    rating_average = 4.8, rating_count = 210, product_count = 4, verification_status = 'verified'
    where id = '2c66294c-e1d7-59f1-925c-5ab6703827f3';

  update public.suppliers set
    rating_average = 3.9, rating_count = 41, product_count = 3, verification_status = 'verified'
    where id = '01e2be08-764b-5ea6-8a32-a1b5152497b1';

  update public.suppliers set
    rating_average = 4.4, rating_count = 76, product_count = 3, verification_status = 'verified'
    where id = 'b8e6fcc1-ef1c-5248-8ffa-5de27e9beebb';

  insert into public.suppliers (id, business_name, supplier_type, city, rating_average, rating_count, product_count) values
    ('3331cbb4-0a65-5f94-9812-fe4270e50fe2', 'MTC Officiel', 'principal', 'Bamako', 4.9, 340, 4);

  -- ------------------------------------------------------------------------
  -- 3. products (25)
  -- ------------------------------------------------------------------------
  insert into public.products (
    id, supplier_id, supplier_name, supplier_type, name, description, category,
    price_fcfa, stock_quantity, image_urls, city, rating_average, rating_count,
    allows_self_delivery, allows_mtc_delivery, weight_kg, is_supplier_verified,
    sizes, colors, region
  ) values
    ('b0fe527e-1f73-55e6-b24e-4d985576d473', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'Bogolan Bamako', 'tiers',
     'Tissu Bogolan traditionnel', 'Tissu bogolan teint et peint à la main selon la tradition malienne, 2m x 1,5m.',
     'textiles_bogolan', 25000, 40,
     array['assets/images/products/textiles/fabric.jpg','assets/images/products/textiles/fabric_2.jpg'],
     'Bamako', 4.6, 132, true, true, 0.6, true, '{}', array['Marron','Ocre','Noir','Beige'], 'mali'),

    ('62599202-a3f0-5adc-ae1c-fe2a691adf92', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'Bogolan Bamako', 'tiers',
     'Boubou en bogolan brodé', 'Boubou homme brodé main, tissu bogolan 100% coton, plusieurs tailles disponibles.',
     'textiles_bogolan', 45000, 15,
     array['assets/images/products/textiles/fabric.jpg','assets/images/products/textiles/fabric_2.jpg'],
     'Bamako', 4.6, 132, true, true, 0.8, true, array['S','M','L','XL'], array['Marron','Noir','Ocre'], 'mali'),

    ('31987995-52ae-5c1f-81ce-b253f7fe55c3', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'Bogolan Bamako', 'tiers',
     'Sac en bogolan', 'Sac à main artisanal en tissu bogolan doublé, fermeture éclair.',
     'textiles_bogolan', 15000, 60,
     array['assets/images/products/artisanat/basket.jpg','assets/images/products/artisanat/basket_2.jpg'],
     'Bamako', 4.6, 132, true, false, 0.5, true, '{}', array['Marron','Noir'], 'mali'),

    ('9dde2022-87bd-5f9f-83dc-b0bc162a672c', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'Bogolan Bamako', 'tiers',
     'Masque décoratif Bambara', 'Masque décoratif en bois sculpté, style Bambara, pièce unique.',
     'artisanat', 20000, 20,
     array['assets/images/products/artisanat/mask.jpg'],
     'Bamako', 4.6, 132, true, true, 1.5, true, '{}', '{}', 'mali'),

    ('20bb8870-4dcb-5043-be5b-f56eddf74226', 'b8e6fcc1-ef1c-5248-8ffa-5de27e9beebb', 'Tissus Mopti', 'tiers',
     'Pagne Wax 6 yards', 'Pagne wax haute qualité, 6 yards, motifs colorés.',
     'textiles_bogolan', 18000, 80,
     array['assets/images/products/textiles/fabric.jpg','assets/images/products/textiles/fabric_2.jpg'],
     'Mopti', 4.4, 76, true, true, 0.9, true, '{}', array['Rouge','Bleu','Jaune','Vert'], 'mali'),

    ('c56dbd51-9952-5634-be42-2d05b5423276', 'b8e6fcc1-ef1c-5248-8ffa-5de27e9beebb', 'Tissus Mopti', 'tiers',
     'Foulard traditionnel', 'Foulard en coton local, teinture artisanale.',
     'textiles_bogolan', 8000, 100,
     array['assets/images/products/textiles/fabric.jpg','assets/images/products/textiles/fabric_2.jpg'],
     'Mopti', 4.4, 76, true, true, 0.2, true, '{}', array['Rouge','Bleu','Blanc'], 'mali'),

    ('4c7d3a05-200e-54dd-9b3f-0ba6309a4fa1', 'b8e6fcc1-ef1c-5248-8ffa-5de27e9beebb', 'Tissus Mopti', 'tiers',
     'Nappe brodée', 'Nappe de table brodée main, 8 personnes.',
     'textiles_bogolan', 22000, 25,
     array['assets/images/products/textiles/fabric.jpg','assets/images/products/textiles/fabric_2.jpg'],
     'Mopti', 4.4, 76, true, true, 0.7, true, '{}', array['Blanc','Beige'], 'mali'),

    ('044fa572-6712-5a24-8878-87a2560c512c', 'b6b1daf0-1c8e-583f-939f-687991d429ca', 'Artisanat Sikasso', 'tiers',
     'Masque en bois sculpté', 'Masque cérémoniel en bois local sculpté à la main.',
     'artisanat', 35000, 12,
     array['assets/images/products/artisanat/mask.jpg'],
     'Sikasso', 0, 0, true, true, 2.0, false, '{}', '{}', 'mali'),

    ('b242533d-856c-51d4-9d45-9ca895dc0bf7', 'b6b1daf0-1c8e-583f-939f-687991d429ca', 'Artisanat Sikasso', 'tiers',
     'Statuette Bambara', 'Statuette en bois dur, finition huilée.',
     'artisanat', 28000, 8,
     array['assets/images/products/artisanat/mask.jpg'],
     'Sikasso', 0, 0, true, true, 3.0, false, '{}', '{}', 'mali'),

    ('a4804b41-6e94-5c43-b867-aab3a9eaed5a', 'b6b1daf0-1c8e-583f-939f-687991d429ca', 'Artisanat Sikasso', 'tiers',
     'Panier tressé', 'Panier tressé à la main en fibres naturelles.',
     'artisanat', 6000, 50,
     array['assets/images/products/artisanat/basket.jpg','assets/images/products/artisanat/basket_2.jpg'],
     'Sikasso', 0, 0, true, true, 0.8, false, '{}', '{}', 'mali'),

    ('b3fff077-755b-578a-b5ec-1e00139e3029', 'dbff9b88-4829-5eed-b15a-78c33431553f', 'Electro Bamako', 'tiers',
     'Smartphone Android 64GB', 'Smartphone double SIM, 64GB, écran 6,5", garantie 12 mois.',
     'electronique', 85000, 30,
     array['assets/images/products/electronique/smartphone.jpg','assets/images/products/electronique/smartphone_2.jpg'],
     'Bamako', 4.2, 54, true, true, 0.3, true, array['64 Go','128 Go'], array['Noir','Bleu','Or'], 'chine'),

    ('7a383e7f-0bd1-5d70-9cf7-b17f561f89ef', 'dbff9b88-4829-5eed-b15a-78c33431553f', 'Electro Bamako', 'tiers',
     'Chargeur solaire portable', 'Panneau solaire pliable 20W avec batterie intégrée.',
     'electronique', 12000, 70,
     array['assets/images/products/electronique/solar_panel.jpg','assets/images/products/electronique/solar_panel_2.jpg'],
     'Bamako', 4.2, 54, true, true, 1.0, true, array['20W','40W'], array['Noir'], 'chine'),

    ('46628e1d-5faf-5e63-b42c-d7d88c15c15f', 'dbff9b88-4829-5eed-b15a-78c33431553f', 'Electro Bamako', 'tiers',
     'Radio FM à piles', 'Radio portable FM/AM, fonctionne à piles ou secteur.',
     'electronique', 9500, 45,
     array['assets/images/products/electronique/radio.jpg','assets/images/products/electronique/radio_2.jpg'],
     'Bamako', 4.2, 54, true, false, 0.7, true, '{}', array['Noir','Gris'], 'chine'),

    ('097c45a2-c2b7-5eec-ab84-59733cfcbffd', 'dbff9b88-4829-5eed-b15a-78c33431553f', 'Electro Bamako', 'tiers',
     'Enceinte Bluetooth', 'Enceinte portable Bluetooth 10W, autonomie 8h.',
     'electronique', 18000, 35,
     array['assets/images/products/electronique/speaker.jpg','assets/images/products/electronique/speaker_2.jpg'],
     'Bamako', 4.2, 54, true, true, 0.9, true, '{}', array['Noir','Rouge','Bleu'], 'chine'),

    ('d9d25e13-71ac-51c4-93f7-ed042a996500', '2c66294c-e1d7-59f1-925c-5ab6703827f3', 'Alimentation Ségou', 'tiers',
     'Riz local 25kg', 'Riz malien de qualité supérieure, sac de 25kg.',
     'alimentation', 12500, 200,
     array['assets/images/products/alimentation/rice.jpg','assets/images/products/alimentation/rice_2.jpg'],
     'Ségou', 4.8, 210, true, true, 25.0, true, '{}', '{}', 'mali'),

    ('09ccc6c1-6606-5da0-9be3-8c043d63f218', '2c66294c-e1d7-59f1-925c-5ab6703827f3', 'Alimentation Ségou', 'tiers',
     'Mil (sac 50kg)', 'Mil local, sac de 50kg, récolte récente.',
     'alimentation', 18000, 150,
     array['assets/images/products/alimentation/millet.jpg','assets/images/products/alimentation/millet_2.jpg'],
     'Ségou', 4.8, 210, true, true, 50.0, true, '{}', '{}', 'mali'),

    ('eb9c253a-3b34-5d56-b9e6-5cde5e37541d', '2c66294c-e1d7-59f1-925c-5ab6703827f3', 'Alimentation Ségou', 'tiers',
     'Huile d''arachide 5L', 'Huile d''arachide pure, pressée à froid, bidon de 5 litres.',
     'alimentation', 7500, 90,
     array['assets/images/products/alimentation/oil.jpg','assets/images/products/alimentation/oil_2.jpg'],
     'Ségou', 4.8, 210, true, true, 4.6, true, '{}', '{}', 'mali'),

    ('9f5263bf-73c5-5bff-8acf-de477f3e61b8', '2c66294c-e1d7-59f1-925c-5ab6703827f3', 'Alimentation Ségou', 'tiers',
     'Miel pur de brousse 1L', 'Miel artisanal récolté en brousse, pot de 1 litre.',
     'alimentation', 6000, 60,
     array['assets/images/products/alimentation/honey.jpg','assets/images/products/alimentation/honey_2.jpg'],
     'Ségou', 4.8, 210, true, true, 1.3, true, '{}', '{}', 'mali'),

    ('c3e13535-41ce-52c8-a0e2-89278e9f1526', '01e2be08-764b-5ea6-8a32-a1b5152497b1', 'Matériaux Koutiala', 'tiers',
     'Ciment (sac 50kg)', 'Ciment CPJ 32,5, sac de 50kg.',
     'materiaux_construction', 5000, 500,
     array['assets/images/products/materiaux/cement.jpg'],
     'Koutiala', 3.9, 41, true, true, 50.0, true, '{}', '{}', 'afrique_hors_mali'),

    ('a860f2ac-e6e1-5ea6-bb29-bee7ea51ab9c', '01e2be08-764b-5ea6-8a32-a1b5152497b1', 'Matériaux Koutiala', 'tiers',
     'Tôles ondulées (unité)', 'Tôle galvanisée ondulée, 2m, épaisseur 0,4mm.',
     'materiaux_construction', 8500, 120,
     array['assets/images/products/materiaux/corrugated_sheets.jpg','assets/images/products/materiaux/corrugated_sheets_2.jpg'],
     'Koutiala', 3.9, 41, true, true, 6.0, true, '{}', '{}', 'afrique_hors_mali'),

    ('3e9e198f-2909-53f2-913b-a819bb0a8702', '01e2be08-764b-5ea6-8a32-a1b5152497b1', 'Matériaux Koutiala', 'tiers',
     'Fer à béton 12mm (barre)', 'Barre de fer à béton torsadé, diamètre 12mm, 6m.',
     'materiaux_construction', 6500, 300,
     array['assets/images/products/materiaux/steel.jpg','assets/images/products/materiaux/steel_2.jpg'],
     'Koutiala', 3.9, 41, true, false, 5.3, true, '{}', '{}', 'afrique_hors_mali'),

    ('009e96cf-2edd-52fe-a9a4-473cfe6c093a', '3331cbb4-0a65-5f94-9812-fe4270e50fe2', 'MTC Officiel', 'principal',
     'Kit solaire MTC 100W', 'Kit solaire complet 100W avec batterie et régulateur, garantie MTC 24 mois.',
     'electronique', 95000, 25,
     array['assets/images/products/electronique/solar_panel.jpg','assets/images/products/electronique/solar_panel_2.jpg'],
     'Bamako', 4.9, 340, true, false, 8.0, true, array['100W','200W'], array['Noir'], 'europe'),

    ('84ac7169-d15e-5562-aa51-e2324cc118ac', '3331cbb4-0a65-5f94-9812-fe4270e50fe2', 'MTC Officiel', 'principal',
     'Sac de riz MTC Premium 25kg', 'Riz premium sélectionné et conditionné par MTC, sac de 25kg.',
     'alimentation', 14000, 100,
     array['assets/images/products/alimentation/rice.jpg','assets/images/products/alimentation/rice_2.jpg'],
     'Bamako', 4.9, 340, true, false, 25.0, true, '{}', '{}', 'mali'),

    ('d1ad6a10-1e0e-50b6-9537-864a6a1aaafe', '3331cbb4-0a65-5f94-9812-fe4270e50fe2', 'MTC Officiel', 'principal',
     'Pagne MTC édition limitée', 'Pagne exclusif MTC, édition limitée, tissage haut de gamme.',
     'textiles_bogolan', 30000, 40,
     array['assets/images/products/textiles/fabric.jpg','assets/images/products/textiles/fabric_2.jpg'],
     'Bamako', 4.9, 340, true, false, 0.9, true, '{}', array['Bleu','Vert','Or'], 'mali'),

    ('c61a70a7-0942-5a17-8ebc-6367bbb34056', '3331cbb4-0a65-5f94-9812-fe4270e50fe2', 'MTC Officiel', 'principal',
     'Ciment MTC Pro (sac 50kg)', 'Ciment haute résistance distribué par MTC, sac de 50kg.',
     'materiaux_construction', 5200, 400,
     array['assets/images/products/materiaux/cement.jpg'],
     'Bamako', 4.9, 340, true, false, 50.0, true, '{}', '{}', 'mali');

  -- ------------------------------------------------------------------------
  -- 4. cart_items (2) / favorites (1)
  -- ------------------------------------------------------------------------
  insert into public.cart_items (id, user_id, product_id, supplier_id, product_name_snapshot, unit_price_fcfa_snapshot, quantity) values
    (gen_random_uuid()::text, '3355adef-385d-5eee-a565-815c8cf8e4d3', 'd9d25e13-71ac-51c4-93f7-ed042a996500', '2c66294c-e1d7-59f1-925c-5ab6703827f3', 'Riz local 25kg', 12500, 2),
    (gen_random_uuid()::text, '3355adef-385d-5eee-a565-815c8cf8e4d3', 'b3fff077-755b-578a-b5ec-1e00139e3029', 'dbff9b88-4829-5eed-b15a-78c33431553f', 'Smartphone Android 64GB', 85000, 1);

  insert into public.favorites (id, user_id, product_id) values
    (gen_random_uuid()::text, '04060d99-e34d-520e-8b75-631ff4d3c10c', 'b0fe527e-1f73-55e6-b24e-4d985576d473');

  -- ------------------------------------------------------------------------
  -- 5. addresses (2)
  -- ------------------------------------------------------------------------
  insert into public.addresses (user_id, label, city, details, latitude, longitude) values
    ('04060d99-e34d-520e-8b75-631ff4d3c10c', 'Domicile', 'Bamako', 'Hippodrome, Rue 12, Porte 34', 12.6492, -7.9929),
    ('3355adef-385d-5eee-a565-815c8cf8e4d3', 'Domicile', 'Bamako', 'Badalabougou, Porte 45', 12.6242, -8.0109);

  -- ------------------------------------------------------------------------
  -- 6. orders / order_supplier_groups / order_items
  -- ------------------------------------------------------------------------
  insert into public.orders (
    id, client_id, client_display_name_snapshot, status, placed_at,
    total_fcfa, delivery_city
  ) values
    ('222a8eb1-59d2-57e4-a57e-7cc382ca72f1', '04060d99-e34d-520e-8b75-631ff4d3c10c', 'Awa Traoré', 'delivered',
     now() - interval '6 days', 25000, 'Bamako'),
    ('8b306ef7-cb08-5523-bb49-08b41eabc9ac', '04060d99-e34d-520e-8b75-631ff4d3c10c', 'Awa Traoré', 'in_transit',
     now() - interval '3 hours', 87000, 'Bamako'),
    ('f1db68f7-e2b3-5c0e-be0f-ed0098a40807', '3355adef-385d-5eee-a565-815c8cf8e4d3', 'Moussa Diarra', 'delivered',
     now() - interval '4 days', 12500, 'Bamako'),
    ('4d3b32a4-b09d-51ba-8b27-6d839083c131', '3355adef-385d-5eee-a565-815c8cf8e4d3', 'Moussa Diarra', 'in_transit',
     now() - interval '1 hour', 22000, 'Bamako'),
    ('1e31c8a6-d12e-59e4-ad3b-5af974e9dd19', '3355adef-385d-5eee-a565-815c8cf8e4d3', 'Moussa Diarra', 'delivered',
     now() - interval '12 days', 25000, 'Bamako'),
    ('ca6f1cdc-ffd4-5bc6-97c3-f33cd52465ee', '04060d99-e34d-520e-8b75-631ff4d3c10c', 'Awa Traoré', 'delivered',
     now() - interval '22 days', 12500, 'Bamako');

  -- Numéros et adresses à part (`0120`), comme `place_order` les range.
  insert into public.order_contacts (
    order_id, client_phone, address_label, address_details, latitude, longitude
  ) values
    ('222a8eb1-59d2-57e4-a57e-7cc382ca72f1', '+22370000001', 'Domicile', 'Hippodrome, Rue 12, Porte 34', 12.6492, -7.9929),
    ('8b306ef7-cb08-5523-bb49-08b41eabc9ac', '+22370000001', 'Domicile', 'Hippodrome, Rue 12, Porte 34', 12.6492, -7.9929),
    ('f1db68f7-e2b3-5c0e-be0f-ed0098a40807', '+22370000002', 'Domicile', 'Badalabougou, Porte 45', 12.6242, -8.0109),
    ('4d3b32a4-b09d-51ba-8b27-6d839083c131', '+22370000002', 'Domicile', 'Badalabougou, Porte 45', 12.6242, -8.0109),
    ('1e31c8a6-d12e-59e4-ad3b-5af974e9dd19', '+22370000002', 'Domicile', 'Badalabougou, Porte 45', 12.6242, -8.0109),
    ('ca6f1cdc-ffd4-5bc6-97c3-f33cd52465ee', '+22370000001', 'Domicile', 'Hippodrome, Rue 12, Porte 34', 12.6492, -7.9929);

  insert into public.order_supplier_groups (
    id, order_id, supplier_id, supplier_name, delivery_mode, delivery_fee_fcfa, subtotal_fcfa, status
  ) values
    ('efbd44fe-a725-533d-ba6c-a9c867b161cb', '222a8eb1-59d2-57e4-a57e-7cc382ca72f1', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'Bogolan Bamako', 'self_delivery', 0, 25000, 'delivered'),
    ('ca322249-2d39-5557-b97e-2e67eaeb4131', '8b306ef7-cb08-5523-bb49-08b41eabc9ac', 'dbff9b88-4829-5eed-b15a-78c33431553f', 'Electro Bamako', 'mtc_delivery', 2000, 85000, 'in_transit'),
    ('04f30401-2cc9-5e3b-be84-16c5e7ecc81e', 'f1db68f7-e2b3-5c0e-be0f-ed0098a40807', '2c66294c-e1d7-59f1-925c-5ab6703827f3', 'Alimentation Ségou', 'self_delivery', 0, 12500, 'delivered'),
    ('79cc954a-1d1a-5b33-8fc7-07c753975417', '4d3b32a4-b09d-51ba-8b27-6d839083c131', '01e2be08-764b-5ea6-8a32-a1b5152497b1', 'Matériaux Koutiala', 'mtc_delivery', 2000, 20000, 'in_transit'),
    ('821d2218-ee1c-50fa-b2b4-9d10895d950d', '1e31c8a6-d12e-59e4-ad3b-5af974e9dd19', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'Bogolan Bamako', 'self_delivery', 0, 25000, 'delivered'),
    ('4f06822c-a3e5-5c68-a4fa-8462c46de343', 'ca6f1cdc-ffd4-5bc6-97c3-f33cd52465ee', '2c66294c-e1d7-59f1-925c-5ab6703827f3', 'Alimentation Ségou', 'self_delivery', 0, 12500, 'delivered');

  insert into public.order_items (group_id, product_id, product_name_snapshot, unit_price_fcfa_snapshot, quantity) values
    ('efbd44fe-a725-533d-ba6c-a9c867b161cb', 'b0fe527e-1f73-55e6-b24e-4d985576d473', 'Tissu Bogolan traditionnel', 25000, 1),
    ('ca322249-2d39-5557-b97e-2e67eaeb4131', 'b3fff077-755b-578a-b5ec-1e00139e3029', 'Smartphone Android 64GB', 85000, 1),
    ('04f30401-2cc9-5e3b-be84-16c5e7ecc81e', 'd9d25e13-71ac-51c4-93f7-ed042a996500', 'Riz local 25kg', 12500, 1),
    ('79cc954a-1d1a-5b33-8fc7-07c753975417', 'c3e13535-41ce-52c8-a0e2-89278e9f1526', 'Ciment (sac 50kg)', 5000, 4),
    ('821d2218-ee1c-50fa-b2b4-9d10895d950d', 'b0fe527e-1f73-55e6-b24e-4d985576d473', 'Tissu Bogolan traditionnel', 25000, 1),
    ('4f06822c-a3e5-5c68-a4fa-8462c46de343', 'd9d25e13-71ac-51c4-93f7-ed042a996500', 'Riz local 25kg', 12500, 1);

  -- ------------------------------------------------------------------------
  -- 7. reviews (2)
  -- ------------------------------------------------------------------------
  insert into public.reviews (id, order_id, supplier_group_id, client_id, supplier_id, stars, comment, created_at) values
    ('c3d4d48f-f9a9-59b5-8798-4a9964995afa', '1e31c8a6-d12e-59e4-ad3b-5af974e9dd19', '821d2218-ee1c-50fa-b2b4-9d10895d950d', '3355adef-385d-5eee-a565-815c8cf8e4d3', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3',
     5, 'Très beau tissu, livraison rapide.', now() - interval '10 days'),
    ('b3a7f841-f4c5-5b1c-aabe-9e76b100b796', 'ca6f1cdc-ffd4-5bc6-97c3-f33cd52465ee', '4f06822c-a3e5-5c68-a4fa-8462c46de343', '04060d99-e34d-520e-8b75-631ff4d3c10c', '2c66294c-e1d7-59f1-925c-5ab6703827f3',
     5, 'Riz de très bonne qualité, je recommande.', now() - interval '20 days');

  -- ------------------------------------------------------------------------
  -- 8. supplier_kyc / supplier_documents (3 dossiers, 5 documents)
  -- ------------------------------------------------------------------------
  insert into public.supplier_kyc (
    id, supplier_id, legal_type, status, created_at, submitted_at, reviewed_at, reviewed_by_staff_id,
    rejection_reason, rccm_number, tax_id, legal_representative_name, registered_address
  ) values
    ('8b080e37-5cd8-54e0-83b2-44ec937749a1', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'company', 'approved',
     now() - interval '61 days', now() - interval '60 days', now() - interval '58 days',
     '2358888a-b13d-56f8-858b-a0c63831b512', null,
     'MA.BKO.2022.B.0456', 'NIF-004521', 'Ibrahima Coulibaly', 'Zone Industrielle, Bamako'),
    ('0c884147-9c42-5893-b253-ab069e5dc9e4', 'b6b1daf0-1c8e-583f-939f-687991d429ca', 'company', 'submitted',
     now() - interval '3 days', now() - interval '2 days', null, null, null,
     'MA.SIK.2026.B.0789', 'NIF-009873', 'Fatoumata Keita', 'Marché Central, Sikasso'),
    ('f3824a79-b8d2-5445-bd5e-53308bc806cd', 'deb94bf5-bddb-5399-8010-3b0264c98f1a', 'company', 'rejected',
     now() - interval '6 days', now() - interval '5 days', now() - interval '4 days',
     '0354c601-5e09-57b6-a23c-affaa5acf0d0',
     'Le numéro RCCM fourni ne correspond à aucun enregistrement valide. Merci de soumettre un extrait RCCM lisible et à jour.',
     null, 'NIF-002211', 'Seydou Traoré', 'Marché de Niono');

  insert into public.supplier_documents (id, kyc_id, type, file_path, uploaded_at) values
    ('171dcb37-678b-550d-920e-f580ed382da5', '8b080e37-5cd8-54e0-83b2-44ec937749a1', 'rccm_certificate', 'seed://rccm-bogolan.jpg', now() - interval '60 days'),
    ('d698ca07-015a-58d4-9c2b-5a016de69a0a', '8b080e37-5cd8-54e0-83b2-44ec937749a1', 'manager_id_card', 'seed://id-bogolan.jpg', now() - interval '60 days'),
    ('19b1dcea-7432-5054-b2bc-c5bedf8d7f8a', '0c884147-9c42-5893-b253-ab069e5dc9e4', 'rccm_certificate', 'seed://rccm-sikasso.jpg', now() - interval '2 days'),
    ('ca15084c-3e4d-5582-bcbc-c85dd01fc593', '0c884147-9c42-5893-b253-ab069e5dc9e4', 'manager_id_card', 'seed://id-sikasso.jpg', now() - interval '2 days'),
    ('e7eff388-5320-5ab2-966b-a9530b738b8b', 'f3824a79-b8d2-5445-bd5e-53308bc806cd', 'manager_id_card', 'seed://id-niono.jpg', now() - interval '5 days');

  -- ------------------------------------------------------------------------
  -- 9. payout_requests (1)
  -- ------------------------------------------------------------------------
  insert into public.payout_requests (id, supplier_id, amount_fcfa, status, requested_at, method, payout_destination, processed_at) values
    ('d83fac03-2549-57d2-8725-c122da499036', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 10000, 'paid',
     now() - interval '4 days', 'orange_money', '+22370000010', now() - interval '3 days');

  -- ------------------------------------------------------------------------
  -- 10. chat (2 conversations, 3 messages)
  -- ------------------------------------------------------------------------
  insert into public.chat_conversations (
    id, client_id, client_display_name_snapshot, supplier_id, supplier_name,
    last_message_preview, last_message_at, unread_count_client, unread_count_supplier
  ) values
    ('41889195-7cbf-5b45-8d95-de49a8b47cd0', '04060d99-e34d-520e-8b75-631ff4d3c10c', 'Awa Traoré', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'Bogolan Bamako',
     'Oui, disponible en plusieurs coloris !', now() - interval '2 hours', 1, 0),
    ('2fbdae8c-afc9-5053-b47a-6e46ab1a9361', '3355adef-385d-5eee-a565-815c8cf8e4d3', 'Moussa Diarra', '3331cbb4-0a65-5f94-9812-fe4270e50fe2', 'MTC Officiel',
     'Bienvenue sur Mali Trade Connect !', now() - interval '1 day', 0, 0);

  insert into public.chat_messages (id, conversation_id, sender_id, text, sent_at, is_read) values
    ('60c32d08-af5f-51e0-b744-2340fb894aab', '41889195-7cbf-5b45-8d95-de49a8b47cd0', '04060d99-e34d-520e-8b75-631ff4d3c10c',
     'Bonjour, le tissu bogolan est-il disponible en plusieurs couleurs ?', now() - interval '3 hours', true),
    ('6f8c35d7-095a-5944-b617-4bb7d495ed48', '41889195-7cbf-5b45-8d95-de49a8b47cd0', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3',
     'Oui, disponible en plusieurs coloris !', now() - interval '2 hours', false),
    ('805a78e4-82cb-5369-85e0-f78eade39cc1', '2fbdae8c-afc9-5053-b47a-6e46ab1a9361', '3331cbb4-0a65-5f94-9812-fe4270e50fe2',
     'Bienvenue sur Mali Trade Connect ! Nous sommes là pour vous aider.', now() - interval '1 day', true);

  -- ------------------------------------------------------------------------
  -- 11. product_comments (3) + comment_likes (1)
  -- ------------------------------------------------------------------------
  insert into public.product_comments (id, product_id, supplier_id, author_id, author_name, created_at, text, is_supplier, parent_id) values
    ('3d2df89f-c408-5ed7-8d7b-d0b90aeea554', 'b0fe527e-1f73-55e6-b24e-4d985576d473', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', '3355adef-385d-5eee-a565-815c8cf8e4d3', 'Moussa Diarra',
     now() - interval '2 days',
     'Le tissu est-il aussi solide qu''il en a l''air ? Je cherche quelque chose de durable pour un boubou de tous les jours.',
     false, null),
    ('b6059714-4354-5cb3-bbbd-da0b7cc32620', 'b0fe527e-1f73-55e6-b24e-4d985576d473', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'Bogolan Bamako',
     now() - interval '1 day 20 hours',
     'Oui, c''est un coton épais tissé main, teint deux fois pour bien fixer les motifs. Très résistant à l''usage quotidien.',
     true, '3d2df89f-c408-5ed7-8d7b-d0b90aeea554'),
    ('0ba923ec-60a9-59c4-8661-d6f950755c37', 'b0fe527e-1f73-55e6-b24e-4d985576d473', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', '04060d99-e34d-520e-8b75-631ff4d3c10c', 'Awa Traoré',
     now() - interval '5 hours',
     'Magnifiques couleurs, exactement comme sur les photos !',
     false, null);

  insert into public.comment_likes (comment_id, user_id) values
    ('0ba923ec-60a9-59c4-8661-d6f950755c37', '3355adef-385d-5eee-a565-815c8cf8e4d3');

  -- ------------------------------------------------------------------------
  -- 12. product_characteristic_types — les 4 types pré-approuvés, vidés par
  -- le TRUNCATE CASCADE ci-dessus (voir commentaire en tête de migration).
  -- ------------------------------------------------------------------------
  insert into public.product_characteristic_types (id, label, status) values
    ('couleur', 'Couleur', 'approved'),
    ('stockage', 'Stockage', 'approved'),
    ('taille', 'Taille', 'approved'),
    ('poids', 'Poids', 'approved')
  on conflict (id) do nothing;

  -- ------------------------------------------------------------------------
  -- 13. Every seeded product gets a single "Taille: Standard" characteristic
  -- + option + default variant carrying over its own price/stock/photos —
  -- `products_active_requires_variants` (0021) requires it to be `active`,
  -- and the `product_variants_aggregate_products` trigger (0018) then
  -- recomputes price_fcfa/stock_quantity/has_variants from that one variant
  -- right back to what section 3 just inserted. Must run after §12: `taille`
  -- doesn't exist until then (this reset wipes `product_characteristic_types`
  -- entirely, see the comment at the top of this migration).
  -- ------------------------------------------------------------------------
  declare
    v_product record;
    v_characteristic_id text;
    v_option_id text;
    v_variant_id text;
  begin
    for v_product in select * from public.products where has_variants = false loop
      v_characteristic_id := gen_random_uuid()::text;
      v_option_id := gen_random_uuid()::text;
      v_variant_id := gen_random_uuid()::text;

      insert into public.product_characteristics (id, product_id, type_id, display_order)
      values (v_characteristic_id, v_product.id, 'taille', 0);

      insert into public.product_characteristic_options
        (id, characteristic_id, value, price_delta_fcfa, display_order)
      values (v_option_id, v_characteristic_id, 'Standard', 0, 0);

      insert into public.product_variants
        (id, product_id, name, price_fcfa, stock_quantity, image_urls, is_default, display_order)
      values (
        v_variant_id, v_product.id, 'Standard',
        v_product.price_fcfa, v_product.stock_quantity, v_product.image_urls,
        true, 0
      );

      insert into public.product_variant_options (variant_id, characteristic_id, option_id)
      values (v_variant_id, v_characteristic_id, v_option_id);
    end loop;
  end;
end;
$function$;

-- ---- qui voit quoi --------------------------------------------------------

-- Ce que l'appelant peut voir des coordonnées de la commande `p_order_id` :
-- le numéro, l'adresse, les deux ou rien. Tout se relit en base à partir du
-- seul identifiant.
create or replace function public.order_contact_access(p_order_id text)
returns table (phone boolean, address boolean)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_client uuid;
  v_shop uuid;
  v_groupes_ouverts integer;
  v_livre_lui_meme boolean;
begin
  phone := false;
  address := false;
  if v_uid is null or p_order_id is null then
    return next;
    return;
  end if;

  select o.client_id into v_client from public.orders o where o.id = p_order_id;
  if v_client is null then
    return next;
    return;
  end if;

  -- Le client : tout, toujours.
  if v_client = v_uid then
    phone := true;
    address := true;
    return next;
    return;
  end if;

  -- La boutique : l'adresse tant que sa part n'est ni livrée ni annulée ; le
  -- numéro en plus quand c'est elle qui livre. Un collaborateur sans la
  -- permission `orders` n'a rien à en voir.
  v_shop := public.operating_supplier_id();
  if v_shop is not null and public.supplier_can('orders') then
    select count(*), coalesce(bool_or(g.delivery_mode = 'self_delivery'), false)
      into v_groupes_ouverts, v_livre_lui_meme
      from public.order_supplier_groups g
     where g.order_id = p_order_id
       and g.supplier_id = v_shop
       and g.status not in ('delivered', 'cancelled');
    if v_groupes_ouverts > 0 then
      address := true;
      phone := v_livre_lui_meme;
    end if;
  end if;

  -- Le livreur : numéro et adresse une fois la course acceptée, jusqu'à la
  -- remise ; l'adresse seule pendant qu'on la lui propose, pour qu'il juge
  -- le trajet. Le numéro attend qu'il ait dit oui.
  if exists (
    select 1 from public.deliveries d
     where d.order_id = p_order_id
       and d.courier_id = v_uid
       and d.status in ('accepted', 'picked_up')
  ) then
    phone := true;
    address := true;
  elsif exists (
    select 1 from public.deliveries d
     where d.order_id = p_order_id
       and d.offered_to_courier_id = v_uid
       and d.status = 'offered'
  ) then
    address := true;
  end if;

  return next;
end;
$$;

-- Appelée par `client_contact`, qui tourne en propriétaire : personne d'autre
-- n'a à l'appeler.
revoke all on function public.order_contact_access(text) from public, anon, authenticated;

-- La colonne calculée que PostgREST sert à côté de la commande. `null` quand
-- l'appelant n'a droit à rien ; sinon un objet qui ne porte que les clés
-- permises :
--
--   phone            le numéro à appeler pour la livraison (celui donné au
--                    paiement, sinon celui du compte)
--   alternate_phone  le second numéro, s'il y en a un
--   address_label, address_details, latitude, longitude
--
-- Seul l'identifiant de la ligne reçue est lu. Une fonction qui prend une
-- ligne en paramètre peut aussi être appelée en RPC avec une ligne fabriquée
-- (« client_id = moi ») : rien de ce qu'elle contient d'autre n'est cru.
create or replace function public.client_contact(o public.orders)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_phone boolean;
  v_address boolean;
  c public.order_contacts;
begin
  select a.phone, a.address into v_phone, v_address
    from public.order_contact_access(o.id) a;
  if not (coalesce(v_phone, false) or coalesce(v_address, false)) then
    return null;
  end if;

  select * into c from public.order_contacts where order_id = o.id;
  if not found then
    return null;
  end if;

  return jsonb_strip_nulls(jsonb_build_object(
    'phone', case when v_phone
      then coalesce(nullif(btrim(c.courier_phone), ''), c.client_phone) end,
    'alternate_phone', case when v_phone
      then nullif(btrim(c.alternate_phone), '') end,
    'address_label', case when v_address then c.address_label end,
    'address_details', case when v_address then c.address_details end,
    'latitude', case when v_address then c.latitude end,
    'longitude', case when v_address then c.longitude end
  ));
end;
$$;

revoke all on function public.client_contact(public.orders) from public, anon;
grant execute on function public.client_contact(public.orders) to authenticated;

notify pgrst, 'reload schema';
