-- Lot 11 : `ProductRepository.updateSupplierVerification` (called from
-- `KycReviewController.approve/reject`) did a raw client-side
-- `update products set is_supplier_verified = ... where supplier_id = ...`
-- — real bug found via the newly-ported repository tests (Lot 10/11):
-- `products` has no staff-read SELECT policy, and Postgres RLS requires a
-- row to be visible via *some* SELECT-capable policy for an UPDATE to even
-- locate it, not just satisfy the UPDATE policy's own USING clause. Staff
-- genuinely had zero visibility into another supplier's unverified
-- products, so this UPDATE silently affected 0 rows every time — a
-- supplier's account/profile would flip to "verified" on KYC approval, but
-- their products stayed permanently invisible to clients
-- (`products_select_public` requires `is_supplier_verified = true`).
-- Same remedy as `update_order_group_status`/`set_order_voice_message`
-- (Lots 5/9): a `security definer` RPC, which runs unconstrained by the
-- caller's own RLS visibility, with its own explicit `is_staff()` gate.
create or replace function public.set_products_supplier_verification(
  p_supplier_id uuid,
  p_verified boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_staff() then
    raise exception 'Non autorisé.';
  end if;

  update public.products
    set is_supplier_verified = p_verified
    where supplier_id = p_supplier_id;
end;
$$;

revoke all on function public.set_products_supplier_verification(uuid, boolean) from public, anon;
grant execute on function public.set_products_supplier_verification(uuid, boolean) to authenticated;
