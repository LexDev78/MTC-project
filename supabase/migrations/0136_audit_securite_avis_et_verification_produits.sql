-- 0136 — Audit de sécurité du 27/10/2026 : deux failles confirmées.
--
-- 1. AVIS FORGÉS (reviews_insert_own_delivered, depuis 0001)
--    La policy compare `g.order_id = g.order_id` (toujours vrai) au lieu de
--    `g.order_id = reviews.order_id`, et ne vérifie jamais `supplier_id`.
--    Un client qui a UNE commande livrée peut donc, par un simple
--    `insert into reviews` REST, publier autant d'avis qu'il veut (en
--    changeant `order_id`) sur N'IMPORTE QUELLE boutique (`supplier_id`
--    libre). Ces avis apparaissent dans `fetch_supplier_reviews`.
--    L'app passe déjà par `submit_review` (0063) : l'insert direct ne sert
--    à rien d'autre qu'à l'attaque. On le ferme.
--
-- 2. BOUTIQUE NON VÉRIFIÉE RENDUE PUBLIQUE (products_write_own)
--    `is_supplier_verified` est calculé côté Dart
--    (`supplier_product_controller.dart`) et la base le croit : une boutique
--    `unverified`/`pending`/`rejected` peut écrire
--    `is_supplier_verified = true` sur ses produits (insert ou update) et
--    ils deviennent visibles et achetables par tous, sans KYC.
--    De même `supplier_name`/`supplier_type` sont libres : une boutique
--    peut afficher « MTC Officiel » sur ses produits.
--    Ces trois colonnes sont désormais imposées par la base.

-- ---------------------------------------------------------------- 1. avis
drop policy if exists reviews_insert_own_delivered on public.reviews;
revoke insert on public.reviews from authenticated, anon;

-- ------------------------------------------------- 2. colonnes de confiance
create or replace function public.stamp_product_trusted_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supplier public.suppliers;
begin
  -- Le staff (RPC de décision KYC, boutique officielle), les écritures
  -- internes déjà marquées de confiance et le service_role gardent la main.
  if auth.uid() is null
     or public.is_staff()
     or current_setting('app.trusted_product_write', true) = 'on'
  then
    return new;
  end if;

  select * into v_supplier from public.suppliers where id = new.supplier_id;

  new.supplier_name := coalesce(v_supplier.business_name, new.supplier_name);
  new.supplier_type := coalesce(v_supplier.supplier_type, new.supplier_type);

  if tg_op = 'INSERT' then
    new.is_supplier_verified := coalesce(v_supplier.verification_status = 'verified', false);
  else
    -- Seul le staff (set_products_supplier_verification /
    -- review_supplier_kyc) change ce drapeau.
    new.is_supplier_verified := old.is_supplier_verified;
  end if;

  return new;
end;
$$;

revoke all on function public.stamp_product_trusted_columns() from public, anon, authenticated;

drop trigger if exists products_stamp_trusted_columns on public.products;
-- Nommé pour passer APRÈS products_guard_permission (ordre alphabétique) et
-- avant les déclencheurs AFTER.
create trigger products_stamp_trusted_columns
  before insert or update on public.products
  for each row execute function public.stamp_product_trusted_columns();
