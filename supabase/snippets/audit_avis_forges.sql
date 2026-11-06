-- Les avis que la faille 1 de l'audit du 27/10/2026 a pu laisser entrer,
-- à passer sur la base de production après le déploiement de `0136`.
--
-- Jusqu'à `0136`, la policy `reviews_insert_own_delivered` comparait
-- `g.order_id` à lui-même et ne regardait pas `supplier_id` : un client avec
-- une seule commande livrée pouvait écrire autant d'avis qu'il voulait, sur
-- la boutique de son choix, en changeant `order_id`. Un vrai avis, lui, vient
-- de `submit_review`, qui l'attache à un groupe livré de la commande du
-- client, chez la boutique de ce groupe.
--
-- Lecture seule. Lancer depuis l'éditeur SQL du tableau de bord, ou :
--
--   psql "$DATABASE_URL" -f supabase/snippets/audit_avis_forges.sql
--
-- 1. Les avis forgés : pas de groupe, groupe d'une autre commande, commande
--    d'un autre client, autre boutique que celle du groupe, ou groupe jamais
--    livré.
select r.id as avis,
       r.created_at,
       r.client_id,
       r.supplier_id as boutique_notee,
       r.stars,
       left(r.comment, 80) as extrait,
       case
         when g.id is null then 'groupe inexistant'
         when g.order_id is distinct from r.order_id then 'groupe d''une autre commande'
         when o.client_id is distinct from r.client_id then 'commande d''un autre client'
         when g.supplier_id is distinct from r.supplier_id then 'autre boutique que celle du groupe'
         when g.status <> 'delivered' then 'groupe non livré'
       end as motif
  from public.reviews r
  left join public.order_supplier_groups g on g.id = r.supplier_group_id
  left join public.orders o on o.id = g.order_id
 where g.id is null
    or g.order_id is distinct from r.order_id
    or o.client_id is distinct from r.client_id
    or g.supplier_id is distinct from r.supplier_id
    or g.status <> 'delivered'
 order by r.supplier_id, r.created_at;

-- 2. Pour mémoire, ce que `0138` refuse désormais : plusieurs avis du même
--    client sur la même boutique à moins de 30 jours d'écart. Pas forcément
--    des faux — un client content qui commande souvent —, mais c'est ainsi
--    qu'un complice gonflait une note.
select r.client_id, r.supplier_id, count(*) as avis,
       min(r.created_at) as premier, max(r.created_at) as dernier,
       round(avg(r.stars), 2) as moyenne
  from public.reviews r
 where exists (
   select 1 from public.reviews r2
    where r2.client_id = r.client_id and r2.supplier_id = r.supplier_id
      and r2.id <> r.id
      and abs(extract(epoch from (r2.created_at - r.created_at))) < 30 * 86400
 )
 group by r.client_id, r.supplier_id
 order by avis desc;

-- 3. Une fois les avis forgés supprimés (décision humaine), la note de
--    chaque boutique touchée se recalcule depuis les avis restants, et se
--    recopie sur ses produits — comme le fait `submit_review`. À lancer en
--    connaissance de cause, boutique par boutique :
--
-- begin;
-- update public.suppliers s
--    set rating_average = coalesce((select avg(stars) from public.reviews where supplier_id = s.id), 0),
--        rating_count = (select count(*) from public.reviews where supplier_id = s.id)
--  where s.id = '<boutique>';
-- update public.products p
--    set rating_average = s.rating_average, rating_count = s.rating_count
--   from public.suppliers s
--  where s.id = p.supplier_id and s.id = '<boutique>';
-- commit;
