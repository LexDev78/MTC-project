-- Corrige deux failles trouvées en audit :
--
-- 1) `place_order` calculait `total_fcfa`/`subtotal_fcfa` en sommant
--    `unit_price_fcfa_snapshot` tel qu'envoyé par le CLIENT, sans jamais le
--    comparer à `products.price_fcfa`/`product_variants.price_fcfa`. N'importe
--    quel compte `authenticated` pouvait appeler cette RPC directement (hors
--    de l'app) avec un prix arbitraire : le stock était bien vérifié et
--    décrémenté correctement, mais le montant facturé ne l'était pas.
--    Remède : un premier passage lit le prix côté serveur pour chaque ligne
--    (produit ou variante) et construit une version « re-pricée » des
--    groupes/items ; le reste de la fonction (vérif de stock, écritures)
--    est inchangé mais opère sur cette version fiable, jamais sur `p_groups`
--    directement pour tout ce qui touche à l'argent.
--
-- 2) `suppliers_update_own` (0001_initial_schema.sql) autorise l'UPDATE de
--    toute la ligne dès que `id = operating_supplier_id()` (le fournisseur
--    lui-même) OU `is_staff()` OU `has_reviewed_supplier(id)` — Postgres RLS
--    ne restreint pas par colonne, donc un fournisseur pouvait s'auto-valider
--    (`update suppliers set verification_status = 'verified' where id =
--    <son propre id>`), et un client ayant simplement laissé un avis
--    héritait du même accès en écriture sur toute la ligne du fournisseur
--    concerné. Même classe de faille que celle fermée au Lot 11 côté
--    `products` (`0009_lot11_supplier_verification_rpc.sql`), mais fermée
--    ici via un trigger plutôt qu'une RPC dédiée : `suppliers_update_own`
--    doit rester ouverte aux trois acteurs pour les autres colonnes de la
--    ligne (nom, description, notes...), seule `verification_status` doit
--    rester staff-only quel que soit le chemin d'écriture emprunté.

create or replace function public.place_order(
  p_client_display_name_snapshot text,
  p_client_phone_snapshot text,
  -- [{supplier_id, supplier_name, delivery_mode, delivery_fee_fcfa,
  --   items: [{product_id, variant_id, product_name_snapshot,
  --            variant_name_snapshot, unit_price_fcfa_snapshot, quantity}]}]
  -- `unit_price_fcfa_snapshot` en entrée n'est jamais utilisé pour l'argent —
  -- voir la boucle de re-pricing ci-dessous.
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
begin
  if v_client_id is null then
    raise exception 'Vous devez être connecté pour passer commande.';
  end if;

  -- Re-pricing : le prix facturé vient toujours de `products`/`product_variants`,
  -- jamais du JSON envoyé par le client. Construit `v_priced_groups`, une
  -- copie de `p_groups` où `unit_price_fcfa_snapshot` a été remplacé par le
  -- prix serveur — tout le reste de la fonction opère ensuite sur cette
  -- copie fiable plutôt que sur `p_groups`.
  for v_group in select * from jsonb_array_elements(p_groups)
  loop
    v_priced_items := '[]'::jsonb;
    v_group_subtotal := 0;
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

    v_total := v_total + v_group_subtotal + coalesce((v_group ->> 'delivery_fee_fcfa')::integer, 0);
    v_priced_groups := v_priced_groups || jsonb_build_object(
      'supplier_id', v_group ->> 'supplier_id',
      'supplier_name', v_group ->> 'supplier_name',
      'delivery_mode', v_group ->> 'delivery_mode',
      'delivery_fee_fcfa', coalesce((v_group ->> 'delivery_fee_fcfa')::integer, 0),
      'subtotal_fcfa', v_group_subtotal,
      'items', v_priced_items
    );
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

-- ----------------------------------------------------------------------------
-- Garde `verification_status` : staff uniquement, quel que soit le chemin
-- d'écriture emprunté sur `suppliers` (propriétaire, staff ou reviewer).
-- ----------------------------------------------------------------------------
create or replace function public.guard_supplier_verification_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- `auth.uid()` est nul pour toute connexion sans JWT utilisateur : la
  -- session `service_role` du harnais de test (`test_reset_and_seed`), le
  -- seed direct en superuser (`supabase/seed.sql`), tout outillage
  -- admin/backend futur. Aucun de ces chemins n'a de `sub` de JWT réel — le
  -- garde-fou ne doit s'appliquer qu'à une vraie session `authenticated`
  -- (un utilisateur connecté qui n'est pas staff), jamais à eux.
  if new.verification_status is distinct from old.verification_status
     and auth.uid() is not null
     and not public.is_staff() then
    raise exception 'Non autorisé à modifier le statut de vérification.';
  end if;
  return new;
end;
$$;

drop trigger if exists suppliers_guard_verification_status on public.suppliers;
create trigger suppliers_guard_verification_status
  before update on public.suppliers
  for each row
  execute function public.guard_supplier_verification_status();
