-- Supplier dashboard product cards need, per product: view count, like
-- (favorite) count, order count, and stock. `stock_quantity` already
-- exists; the other three needed new plumbing:
--   1. `products.view_count` — a plain counter column, bumped once per
--      client visit to `ProductDetailScreen`.
--   2. `increment_product_view` — `products` has no client-writable UPDATE
--      policy at all (only the owner/staff, see `products_write_own`/
--      `products_update_verification_staff`), so bumping the counter from
--      an arbitrary client session needs a `security definer` RPC, same
--      remedy as `set_products_supplier_verification` (0009).
--   3. `get_supplier_product_stats` — favorite count lives in `favorites`,
--      order count in `order_items`; neither is denormalized onto
--      `products`. One RPC returning both, aggregated per product, avoids
--      the dashboard firing N+1 queries/subscriptions for a supplier with
--      many products.

alter table public.products add column view_count integer not null default 0;

create or replace function public.increment_product_view(p_product_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.products set view_count = view_count + 1 where id = p_product_id;
end;
$$;

revoke all on function public.increment_product_view(text) from public, anon;
grant execute on function public.increment_product_view(text) to authenticated;

-- Guarded to the caller's own operating supplier (mirrors
-- `set_products_supplier_verification`'s `is_staff()` guard) — a supplier
-- session can only ever ask for its own stats, never another's.
create or replace function public.get_supplier_product_stats(p_supplier_id uuid)
returns table(product_id text, favorite_count bigint, order_count bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_supplier_id is distinct from public.operating_supplier_id() then
    raise exception 'Non autorisé.';
  end if;

  return query
    select
      p.id,
      coalesce(f.favorite_count, 0),
      coalesce(o.order_count, 0)
    from public.products p
    left join (
      select favorites.product_id, count(*) as favorite_count
      from public.favorites
      group by favorites.product_id
    ) f on f.product_id = p.id
    left join (
      select order_items.product_id, count(*) as order_count
      from public.order_items
      group by order_items.product_id
    ) o on o.product_id = p.id
    where p.supplier_id = p_supplier_id;
end;
$$;

revoke all on function public.get_supplier_product_stats(uuid) from public, anon;
grant execute on function public.get_supplier_product_stats(uuid) to authenticated;
