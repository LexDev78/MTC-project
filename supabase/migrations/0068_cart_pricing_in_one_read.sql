-- Le panier lisait un produit entier par ligne, pour en tirer un prix.
--
-- `productDetailProvider` passe par `getById`, dont la lecture imbriquée
-- ramène les caractéristiques, leurs options, les variantes et les options
-- de chaque variante. C'est ce qu'il faut pour une fiche produit. Pour
-- afficher le prix d'une ligne de panier, il faut le prix, celui de la
-- variante choisie, et les promotions — et l'app faisait une de ces
-- requêtes **par ligne**, à chaque ouverture du panier, puis N autres au
-- paiement (`checkoutGroupsProvider` appelait `getById` pour chaque
-- article).
--
-- Cette fonction renvoie en **un seul appel**, pour tous les produits du
-- panier, exactement ce dont le prix et les frais de livraison ont besoin.
-- Un panier de cinq articles passe de dix lectures imbriquées à une.
--
-- `security invoker` (le défaut) et non `definer` : tout ce qu'elle renvoie
-- est déjà public en lecture (`products_select_public`,
-- `product_variants_select_public`, `product_promotions_select_public`),
-- donc la RLS doit continuer de s'appliquer — un produit retiré de la vente
-- ne doit pas réapparaître par ce chemin.
create or replace function public.fetch_pricing_inputs(p_product_ids text[])
returns jsonb
language sql
stable
set search_path = public
as $$
  select coalesce(jsonb_object_agg(p.id, jsonb_build_object(
           'price_fcfa', p.price_fcfa,
           'weight_kg', p.weight_kg,
           'category', p.category,
           'city', p.city,
           'supplier_id', p.supplier_id,
           'supplier_name', p.supplier_name,
           'allows_self_delivery', p.allows_self_delivery,
           'allows_mtc_delivery', p.allows_mtc_delivery,
           'stock_quantity', p.stock_quantity,
           'variants', coalesce((
             select jsonb_object_agg(v.id, jsonb_build_object(
                      'price_fcfa', v.price_fcfa,
                      'stock_quantity', v.stock_quantity
                    ))
               from public.product_variants v where v.product_id = p.id
           ), '{}'::jsonb),
           'promotions', coalesce((
             select jsonb_agg(to_jsonb(pr))
               from public.product_promotions pr where pr.product_id = p.id
           ), '[]'::jsonb)
         )), '{}'::jsonb)
    from public.products p
   where p.id = any(p_product_ids);
$$;

grant execute on function public.fetch_pricing_inputs(text[]) to anon, authenticated;
