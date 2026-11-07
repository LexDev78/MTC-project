-- RPCs locale-only, test uniquement : contournent la RLS pour mettre en
-- scène ou lire un état qu'aucune session utilisateur réelle ne pourrait
-- produire/consulter légitimement (ex. le stock d'un produit qui
-- appartient à un autre fournisseur, ou le grand livre `stock_movements`
-- d'un fournisseur consulté depuis la session d'un client). Même pattern
-- que `test_reset_and_seed()` (`0002_test_reset_fn.sql`) : `security
-- definer`, exécution réservée à `service_role`, jamais appelable depuis
-- l'app Flutter elle-même.

create or replace function public.test_adjust_stock(
  p_product_id text,
  p_quantity_delta int
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current int;
begin
  select stock_quantity into v_current from public.products where id = p_product_id;
  update public.products set stock_quantity = v_current + p_quantity_delta where id = p_product_id;
  insert into public.stock_movements (id, product_id, quantity_delta, reason)
  values (gen_random_uuid()::text, p_product_id, p_quantity_delta, 'correction');
end;
$$;

revoke all on function public.test_adjust_stock(text, int) from public, anon, authenticated;
grant execute on function public.test_adjust_stock(text, int) to service_role;

create or replace function public.test_fetch_stock_movements(p_product_id text)
returns setof public.stock_movements
language sql
security definer
set search_path = public
as $$
  select * from public.stock_movements where product_id = p_product_id order by occurred_at;
$$;

revoke all on function public.test_fetch_stock_movements(text) from public, anon, authenticated;
grant execute on function public.test_fetch_stock_movements(text) to service_role;
