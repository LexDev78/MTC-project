-- Le nombre de produits qu'un client voit dans une boutique, compté par la
-- base.
--
-- La vitrine, et maintenant la liste « Boutiques du Mali », affichaient
-- `suppliers.product_count`. Ce compteur est tenu par l'application de la
-- boutique (`adjustProductCount` : lire, ajouter un, réécrire) : il compte
-- les brouillons et les produits en pause, que le client ne voit pas, et la
-- boutique peut l'écrire directement — aucune garde ne le protège
-- (`guard_supplier_badges` ne couvre que la note, le statut et la forme
-- juridique). Montré à tous les clients, c'est une promesse que rien ne
-- tient : « 12 produits » sur une vitrine qui en montre trois.
--
-- Une colonne calculée que PostgREST sert à côté de la boutique
-- (`select=*,listed_product_count`) : les produits actifs d'une boutique
-- vérifiée, c'est-à-dire exactement ceux de `products_select_public`. Pas de
-- `security definer` : ces produits sont visibles de tous, et le filtre
-- explicite rend le même nombre quel que soit celui qui demande — y compris
-- la boutique elle-même, qui voit aussi ses brouillons.
--
-- `product_count` reste tel quel : c'est le compteur de travail de la
-- boutique, que les clients ne lisent plus.

create or replace function public.listed_product_count(s public.suppliers)
returns integer
language sql
stable
set search_path = public
as $$
  select count(*)::integer
    from public.products p
   where p.supplier_id = s.id
     and p.status = 'active'
     and p.is_supplier_verified;
$$;

grant execute on function public.listed_product_count(public.suppliers) to anon, authenticated;

notify pgrst, 'reload schema';
