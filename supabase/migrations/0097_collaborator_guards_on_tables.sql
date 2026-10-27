-- Les permissions, tenues même quand la RLS ne s'applique pas.
--
-- `0094` et `0096` ont posé `supplier_can()` sur les policies. Ce n'était
-- pas assez : une bonne partie des écritures de cette application passe par
-- des fonctions `security definer` — `adjust_stock`,
-- `replace_product_characteristics_and_variants`,
-- `update_order_group_status`, les lots de remises — et **une fonction
-- `security definer` contourne la RLS par construction**. C'est tout son
-- objet.
--
-- Résultat constaté à l'usage : un collaborateur sans le droit « produits »
-- ne pouvait pas renommer un article par une écriture directe (la policy
-- tenait), mais pouvait ajuster son stock et refaire ses variantes (les RPC
-- passaient). Une permission à moitié tenue ne vaut rien : le patron décoche
-- une case et croit avoir fermé une porte.
--
-- ## Pourquoi des déclencheurs plutôt que de corriger chaque fonction
--
-- Il y en a une vingtaine, certaines longues de deux cents lignes. Les
-- rouvrir une à une pour y glisser une condition, c'est vingt occasions de
-- recopier une version périmée — ce qui, dans cette même série de
-- migrations, a déjà réintroduit une faille de sécurité et cassé neuf tests.
--
-- Un déclencheur `before` sur la table s'exécute quel que soit le chemin
-- emprunté : policy, RPC `security definer`, ou écriture directe. Il se pose
-- une fois, se lit en entier, et n'oblige à toucher aucune fonction
-- existante.
--
-- ## La condition est volontairement étroite
--
-- Le déclencheur ne se déclenche que si **toutes** ces conditions tiennent :
--
--   * l'appelant opère bien la boutique à qui appartient la ligne ;
--   * et il n'a pas la permission demandée.
--
-- Un client qui commande (`operating_supplier_id()` est nul), le staff
-- MTC, le propriétaire, et tous les déclencheurs internes qui recalculent
-- une note ou un stock passent sans rien remarquer. Seul un collaborateur
-- à qui l'on n'a pas accordé ce droit est arrêté.

-- Le garde générique. `tg_argv[0]` porte la permission à exiger, et
-- `tg_argv[1]` le nom de la colonne qui désigne le fournisseur — `null`
-- quand il faut le retrouver par le produit.
create or replace function public.guard_supplier_permission()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_permission text := tg_argv[0];
  v_supplier_id uuid;
  v_row jsonb := to_jsonb(coalesce(new, old));
  v_product_id text;
begin
  -- Hors d'un contexte fournisseur, rien à garder : c'est un client, un
  -- livreur, ou un déclencheur interne.
  if public.operating_supplier_id() is null then
    return coalesce(new, old);
  end if;

  if tg_argv[1] = 'supplier_id' then
    v_supplier_id := (v_row ->> 'supplier_id')::uuid;
  else
    -- Variantes, caractéristiques, mouvements de stock : le fournisseur se
    -- lit sur le produit qui les porte.
    v_product_id := v_row ->> 'product_id';
    select p.supplier_id into v_supplier_id
      from public.products p where p.id = v_product_id;
  end if;

  if v_supplier_id is distinct from public.operating_supplier_id() then
    return coalesce(new, old);
  end if;

  if not public.supplier_can(v_permission) then
    raise exception
      'Votre compte n''a pas accès à cette partie de la boutique (%).',
      v_permission;
  end if;

  return coalesce(new, old);
end;
$$;

-- ---- le catalogue ---------------------------------------------------------

create trigger products_guard_permission
  before insert or update or delete on public.products
  for each row execute function public.guard_supplier_permission('products', 'supplier_id');

create trigger product_variants_guard_permission
  before insert or update or delete on public.product_variants
  for each row execute function public.guard_supplier_permission('products', 'product_id');

create trigger product_characteristics_guard_permission
  before insert or update or delete on public.product_characteristics
  for each row execute function public.guard_supplier_permission('products', 'product_id');

create trigger stock_movements_guard_permission
  before insert on public.stock_movements
  for each row execute function public.guard_supplier_permission('products', 'product_id');

-- ---- les remises et les codes --------------------------------------------

create trigger product_promotions_guard_permission
  before insert or update or delete on public.product_promotions
  for each row execute function public.guard_supplier_permission('promotions', 'supplier_id');

create trigger promo_codes_guard_permission
  before insert or update or delete on public.promo_codes
  for each row execute function public.guard_supplier_permission('promotions', 'supplier_id');

-- ---- la vitrine ------------------------------------------------------------

-- `suppliers` porte son identifiant dans `id`, pas dans `supplier_id` : le
-- garde générique ne sait pas le lire. Un garde dédié, de trois lignes.
create or replace function public.guard_storefront_permission()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.operating_supplier_id() is distinct from new.id then
    return new;
  end if;
  if not public.supplier_can('storefront') then
    raise exception 'Votre compte n''a pas accès à la vitrine de cette boutique.';
  end if;
  return new;
end;
$$;

create trigger suppliers_guard_storefront_permission
  before update on public.suppliers
  for each row execute function public.guard_storefront_permission();
