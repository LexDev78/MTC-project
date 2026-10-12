-- Test-only: gives a product a single default variant without going through
-- the full characteristics/options flow — several integration tests only
-- care about "this product is variant-backed" (activating a draft product,
-- low-stock notifications, ...), and now that
-- `products_active_requires_variants` (0021) requires exactly that before a
-- product can go `active`, they need a cheap way to get there. Same
-- security-definer-RPC-for-service_role pattern as `test_adjust_stock`
-- (`0004_test_admin_helpers.sql`).
create or replace function public.test_give_product_a_variant(
  p_product_id text,
  p_price_fcfa integer default null,
  p_stock_quantity integer default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_price integer;
  v_stock integer;
begin
  select coalesce(p_price_fcfa, price_fcfa), coalesce(p_stock_quantity, stock_quantity)
    into v_price, v_stock
    from public.products
    where id = p_product_id;

  insert into public.product_variants (id, product_id, name, price_fcfa, stock_quantity, is_default)
  values (gen_random_uuid()::text, p_product_id, 'Standard', v_price, v_stock, true);
end;
$$;

revoke all on function public.test_give_product_a_variant(text, integer, integer) from public, anon, authenticated;
grant execute on function public.test_give_product_a_variant(text, integer, integer) to service_role;
