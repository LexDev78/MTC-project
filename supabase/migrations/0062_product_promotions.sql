-- Promotions sur les produits, décidées par le fournisseur.
--
-- Jusqu'ici il n'y avait que `products.compare_at_price_fcfa` : un prix barré
-- écrit à la main, sans date ni condition. Il fallait donc baisser le prix
-- réel, se souvenir de le remonter, et rien ne permettait un « à partir de
-- 10 pièces ». Cette migration remplace le prix barré décoratif par une
-- règle que la base applique elle-même.
--
-- Deux formes, qui se combinent librement :
--
--  * une remise en pourcentage ou en francs ;
--  * une condition de quantité (`min_quantity`) et/ou une fenêtre de dates
--    (`starts_at`, `ends_at`).
--
-- Un « -15% du 1er au 15 » et un « -20% à partir de 10 pièces » sont donc
-- deux lignes, et c'est voulu : le fournisseur les gère séparément, les
-- active ou les arrête séparément.
--
-- Elles ne se **cumulent** pas. Le prix retenu est le plus avantageux pour
-- le client parmi celles qui s'appliquent. Cumuler aurait deux défauts :
-- l'empilement produit des prix que personne n'a voulus (deux fois -50% ne
-- fait pas 0 par accident), et l'ordre d'application changerait le résultat
-- sans qu'aucun ordre soit plus légitime qu'un autre.
--
-- Le prix facturé reste calculé par le serveur, comme avant (`0029`,
-- `0030`) : `place_order` ne lit aucun prix venu de l'app, et applique donc
-- ces règles lui-même. Une promotion affichée mais expirée ne donne rien ;
-- une promotion inventée côté client ne donne rien non plus.

create type public.promotion_kind as enum ('percentage', 'fixed_amount');

create table public.product_promotions (
  id text primary key default gen_random_uuid()::text,
  product_id text not null references public.products(id) on delete cascade,

  -- Dénormalisé depuis le produit, et **posé par le trigger** ci-dessous :
  -- la policy n'a ainsi pas à joindre `products` pour savoir qui a le droit
  -- d'écrire, et la colonne ne peut pas mentir.
  supplier_id uuid not null references public.suppliers(id) on delete cascade,

  kind public.promotion_kind not null,
  value integer not null check (value > 0),

  -- Remise sur quantité : s'applique à partir de ce nombre d'unités.
  min_quantity integer not null default 1 check (min_quantity between 1 and 10000),

  -- Fenêtre ouverte des deux côtés : `null` = déjà commencée / sans fin.
  starts_at timestamptz,
  ends_at timestamptz,

  -- Arrêter une promotion sans la supprimer : son historique reste lisible,
  -- et la reprendre ne demande pas de la ressaisir.
  is_active boolean not null default true,

  -- Ce que le client lit sur la vignette (« Rentrée scolaire »). Facultatif.
  label text,
  created_at timestamptz not null default now(),

  -- 90% au plus : une remise de 100% est un cadeau, et presque toujours une
  -- faute de saisie. Ce plafond garantit aussi qu'un prix reste strictement
  -- positif sans qu'on ait à rattraper le cas.
  constraint promotion_percentage_range
    check (kind <> 'percentage' or value between 1 and 90),
  constraint promotion_window_ordered
    check (ends_at is null or starts_at is null or ends_at > starts_at)
);

create index product_promotions_product_idx
  on public.product_promotions (product_id) where is_active;

create or replace function public.stamp_promotion_supplier()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
begin
  select supplier_id into v_owner
    from public.products where id = new.product_id;
  if v_owner is null then
    raise exception 'Produit introuvable : %', new.product_id;
  end if;
  -- Vérifié ici **en plus** de la policy : c'est cette fonction qui décide
  -- de la valeur, donc c'est ici qu'un produit qui n'est pas le sien doit
  -- être refusé, et non après coup.
  if v_owner is distinct from public.operating_supplier_id() then
    raise exception 'Vous ne pouvez pas promouvoir un produit qui n''est pas le vôtre.';
  end if;
  new.supplier_id := v_owner;
  return new;
end;
$$;

create trigger product_promotions_stamp_supplier
  before insert or update on public.product_promotions
  for each row execute function public.stamp_promotion_supplier();

alter table public.product_promotions enable row level security;

-- Lecture publique : une promotion est une information commerciale, et le
-- visiteur doit voir le prix remisé avant de créer un compte.
create policy "product_promotions_select_public" on public.product_promotions
  for select using (true);

create policy "product_promotions_write_own" on public.product_promotions
  for all using (supplier_id = public.operating_supplier_id())
  with check (supplier_id = public.operating_supplier_id());

grant select on public.product_promotions to anon, authenticated;
grant insert, update, delete on public.product_promotions to authenticated;

-- Le prix unitaire réellement dû, remises comprises.
--
-- Une seule définition du calcul côté serveur, appelée par `place_order` :
-- l'app a la sienne pour l'affichage (`promotion_pricing.dart`), et un test
-- vérifie que les deux donnent le même résultat. Sans ce test, deux règles
-- finiraient par diverger et le panier annoncerait un prix que la commande
-- ne respecterait pas.
create or replace function public.effective_unit_price_fcfa(
  p_product_id text,
  p_variant_id text,
  p_quantity integer
) returns integer
language plpgsql
stable
set search_path = public
as $$
declare
  v_base integer;
  v_best integer;
begin
  if p_variant_id is null then
    select price_fcfa into v_base
      from public.products where id = p_product_id;
  else
    select price_fcfa into v_base
      from public.product_variants
      where id = p_variant_id and product_id = p_product_id;
  end if;
  if v_base is null then return null; end if;

  -- Le meilleur prix parmi les promotions applicables, jamais leur somme.
  -- `greatest(..., 1)` : un prix nul passerait les contrôles de stock et de
  -- paiement sans que personne ne l'ait voulu.
  select min(
           greatest(
             case p.kind
               when 'percentage' then v_base - (v_base * p.value) / 100
               else v_base - p.value
             end,
             1
           )
         )
    into v_best
    from public.product_promotions p
   where p.product_id = p_product_id
     and p.is_active
     and coalesce(p_quantity, 1) >= p.min_quantity
     and (p.starts_at is null or p.starts_at <= now())
     and (p.ends_at is null or p.ends_at > now());

  return least(coalesce(v_best, v_base), v_base);
end;
$$;

grant execute on function public.effective_unit_price_fcfa(text, text, integer)
  to anon, authenticated;

-- `place_order` applique les promotions.
--
-- Reprise de sa définition en vigueur, à un seul endroit près : la lecture
-- du prix. C'est le point qui compte — le prix facturé n'a jamais été celui
-- envoyé par l'app (`0029`, `0030`), et il ne le devient pas davantage
-- maintenant qu'il y a des remises. Une promotion expirée, désactivée ou
-- inventée côté client ne change donc rien au montant.
CREATE OR REPLACE FUNCTION public.place_order(p_client_display_name_snapshot text, p_client_phone_snapshot text, p_groups jsonb, p_delivery_address_label text, p_delivery_city text, p_delivery_details text, p_delivery_latitude double precision, p_delivery_longitude double precision, p_fulfillment_method text DEFAULT 'home_delivery'::text, p_courier_phone text DEFAULT NULL::text, p_alternate_phone text DEFAULT NULL::text, p_delivery_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_delivery_time_slot_label text DEFAULT NULL::text, p_is_priority boolean DEFAULT false, p_priority_fee_fcfa integer DEFAULT 0, p_supplier_message_type text DEFAULT 'none'::text, p_supplier_message_text text DEFAULT NULL::text, p_supplier_message_voice_path text DEFAULT NULL::text, p_supplier_message_voice_duration_seconds integer DEFAULT NULL::integer, p_payment_method text DEFAULT 'on_delivery'::text, p_payment_status text DEFAULT 'pending_on_delivery'::text, p_mobile_money_provider text DEFAULT NULL::text)
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
$function$
