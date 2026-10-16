-- Les permissions d'un collaborateur, réellement tenues.
--
-- `0093` a appris à `operating_supplier_id()` de répondre pour un
-- collaborateur, et a enregistré ce que le patron lui accorde. Mais les
-- policies d'écriture, elles, ne consultaient que la première : un
-- collaborateur à qui l'on n'avait donné que « commandes » pouvait créer
-- des produits et changer les prix.
--
-- Annoncer une permission sans la tenir est pire que de ne pas l'offrir :
-- le patron coche trois cases, croit avoir restreint, et n'a rien
-- restreint. Ce fichier branche `supplier_can()` sur chaque écriture.
--
-- Le propriétaire traverse tout sans rien cocher : `supplier_can()` lui
-- répond toujours vrai. Les règles ci-dessous ne changent donc **rien**
-- pour les comptes d'aujourd'hui — elles n'entrent en jeu qu'à partir du
-- premier collaborateur.

-- ---- le catalogue ---------------------------------------------------------

drop policy if exists "products_write_own" on public.products;
create policy "products_write_own" on public.products
  for all
  using (supplier_id = public.operating_supplier_id() and public.supplier_can('products'))
  with check (supplier_id = public.operating_supplier_id() and public.supplier_can('products'));

-- Variantes et caractéristiques suivent le produit : les séparer
-- permettrait de modifier le prix d'une variante sans le droit d'ouvrir le
-- produit qui la porte.
drop policy if exists "product_variants_write_own" on public.product_variants;
create policy "product_variants_write_own" on public.product_variants
  for all
  using (
    public.supplier_can('products')
    and exists (
      select 1 from public.products p
       where p.id = product_id and p.supplier_id = public.operating_supplier_id()
    )
  )
  with check (
    public.supplier_can('products')
    and exists (
      select 1 from public.products p
       where p.id = product_id and p.supplier_id = public.operating_supplier_id()
    )
  );

drop policy if exists "product_characteristics_write_own" on public.product_characteristics;
create policy "product_characteristics_write_own" on public.product_characteristics
  for all
  using (
    public.supplier_can('products')
    and exists (
      select 1 from public.products p
       where p.id = product_id and p.supplier_id = public.operating_supplier_id()
    )
  )
  with check (
    public.supplier_can('products')
    and exists (
      select 1 from public.products p
       where p.id = product_id and p.supplier_id = public.operating_supplier_id()
    )
  );

-- ---- les remises et les codes --------------------------------------------

drop policy if exists "product_promotions_write_own" on public.product_promotions;
create policy "product_promotions_write_own" on public.product_promotions
  for all
  using (supplier_id = public.operating_supplier_id() and public.supplier_can('promotions'))
  with check (supplier_id = public.operating_supplier_id() and public.supplier_can('promotions'));

drop policy if exists "promo_codes_owner" on public.promo_codes;
create policy "promo_codes_owner" on public.promo_codes
  for all
  using (supplier_id = public.operating_supplier_id() and public.supplier_can('promotions'))
  with check (supplier_id = public.operating_supplier_id() and public.supplier_can('promotions'));

drop policy if exists "promo_code_products_owner" on public.promo_code_products;
create policy "promo_code_products_owner" on public.promo_code_products
  for all
  using (
    public.supplier_can('promotions')
    and exists (
      select 1 from public.promo_codes c
       where c.id = promo_code_id
         and c.supplier_id = public.operating_supplier_id()
    )
  )
  with check (
    public.supplier_can('promotions')
    and exists (
      select 1 from public.promo_codes c
       where c.id = promo_code_id
         and c.supplier_id = public.operating_supplier_id()
    )
  );

-- ---- la vitrine ------------------------------------------------------------

-- Reprend **la définition en vigueur** (`0063`), pas celle de `0036`.
--
-- `0036` portait une troisième branche, `has_reviewed_supplier(id)` : un
-- client ayant laissé un avis pouvait écrire sur la fiche du fournisseur,
-- pour y mettre à jour la note. `0063` a déplacé ce calcul côté serveur et
-- retiré la branche — c'était une faille, un relecteur pouvant renommer la
-- boutique, détourner ses téléphones ou la supprimer.
--
-- Un premier jet de ce fichier l'a réintroduite, en recopiant la policy
-- depuis `0036` au lieu de la lire telle qu'elle vit. Le test de frontières
-- d'écriture l'a dit aussitôt. Une règle qu'on remplace se lit dans la
-- base, pas dans la migration qui l'a créée.
drop policy if exists "suppliers_update_own" on public.suppliers;
create policy "suppliers_update_own" on public.suppliers
  for update using (
    (
      id = public.operating_supplier_id()
      and deleted_at is null
      and public.supplier_can('storefront')
    )
    or public.is_staff()
  )
  with check (
    (
      id = public.operating_supplier_id()
      and deleted_at is null
      and public.supplier_can('storefront')
    )
    or public.is_staff()
  );

-- ---- les avis ---------------------------------------------------------------

drop policy if exists "reviews_update_own_supplier" on public.reviews;
create policy "reviews_update_own_supplier" on public.reviews
  for update
  using (supplier_id = public.operating_supplier_id() and public.supplier_can('reviews'))
  with check (supplier_id = public.operating_supplier_id() and public.supplier_can('reviews'));

-- ---- les commandes -----------------------------------------------------------

-- Le changement de statut d'un groupe passe par une RPC (`0019`), pas par
-- une policy : on y pose la garde directement.
create or replace function public.guard_collaborator_order_access()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Le staff et les déclencheurs internes passent : seul le chemin
  -- fournisseur est concerné.
  if public.operating_supplier_id() is distinct from new.supplier_id then
    return new;
  end if;
  if not public.supplier_can('orders') then
    raise exception 'Vous n''avez pas accès aux commandes de cette boutique.';
  end if;
  return new;
end;
$$;

create trigger order_supplier_groups_guard_collaborator
  before update of status on public.order_supplier_groups
  for each row execute function public.guard_collaborator_order_access();
