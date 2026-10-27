-- La répartition des avis d'un produit par nombre d'étoiles.
--
-- La fiche produit du client suit désormais le kit FlutterShop, dont le
-- résumé des avis (`ReviewCard`) montre, à côté de la moyenne, une barre par
-- note de 5 à 1. `fetch_product_review_summary` ne donne que le nombre et la
-- moyenne ; la liste des avis, elle, est paginée par 20 — une répartition
-- calculée sur sa première page serait fausse dès le 21e avis.
--
-- Même périmètre exactement que le résumé : les avis laissés sur un groupe de
-- commande livré qui contenait ce produit. Les deux doivent toujours compter
-- les mêmes avis, sinon la somme des barres ne ferait pas le total affiché.
create or replace function public.fetch_product_rating_distribution(p_product_id text)
returns table (stars integer, review_count integer)
language sql
stable
security definer
set search_path = public
as $$
  select r.stars::integer, count(*)::integer
    from public.reviews r
   where exists (
     select 1
       from public.order_items i
       join public.order_supplier_groups g on g.id = i.group_id
      where i.group_id = r.supplier_group_id
        and i.product_id = p_product_id
        and g.status = 'delivered'
   )
   group by r.stars;
$$;

-- Les avis sont publics, comme le résumé : la répartition n'en dit pas plus.
grant execute on function public.fetch_product_rating_distribution(text) to anon, authenticated;
