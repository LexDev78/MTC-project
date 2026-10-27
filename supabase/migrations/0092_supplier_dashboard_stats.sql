-- Ce que le fournisseur veut savoir en ouvrant son application.
--
-- Le tableau de bord montrait un message de bienvenue, un badge de
-- vérification, une note, et la liste des produits. Rien sur ce qui se
-- passe : combien de ventes, combien de gens ont regardé, combien a été
-- gagné. Pour le savoir, il fallait ouvrir trois écrans et faire les
-- additions de tête.
--
-- ## Une seule lecture
--
-- La tentation était de tout charger dans l'app — commandes, produits,
-- retraits — et d'additionner en Dart. L'écran d'accueil se serait ouvert
-- en rapatriant toutes les commandes du fournisseur depuis le premier jour,
-- à chaque démarrage, sur une connexion mobile malienne. Postgres compte
-- mieux et transmet moins.
--
-- ## Ce que cette fonction ne calcule pas
--
-- Ni commission, ni net, ni solde disponible. Ces trois-là obéissent à une
-- règle métier qui vit déjà dans `compute_financial_summary.dart`, et la
-- réécrire ici en ferait **deux** — avec la certitude qu'un jour l'une sera
-- corrigée et pas l'autre, sur un calcul qui dit au fournisseur combien il
-- a gagné. La fonction rend donc les bruts : le chiffre d'affaires livré et
-- ce qui a déjà été versé. L'app applique la règle, une seule fois.
create or replace function public.fetch_supplier_dashboard_stats()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with moi as (select public.operating_supplier_id() as id),
  produits as (
    select
      count(*) as total,
      count(*) filter (where p.status = 'active') as actifs,
      coalesce(sum(p.view_count), 0) as vues
      from public.products p, moi
     where p.supplier_id = moi.id
  ),
  groupes as (
    select
      count(*) as total,
      count(*) filter (where g.status = 'delivered') as livrees,
      -- « En cours » : tout ce qui n'est ni livré ni annulé. C'est ce que le
      -- fournisseur doit traiter aujourd'hui.
      count(*) filter (
        where g.status not in ('delivered', 'cancelled')
      ) as en_cours,
      -- Jamais `delivery_fee_fcfa` : en livraison MTC il revient à la
      -- plateforme, pas au vendeur. Même règle que
      -- `compute_financial_summary`.
      coalesce(sum(g.subtotal_fcfa) filter (
        where g.status = 'delivered'
      ), 0) as brut,
      coalesce(sum(g.subtotal_fcfa) filter (
        where g.status = 'delivered' and o.placed_at >= now() - interval '30 days'
      ), 0) as brut_30j,
      coalesce(sum(g.subtotal_fcfa) filter (
        where g.status = 'delivered' and o.placed_at >= now() - interval '7 days'
      ), 0) as brut_7j
      from public.order_supplier_groups g
      join public.orders o on o.id = g.order_id, moi
     where g.supplier_id = moi.id
  ),
  retraits as (
    -- Un retrait refusé n'a rien versé. Même filtre que le calcul financier.
    select coalesce(sum(r.amount_fcfa) filter (
             where r.status <> 'rejected'
           ), 0) as verse
      from public.payout_requests r, moi
     where r.supplier_id = moi.id
  ),
  articles as (
    -- Les cinq articles les plus vendus, en quantité livrée. C'est la
    -- question que se pose un commerçant : « qu'est-ce qui part ? »
    select coalesce(jsonb_agg(ligne order by quantite desc), '[]'::jsonb) as top
      from (
        select
          i.product_name_snapshot as nom,
          sum(i.quantity) as quantite,
          sum(i.unit_price_fcfa_snapshot * i.quantity) as montant,
          jsonb_build_object(
            'name', i.product_name_snapshot,
            'quantity', sum(i.quantity),
            'amount_fcfa', sum(i.unit_price_fcfa_snapshot * i.quantity)
          ) as ligne
          from public.order_items i
          join public.order_supplier_groups g on g.id = i.group_id, moi
         where g.supplier_id = moi.id
           and g.status = 'delivered'
         group by i.product_name_snapshot
         order by quantite desc
         limit 5
      ) s
  )
  select jsonb_build_object(
    'products_total', produits.total,
    'products_active', produits.actifs,
    'views_total', produits.vues,
    'orders_total', groupes.total,
    'orders_delivered', groupes.livrees,
    'orders_in_progress', groupes.en_cours,
    'gross_fcfa', groupes.brut,
    'gross_last_30_days_fcfa', groupes.brut_30j,
    'gross_last_7_days_fcfa', groupes.brut_7j,
    'paid_out_fcfa', retraits.verse,
    'best_sellers', articles.top
  )
    from produits, groupes, retraits, articles;
$$;

revoke all on function public.fetch_supplier_dashboard_stats() from public, anon;
grant execute on function public.fetch_supplier_dashboard_stats() to authenticated;
