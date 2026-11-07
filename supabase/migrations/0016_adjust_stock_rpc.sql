-- `adjust_stock` — remplace le read-then-write côté Dart
-- (`SupabaseProductDatasource.adjustStock`) par une mise à jour
-- conditionnelle atomique, fermant la race entre la lecture du stock actuel
-- et l'écriture du nouveau total. Prend déjà un `p_variant_id` optionnel
-- (toujours `null` jusqu'à la migration `0018_product_variants.sql`) pour
-- éviter d'écrire ce pattern non-atomique une seconde fois plus tard.
--
-- Voir /Users/solomon/.claude/plans/sunny-splashing-token.md section 3.

alter table public.products
  add constraint products_stock_quantity_non_negative check (stock_quantity >= 0);

create or replace function public.adjust_stock(
  p_product_id text,
  p_quantity_delta integer,
  p_reason text,
  p_variant_id text default null,
  p_note text default null
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supplier_id uuid;
  v_has_variants boolean;
  v_name text;
  v_new_quantity integer;
begin
  select supplier_id, has_variants, name into v_supplier_id, v_has_variants, v_name
    from public.products where id = p_product_id;
  if v_supplier_id is null then
    raise exception 'Produit introuvable : %', p_product_id;
  end if;
  if v_supplier_id is distinct from public.operating_supplier_id() then
    raise exception 'Non autorisé à modifier le stock de ce produit.';
  end if;
  if p_variant_id is null and v_has_variants then
    raise exception 'Ce produit a des variantes : précisez la variante à ajuster.';
  end if;

  if p_variant_id is null then
    update public.products
      set stock_quantity = stock_quantity + p_quantity_delta
      where id = p_product_id and stock_quantity + p_quantity_delta >= 0
      returning stock_quantity into v_new_quantity;
  else
    update public.product_variants
      set stock_quantity = stock_quantity + p_quantity_delta
      where id = p_variant_id and product_id = p_product_id
        and stock_quantity + p_quantity_delta >= 0
      returning stock_quantity into v_new_quantity;
  end if;

  if v_new_quantity is null then
    raise exception 'Stock insuffisant pour % : mouvement de % impossible.', v_name, p_quantity_delta;
  end if;

  insert into public.stock_movements (id, product_id, variant_id, quantity_delta, reason, note)
  values (gen_random_uuid()::text, p_product_id, p_variant_id, p_quantity_delta, p_reason::stock_movement_reason, p_note);

  return v_new_quantity;
end;
$$;

revoke all on function public.adjust_stock(text, integer, text, text, text) from public, anon;
grant execute on function public.adjust_stock(text, integer, text, text, text) to authenticated;
