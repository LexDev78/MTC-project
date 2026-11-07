-- Two related changes, in dependency order:
--
-- 1. Every pre-existing product (created before the variant system existed)
--    gets a single "Taille: Standard" characteristic + option + default
--    variant carrying over its current price/stock/photos unchanged. The
--    `product_variants_aggregate_products` trigger (0018) then recomputes
--    `products.price_fcfa`/`stock_quantity`/`has_variants` from that one
--    variant — since it's seeded with the product's own current numbers,
--    those end up identical to what they were before this migration, only
--    now variant-backed. Must run BEFORE the constraint below: it flips
--    `has_variants` to true for these rows, which is what lets them satisfy
--    it once it exists.
-- 2. `products_active_requires_variants`: a product can only be `active`
--    once it has at least one variant — no more listing something for sale
--    with no purchasable combination behind it. A plain `check` constraint
--    can't be used here: it's validated synchronously per statement, which
--    would reject `test_reset_and_seed()`'s own `insert into products`
--    (defaults to `active`, `has_variants` false until its backfill loop —
--    §1's sibling for freshly-seeded rows, see `0020_reseed_characteristic_types.sql`
--    — runs after it) before that loop ever gets a chance to fix it up.
--    `check` also isn't declarable `deferrable` at all in Postgres — only
--    a constraint trigger can be, so this is one of those instead,
--    deferred to transaction commit, by which point every product in the
--    same transaction (seeded or otherwise) already has its variant.

do $$
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
$$;

create or replace function public.check_active_product_has_variants()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'active' and not new.has_variants then
    raise exception 'Un produit actif doit avoir au moins une caractéristique/variante (%).', new.id;
  end if;
  return new;
end;
$$;

create constraint trigger products_active_requires_variants
  after insert or update of status, has_variants
  on public.products
  deferrable initially deferred
  for each row execute function public.check_active_product_has_variants();
