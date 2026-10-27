-- Les lignes de commande qui n'auraient jamais dû exister : quantités
-- nulles ou négatives, montants négatifs. Avant `0129`, `place_order` les
-- acceptait (« −3 sacs » ramenait un boubou à 0 FCFA et remontait le stock).
-- Lecture seule.
--
--   psql "$DATABASE_URL" -f supabase/snippets/audit_commandes_negatives.sql
--
-- Pour chaque commande listée : le stock des produits en cause a été gonflé
-- d'autant (voir `stock_movements`, raison `sale` avec un delta positif), et
-- le total payé est faux. Une commande « livrée » de ce genre a aussi pu
-- entrer dans le solde du fournisseur avant `0130`.

\echo '== Lignes de commande à quantité nulle ou négative =='
select o.id as commande, o.placed_at as passee_le, o.client_display_name_snapshot as client,
       g.supplier_name as boutique, g.status as statut, i.product_name_snapshot as produit,
       i.quantity as quantite, i.unit_price_fcfa_snapshot as prix_unitaire, o.total_fcfa as total
  from public.order_items i
  join public.order_supplier_groups g on g.id = i.group_id
  join public.orders o on o.id = g.order_id
 where i.quantity <= 0 or i.unit_price_fcfa_snapshot < 0
 order by o.placed_at;

\echo '== Mouvements de stock « vente » qui ont augmenté le stock =='
select m.occurred_at as le, m.product_id as produit, m.variant_id as variante, m.quantity_delta as delta
  from public.stock_movements m
 where m.reason = 'sale' and m.quantity_delta > 0
 order by m.occurred_at;

\echo '== Montants négatifs =='
select 'groupe' as niveau, g.id, g.subtotal_fcfa, g.delivery_fee_fcfa
  from public.order_supplier_groups g where g.subtotal_fcfa < 0 or g.delivery_fee_fcfa < 0
union all
select 'commande', o.id, o.total_fcfa, null from public.orders o where o.total_fcfa < 0;

\echo '== Paniers à quantité nulle ou négative =='
select c.user_id, c.product_name_snapshot, c.quantity from public.cart_items c where c.quantity <= 0;
