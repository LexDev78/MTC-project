-- 0153 — Ce qu'un client retient sans payer, et à quel rythme il écrit
-- (rapport du 06/11/2026).
--
-- 1. Le stock bloqué par une commande en attente (moyenne). Une commande à
--    la livraison ne coûte rien et retire le stock dès qu'elle est passée :
--    client1 a commandé les 100 unités d'un produit de fournisseur8
--    (800 000 FCFA), le produit est devenu épuisé pour tous les autres, et
--    seule la boutique pouvait l'annuler — un script recommençait aussitôt.
--    « Payer maintenant » n'y échappait pas : aucune passerelle derrière
--    (`mobile_money_payment_sheet.dart`), toute commande naît
--    `pending_on_delivery`, et seul MTC la dit payée (`mark_order_paid`).
--    Tant qu'une commande n'est pas payée, désormais :
--      * un client a au plus 10 exemplaires d'un même article en cours ;
--      * au plus 3 commandes en cours chez une même boutique ;
--      * au plus 200 000 FCFA d'articles en cours en tout — un article seul
--        passe toujours, quel que soit son prix, pour qu'un réfrigérateur
--        reste achetable à la livraison ;
--    et, payée ou non :
--      * au plus 10 commandes par heure, annulées comprises : commander puis
--        annuler en boucle poussait autant de « Nouvelle commande » à la
--        boutique ;
--      * une commande que la boutique n'a pas confirmée sous 24 h s'annule
--        d'elle-même (`pg_cron`, tous les quarts d'heure) : le stock revient
--        (`0152`), le client et la boutique sont prévenus. Une commande déjà
--        payée, elle, attend MTC — l'annuler d'office laisserait l'argent
--        reçu sans commande.
--    « En cours » : un groupe ni livré ni annulé.
--
-- 2. Aucune limite de débit sur les messages et les commentaires (faible).
--    En une requête, client1 a envoyé 200 messages et posté 200
--    commentaires : fournisseur8 a reçu 400 notifications, donc 400 push.
--    Désormais 20 messages par minute et 300 par heure par expéditeur ;
--    10 commentaires par minute et 60 par heure par auteur, sous un produit
--    comme sous un avis — comptés à part (`post_rate_events`), pour qu'effacer
--    ce qu'on vient d'écrire ne remette pas le compteur à zéro. Et un fil —
--    une conversation, les commentaires d'un produit — ne fait qu'une
--    notification non lue à la fois : les messages qui suivent la mettent à
--    jour au lieu d'en créer une chacun, soit une notification push au plus
--    toutes les 10 minutes par fil.
--
-- 3. En passant :
--    * `update_order_group_status` lisait le statut sans verrou : une
--      boutique qui confirmait au moment où l'annulation (automatique, ou du
--      client) passait voyait sa confirmation appliquée sur la commande
--      annulée — « confirmée », stock déjà rendu (`0152`), article vendu
--      deux fois (constaté sur la pile de vérification). Elle verrouille
--      désormais la commande avant de juger la transition ;
--    * une commande annulée gardait son code promo comme utilisé : un code
--      « une fois par client » était brûlé par un refus de la boutique, et
--      le serait par l'annulation automatique. Il revient avec l'annulation ;
--    * `review_comments` gardait à l'insertion la date envoyée par la
--      requête — un commentaire se datait d'hier ou de l'an prochain et se
--      rangeait où il voulait dans le fil ;
--    * la purge à 90 jours des traces d'activité (`0081`), écrite pour une
--      tâche planifiée, n'était planifiée nulle part.
--
-- Les seuils se règlent sans migration, dans `app_settings` (`0135`) :
--
--   insert into public.app_settings (key, value)
--   values ('unpaid_units_per_item_max', '20')
--   on conflict (key) do update set value = excluded.value, updated_at = now();
--
-- Clés, et leur valeur sans ligne : unpaid_units_per_item_max 10,
-- unpaid_orders_per_shop_max 3, unpaid_value_fcfa_max 200000,
-- orders_per_hour_max 10, unconfirmed_order_expiry_hours 24,
-- messages_per_minute_max 20, messages_per_hour_max 300,
-- comments_per_minute_max 10, comments_per_hour_max 60.
--
-- `place_order` et `update_order_group_status` sont reprises de `0147`,
-- `stamp_review_comment_author` de `0143`, `notify_new_message` et
-- `notify_new_comment` de leur définition en vigueur (`0066`) : ces passages
-- seuls changés.

-- ------------------------------------------------------------- 0. réglages
-- Un entier lu dans `app_settings`, ou le défaut : une valeur absente,
-- illisible ou inférieure à 1 ne doit ni faire échouer une commande, ni
-- lever un plafond par accident.
create or replace function public.app_setting_int(p_key text, p_default integer)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select case when jsonb_typeof(s.value) = 'number' then
              case when (s.value #>> '{}')::numeric between 1 and 2147483647
                   then floor((s.value #>> '{}')::numeric)::integer
              end
            end
       from public.app_settings s
      where s.key = p_key),
    p_default
  );
$$;

revoke all on function public.app_setting_int(text, integer) from public, anon, authenticated;

-- « 200 000 FCFA » plutôt que « 200000 » dans les messages.
create or replace function public.fcfa_text(p_amount bigint)
returns text
language sql
immutable
set search_path = public
as $$
  select regexp_replace(p_amount::text, '(\d)(?=(\d{3})+$)', '\1 ', 'g') || ' FCFA';
$$;

revoke all on function public.fcfa_text(bigint) from public, anon, authenticated;

-- ------------------------------------- 1. ce qu'un client retient sans payer
-- Appelée par `place_order` une fois les groupes chiffrés, avant la
-- première écriture, sous le verrou du client (voir `place_order`) : ce
-- qu'il a déjà en cours ne peut pas changer pendant qu'on le compte.
create or replace function public.check_unpaid_holdings(p_client_id uuid, p_groups jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_units_max integer := public.app_setting_int('unpaid_units_per_item_max', 10);
  v_open_max integer := public.app_setting_int('unpaid_orders_per_shop_max', 3);
  v_value_max integer := public.app_setting_int('unpaid_value_fcfa_max', 200000);
  v_line record;
  v_shop record;
  v_held bigint;
  v_open bigint;
  v_held_value bigint;
  v_new_value bigint;
  v_new_units bigint;
begin
  -- Un même article — le produit, et sa variante s'il en a —, toutes
  -- commandes en cours confondues : c'est son stock qu'elles retiennent.
  for v_line in
    select i ->> 'product_id' as product_id,
           i ->> 'variant_id' as variant_id,
           min(i ->> 'product_name_snapshot') as product_name,
           min(i ->> 'variant_name_snapshot') as variant_name,
           sum((i ->> 'quantity')::bigint) as quantity
      from jsonb_array_elements(p_groups) g,
           jsonb_array_elements(g -> 'items') i
     group by 1, 2
  loop
    select coalesce(sum(oi.quantity), 0) into v_held
      from public.orders o
      join public.order_supplier_groups g on g.order_id = o.id
      join public.order_items oi on oi.group_id = g.id
     where o.client_id = p_client_id
       and o.payment_status <> 'paid'
       and g.status in ('pending', 'confirmed', 'preparing', 'in_transit')
       and oi.product_id = v_line.product_id
       and oi.variant_id is not distinct from v_line.variant_id;

    if v_held + v_line.quantity > v_units_max then
      raise exception '%', format(
        '« %s » : %s exemplaire%s au plus par client tant que la commande n''est pas payée%s.',
        -- La variante n'est nommée que s'il y a à choisir : « — Standard »
        -- sous un produit qui n'en a qu'une ne dit rien.
        v_line.product_name
          || case when v_line.variant_name is not null
                   and (select count(*) from public.product_variants pv
                         where pv.product_id = v_line.product_id) > 1
                  then ' — ' || v_line.variant_name
                  else ''
             end,
        v_units_max,
        case when v_units_max > 1 then 's' else '' end,
        case when v_held > 0
             then format(' (vous en avez déjà %s en cours)', v_held)
             else ''
        end);
    end if;
  end loop;

  -- Une même boutique.
  for v_shop in
    select (g ->> 'supplier_id')::uuid as supplier_id,
           g ->> 'supplier_name' as supplier_name
      from jsonb_array_elements(p_groups) g
  loop
    select count(*) into v_open
      from public.orders o
      join public.order_supplier_groups g on g.order_id = o.id
     where o.client_id = p_client_id
       and o.payment_status <> 'paid'
       and g.supplier_id = v_shop.supplier_id
       and g.status in ('pending', 'confirmed', 'preparing', 'in_transit');

    if v_open >= v_open_max then
      raise exception '%', format(
        'Vous avez déjà %s commande%s en cours chez %s : attendez qu''une soit livrée, ou annulez-en une, avant d''en passer une autre.',
        v_open, case when v_open > 1 then 's' else '' end, v_shop.supplier_name);
    end if;
  end loop;

  -- En tout, en valeur d'articles : les frais de livraison ne retiennent
  -- aucun stock. Un article seul passe toujours tant que le reste tient
  -- sous le plafond — sans quoi un réfrigérateur ne s'achèterait plus à la
  -- livraison, et le client n'a aucun moyen de payer d'avance. Qui s'en
  -- sert retient au plus le plafond et un article, puis plus rien.
  select coalesce(sum(g.subtotal_fcfa), 0) into v_held_value
    from public.orders o
    join public.order_supplier_groups g on g.order_id = o.id
   where o.client_id = p_client_id
     and o.payment_status <> 'paid'
     and g.status in ('pending', 'confirmed', 'preparing', 'in_transit');

  select coalesce(sum((g ->> 'subtotal_fcfa')::bigint), 0) into v_new_value
    from jsonb_array_elements(p_groups) g;
  select coalesce(sum((i ->> 'quantity')::bigint), 0) into v_new_units
    from jsonb_array_elements(p_groups) g,
         jsonb_array_elements(g -> 'items') i;

  if v_held_value + v_new_value > v_value_max
     and not (v_new_units = 1 and v_held_value <= v_value_max) then
    raise exception '%', format(
      'Vos commandes non payées ne peuvent pas dépasser %s d''articles en tout : %s.',
      public.fcfa_text(v_value_max),
      case when v_held_value > 0
           then format('vous en avez déjà %s en cours, celle-ci en ajoute %s',
                       public.fcfa_text(v_held_value), public.fcfa_text(v_new_value))
           else format('celle-ci en compte %s — un article seul passe, quel que soit son prix',
                       public.fcfa_text(v_new_value))
      end);
  end if;
end;
$$;

revoke all on function public.check_unpaid_holdings(uuid, jsonb) from public, anon, authenticated;

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

  -- Un client, une commande à la fois (`0153`) : les plafonds plus bas
  -- comptent ce qu'il a déjà en cours, et sans ce verrou dix commandes
  -- simultanées comptaient chacune « rien en cours » et passaient toutes.
  -- La seconde attend que la première soit enregistrée, puis compte avec.
  perform pg_advisory_xact_lock(hashtextextended('place_order:' || v_client_id::text, 0));

  -- Commander puis annuler en boucle poussait autant de « Nouvelle
  -- commande » à la boutique (`0153`) : les commandes de la dernière heure
  -- comptent, annulées comprises.
  if (select count(*) from public.orders o
       where o.client_id = v_client_id
         and o.placed_at > now() - interval '1 hour')
     >= public.app_setting_int('orders_per_hour_max', 10) then
    raise exception 'Vous avez passé beaucoup de commandes en une heure : patientez avant d''en passer une autre.';
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

  -- Ce qu'un client retient sans avoir payé (`0153`), avant la première
  -- écriture : le stock baisse dès la commande.
  perform public.check_unpaid_holdings(v_client_id, v_priced_groups);

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
-- ------------------------------------- 1 quater. une transition à la fois
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
    where g.id = p_group_id and g.order_id = p_order_id
    -- Verrouillé avant de juger la transition (`0153`) : lu sans verrou, le
    -- statut pouvait changer entre la lecture et l'écriture. La boutique
    -- confirmait ainsi une commande que l'annulation automatique — ou le
    -- client — venait d'annuler : son écriture attendait la fin de
    -- l'annulation, puis s'appliquait sur la ligne annulée. Commande
    -- « confirmée », stock déjà rendu (`0152`), article vendu deux fois.
    -- Verrouillée, la seconde lit l'annulation et la transition est refusée.
    for update of g;

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

  -- Le refus que l'annulation automatique rend courant (`0153`) : la
  -- commande expirée au moment où la boutique la confirmait. Le début du
  -- message reste celui que l'app reconnaît (`supabase_order_repository`).
  if v_current_status = 'cancelled' then
    raise exception 'Transition invalide : cette commande a été annulée entre-temps.';
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
  where id = p_group_id
    and status = v_current_status;

  -- Le résumé de la commande (`orders.status`) suit : le déclencheur
  -- `order_supplier_groups_sync_order_status` le recalcule (`0112`).
end;
$function$;

-- ----------------------------------- 1 bis. la commande que personne ne confirme
create index if not exists order_supplier_groups_pending_idx
  on public.order_supplier_groups (order_id) where status = 'pending';

-- Appelée par `pg_cron` (plus bas), sous `postgres` : `auth.uid()` est nul,
-- les gardes propres aux requêtes de l'API laissent passer, et les
-- déclencheurs d'annulation font le reste — la course MTC fermée (`0146`),
-- le stock rendu (`0152`), le statut de la commande recalculé (`0112`).
-- `notify_order_status_change` se tait hors session : les deux
-- notifications sont écrites ici. Le motif se lit après « Annulée par
-- MTC : » dans l'app.
create or replace function public.cancel_unconfirmed_orders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  -- Un an au plus : au-delà, `now() - make_interval(…)` sort des dates que
  -- Postgres sait écrire, et la tâche échouerait à chaque passage.
  v_hours integer := least(public.app_setting_int('unconfirmed_order_expiry_hours', 24), 8760);
  v_group record;
  v_count integer := 0;
begin
  for v_group in
    select g.id, g.order_id, g.supplier_id, g.supplier_name,
           o.client_id, o.client_display_name_snapshot
      from public.order_supplier_groups g
      join public.orders o on o.id = g.order_id
     where g.status = 'pending'
       and o.payment_status <> 'paid'
       and o.placed_at < now() - make_interval(hours => v_hours)
     order by o.placed_at
     limit 500
     for update of g skip locked
  loop
    -- Une commande à la fois : si l'un des déclencheurs d'annulation refuse
    -- celle-ci, elle reste en attente et le dit dans le journal de la tâche,
    -- sans empêcher les autres de s'annuler — ni le passage suivant.
    begin
      update public.order_supplier_groups
         set status = 'cancelled',
             cancelled_by = 'mtc',
             cancellation_reason = format('la boutique ne l''a pas confirmée sous %s h', v_hours)
       where id = v_group.id
         and status = 'pending';
      if found then
        insert into public.notifications (id, user_id, type, title, body, reference_id)
        values
          (gen_random_uuid()::text, v_group.client_id, 'order_status_update',
           'Commande ' || v_group.supplier_name,
           format('Votre commande a été annulée : la boutique ne l''a pas confirmée sous %s h.', v_hours),
           v_group.order_id),
          (gen_random_uuid()::text, v_group.supplier_id, 'order_status_update',
           'Commande annulée',
           format('La commande de %s est annulée faute de confirmation sous %s h : ses articles sont revenus en stock.',
                  v_group.client_display_name_snapshot, v_hours),
           v_group.order_id);
        v_count := v_count + 1;
      end if;
    exception when others then
      raise warning 'Commande % non annulée : %', v_group.order_id, sqlerrm;
    end;
  end loop;
  return v_count;
end;
$$;

revoke all on function public.cancel_unconfirmed_orders() from public, anon, authenticated;

-- ------------------------------ 1 ter. une commande annulée rend son code promo
-- Une commande annulée n'a rien coûté : son code promo ne compte plus comme
-- utilisé. Sans quoi l'annulation automatique — que le client n'a pas
-- choisie — lui brûlait un code « une fois par client », comme un refus de
-- la boutique le faisait déjà ; et commander puis annuler épuisait le
-- nombre d'utilisations d'un code limité.
create or replace function public.release_promo_of_cancelled_group()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_confiance text := current_setting('app.trusted_stock_write', true);
begin
  -- Le garde des codes (`guard_supplier_permission('promotions')`) juge
  -- l'appelant : un collaborateur qui n'a que la case « commandes » annule,
  -- mais n'écrit pas les codes. La base le fait pour lui le temps de
  -- l'écriture, avec le réglage de la remise en stock (`0152`).
  perform set_config('app.trusted_stock_write', 'on', true);
  for v_code in
    delete from public.promo_code_redemptions
     where supplier_group_id = new.id
    returning promo_code_id
  loop
    update public.promo_codes
       set uses_count = greatest(uses_count - 1, 0)
     where id = v_code;
  end loop;
  perform set_config('app.trusted_stock_write', coalesce(v_confiance, ''), true);
  return null;
end;
$$;

revoke all on function public.release_promo_of_cancelled_group() from public, anon, authenticated;

drop trigger if exists order_supplier_groups_release_promo on public.order_supplier_groups;
create trigger order_supplier_groups_release_promo
  after update of status on public.order_supplier_groups
  for each row
  when (new.status = 'cancelled' and old.status is distinct from 'cancelled')
  execute function public.release_promo_of_cancelled_group();

-- -------------------------------------------------------- tâches planifiées
-- Les droits de `postgres` sur le schéma `cron` viennent du crochet de
-- Supabase qui suit la création de l'extension. Ce crochet rejoue ses
-- `revoke`/`grant` à chaque `create extension`, même « if not exists » qui
-- ne crée rien, et échoue (« dependent privileges exist ») sur une base où
-- `pg_cron` était déjà activée et ses droits redonnés à la main — ce que
-- conseille la documentation de Supabase. On ne crée donc l'extension que si
-- elle manque, et on ne redonne aucun droit.
do $$
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    create extension pg_cron with schema pg_catalog;
  end if;
end $$;

-- Rejouer la migration ne double pas les tâches.
select cron.unschedule(j.jobid)
  from cron.job j
 where j.jobname in ('mtc-commandes-non-confirmees', 'mtc-purge-activite');

select cron.schedule(
  'mtc-commandes-non-confirmees', '*/15 * * * *',
  'select public.cancel_unconfirmed_orders()'
);

-- La purge à 90 jours de `0081`, chaque nuit à 3 h 17 (UTC, l'heure de
-- Bamako), loin des heures où l'on commande.
select cron.schedule(
  'mtc-purge-activite', '17 3 * * *',
  'select public.prune_activity_events()'
);

-- --------------------------------------- 2. le rythme des messages et commentaires
-- Le compte des envois, à part : compter les lignes de la table elle-même
-- laissait l'auteur d'un commentaire d'avis — qui peut supprimer les siens —
-- remettre son compteur à zéro en effaçant ce qu'il venait d'écrire. Une
-- ligne par envoi accepté, effacée au bout d'une heure ; une requête refusée
-- n'en laisse aucune, elle part avec la transaction.
create table if not exists public.post_rate_events (
  author_id uuid not null,
  kind text not null,
  at timestamptz not null default now()
);

create index if not exists post_rate_events_author_idx
  on public.post_rate_events (author_id, kind, at desc);

alter table public.post_rate_events enable row level security;
revoke all on public.post_rate_events from public, anon, authenticated;

comment on table public.post_rate_events is
  'Un envoi accepté par auteur et par table, gardé une heure : le compte de '
  '`throttle_posts` (0153). Aucune politique : écrit et lu par la base seule.';

create or replace function public.throttle_posts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  -- Arguments du déclencheur : la colonne de l'auteur, le réglage et le
  -- défaut par minute, puis par heure, et le mot qui nomme ce qu'on envoie.
  v_author uuid := (to_jsonb(new) ->> tg_argv[0])::uuid;
  v_per_minute integer := public.app_setting_int(tg_argv[1], tg_argv[2]::integer);
  v_per_hour integer := public.app_setting_int(tg_argv[3], tg_argv[4]::integer);
  v_minute bigint;
  v_hour bigint;
begin
  -- Hors session (semis, clé de service) : personne à freiner.
  if auth.uid() is null or v_author is null then
    return new;
  end if;
  -- Un expéditeur qui n'est pas l'appelant sera refusé par la politique
  -- d'insertion, qui ne juge qu'après les déclencheurs `before` : ne pas le
  -- compter. Sans quoi on prenait le verrou d'un autre, et le message
  -- d'erreur disait combien il avait envoyé.
  if v_author is distinct from auth.uid()
     and v_author is distinct from public.operating_supplier_id() then
    return new;
  end if;

  -- Un auteur à la fois : sans ce verrou, cinquante requêtes simultanées
  -- comptaient chacune « rien cette minute » et passaient toutes. Les lignes
  -- d'une même requête, elles, se voient : chacune compte celles qui la
  -- précèdent, et la 21e fait échouer la requête entière.
  perform pg_advisory_xact_lock(
    hashtextextended('throttle_posts:' || tg_table_name || ':' || v_author::text, 0));

  delete from public.post_rate_events
   where author_id = v_author and kind = tg_table_name
     and at < now() - interval '1 hour';

  select count(*) filter (where at > now() - interval '1 minute'), count(*)
    into v_minute, v_hour
    from public.post_rate_events
   where author_id = v_author and kind = tg_table_name;

  if v_minute >= v_per_minute then
    raise exception 'Vous envoyez trop de % à la suite : patientez une minute.', tg_argv[5];
  end if;
  if v_hour >= v_per_hour then
    raise exception 'Vous avez envoyé % % en une heure : patientez avant d''en envoyer d''autres.',
      v_hour, case when v_hour > 1 then tg_argv[5] else rtrim(tg_argv[5], 's') end;
  end if;

  insert into public.post_rate_events (author_id, kind) values (v_author, tg_table_name);
  return new;
end;
$$;

revoke all on function public.throttle_posts() from public, anon, authenticated;

-- Ce qu'un auteur n'a pas rafraîchi en écrivant de nouveau, chaque heure.
select cron.unschedule(j.jobid) from cron.job j where j.jobname = 'mtc-purge-rythme';
select cron.schedule(
  'mtc-purge-rythme', '7 * * * *',
  'delete from public.post_rate_events where at < now() - interval ''1 hour'''
);

-- Les noms passent après ceux des déclencheurs qui posent l'auteur (les
-- `before` se suivent par ordre alphabétique) : `product_comments_stamp_author`,
-- `review_comments_stamp_author`. Pour les messages, l'expéditeur est celui
-- de la requête, que la politique d'insertion vérifie.
drop trigger if exists chat_messages_throttle on public.chat_messages;
create trigger chat_messages_throttle
  before insert on public.chat_messages
  for each row execute function public.throttle_posts(
    'sender_id', 'messages_per_minute_max', '20', 'messages_per_hour_max', '300', 'messages');

drop trigger if exists product_comments_throttle on public.product_comments;
create trigger product_comments_throttle
  before insert on public.product_comments
  for each row execute function public.throttle_posts(
    'author_id', 'comments_per_minute_max', '10', 'comments_per_hour_max', '60', 'commentaires');

drop trigger if exists review_comments_throttle on public.review_comments;
create trigger review_comments_throttle
  before insert on public.review_comments
  for each row execute function public.throttle_posts(
    'author_id', 'comments_per_minute_max', '10', 'comments_per_hour_max', '60', 'commentaires');

create or replace function public.stamp_review_comment_author()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_supplier_id uuid;
begin
  -- L'auteur est l'appelant, quoi qu'en dise la requête.
  new.author_id := auth.uid();
  if new.author_id is null then
    raise exception 'Vous devez être connecté pour commenter un avis.';
  end if;

  select p.display_name into new.author_display_name_snapshot
    from public.profiles p where p.id = new.author_id;

  select r.supplier_id into v_supplier_id
    from public.reviews r where r.id = new.review_id;
  if v_supplier_id is null then
    raise exception 'Avis introuvable : %', new.review_id;
  end if;
  -- La boutique notée répond avec son badge, si ce compte a la case
  -- « avis » ; un client (ou le staff) commente en son nom ; personne
  -- d'autre — un livreur ou une autre boutique n'a pas à parler sous cet
  -- avis (`is_client`, `0140`).
  if v_supplier_id is not distinct from public.operating_supplier_id() then
    if not public.supplier_can('reviews') then
      raise exception 'Votre compte n''a pas accès aux avis de cette boutique.';
    end if;
    new.author_is_supplier := true;
  elsif public.is_client() or public.is_staff() then
    new.author_is_supplier := false;
  else
    raise exception 'Seul un client, ou la boutique notée, commente un avis.';
  end if;

  perform public.validate_media_paths(new.image_paths, new.author_id, 4);
  if new.video_path is not null then
    perform public.validate_media_paths(
      array[new.video_path], new.author_id, 1
    );
  end if;

  if tg_op = 'UPDATE' then
    new.created_at := old.created_at;
    new.updated_at := now();
  else
    -- La date d'un commentaire est celle de la base (`0153`) : celle de la
    -- requête passait telle quelle, et un commentaire se datait d'hier ou de
    -- l'an prochain pour se ranger où il voulait dans le fil.
    new.created_at := now();
    new.updated_at := null;
  end if;
  return new;
end;
$function$;

-- ------------------------------------------- 2 bis. une notification par fil
CREATE OR REPLACE FUNCTION public.notify_new_message()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_recipient uuid;
  v_client uuid;
  v_supplier uuid;
  v_body text;
begin
  if auth.uid() is null then return new; end if;

  select c.client_id, c.supplier_id into v_client, v_supplier
    from public.chat_conversations c where c.id = new.conversation_id;
  if v_client is null then return new; end if;

  v_recipient := case when new.sender_id = v_client then v_supplier else v_client end;
  if v_recipient is null or v_recipient = new.sender_id then return new; end if;

  v_body := coalesce(
    nullif(btrim(coalesce(new.text, '')), ''),
    case
      when new.product_name_snapshot is not null
        then '📦 ' || new.product_name_snapshot
      when new.attachment_type = 'image' then '📷 Photo'
      when new.attachment_type = 'voice' then '🎤 Message vocal'
      else 'Nouveau message'
    end
  );

  -- Une conversation, une notification non lue à la fois (`0153`) : tant
  -- que la dernière n'est pas lue et a moins de 10 minutes, les messages qui
  -- suivent la mettent à jour — elle montre le dernier — au lieu d'en créer
  -- une chacun, avec sa notification push : 200 messages faisaient 200 push.
  update public.notifications n
     set title = 'Nouveaux messages', body = v_body
   where n.id = (
     select n2.id from public.notifications n2
      where n2.user_id = v_recipient
        and n2.type = 'new_message'
        and n2.reference_id = new.conversation_id
        and not n2.is_read
        and n2.created_at > now() - interval '10 minutes'
      order by n2.created_at desc
      limit 1
   );
  if found then
    return new;
  end if;

  insert into public.notifications (id, user_id, type, title, body, reference_id)
  values (
    gen_random_uuid()::text, v_recipient, 'new_message', 'Nouveau message',
    v_body, new.conversation_id
  );
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_new_comment()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_recipient uuid;
begin
  if auth.uid() is null then return new; end if;

  if new.parent_id is null then
    v_recipient := new.supplier_id;
  else
    select author_id into v_recipient
      from public.product_comments where id = new.parent_id;
  end if;

  if v_recipient is null or v_recipient = new.author_id then return new; end if;

  -- Les commentaires d'un même produit, une notification non lue à la fois
  -- (`0153`), comme les messages d'une conversation.
  update public.notifications n
     set title = 'Nouveaux commentaires',
         body = coalesce(nullif(btrim(coalesce(new.text, '')), ''), 'Nouveau commentaire')
   where n.id = (
     select n2.id from public.notifications n2
      where n2.user_id = v_recipient
        and n2.type = 'new_comment'
        and n2.reference_id = new.product_id
        and not n2.is_read
        and n2.created_at > now() - interval '10 minutes'
      order by n2.created_at desc
      limit 1
   );
  if found then
    return new;
  end if;

  insert into public.notifications (id, user_id, type, title, body, reference_id)
  values (
    gen_random_uuid()::text, v_recipient, 'new_comment', 'Nouveau commentaire',
    coalesce(nullif(btrim(coalesce(new.text, '')), ''), 'Nouveau commentaire'),
    new.product_id
  );
  return new;
end;
$function$;
