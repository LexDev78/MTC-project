-- Un fournisseur ne retire que l'argent que MTC a réellement reçu.
--
-- ===========================================================================
-- Ce qui se passait (signalé par l'audit)
-- ===========================================================================
--
-- `guard_payout_amount` (`0033`, `0101`) calculait le solde ainsi :
--
--   somme des groupes « livrés » − commission − retraits déjà demandés
--
-- sans regarder **qui** avait encaissé. Or une boutique qui livre elle-même
-- un client qui paie à la livraison garde l'argent dans sa poche : MTC n'en
-- voit pas un franc. Et la boutique passe elle-même sa commande à « livrée »
-- (`update_order_group_status`). D'où la fraude : un faux client, une
-- fausse commande, « livrée » d'un geste, et une demande de versement que
-- MTC paie de sa caisse.
--
-- Le jeu de démonstration en est l'illustration : Bogolan Bamako y a deux
-- ventes livrées par ses soins, payées en espèces (50 000 FCFA), et un
-- versement de 10 000 FCFA marqué payé. Avec la règle juste, MTC ne lui
-- devait rien : c'est elle qui devait 5 000 FCFA de commission.
--
-- ===========================================================================
-- La règle, écrite une seule fois
-- ===========================================================================
--
-- Une vente livrée se range dans l'une de trois cases, selon qui tient
-- l'argent :
--
--   * MTC — le paiement en ligne est confirmé (`payment_status = 'paid'`,
--     que seul le staff pose, `0106`), ou un livreur MTC a remis le colis et
--     encaissé le paiement à la livraison (course `delivered`, close par le
--     scan du client, `0054`) ;
--   * la boutique — elle a livré elle-même et encaissé à la livraison ;
--   * personne encore — le client a choisi de payer en ligne, et MTC n'a
--     pas confirmé l'avoir reçu.
--
--   dû par MTC = encaissé par MTC − commission sur ces ventes
--                − commission due sur les ventes encaissées par la boutique
--   disponible = dû par MTC − retraits non refusés
--
-- Un solde négatif dit que la boutique doit sa commission à MTC : aucun
-- retrait n'est possible tant qu'il l'est. Les ventes « en attente » ne
-- comptent ni pour ni contre, jusqu'à ce que le paiement soit confirmé.
--
-- Cette règle ne vit plus qu'ici. L'app la recalculait en Dart
-- (`compute_financial_summary.dart`) en même temps que la garde la
-- recalculait en SQL : deux copies, qu'il aurait fallu corriger ensemble.
-- L'app lit désormais le résultat (`fetch_my_finance_summary`).
--
-- ===========================================================================
-- Et un point faible de l'audit : le statut d'une demande à sa création
-- ===========================================================================
--
-- La politique d'insertion vérifiait la boutique, pas le contenu : une
-- demande pouvait naître `paid`, datée d'il y a un an, avec un motif de
-- refus. Elle naît désormais toujours `requested`, maintenant.

create or replace function public.supplier_ledger(p_supplier_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with ventes as (
    select g.subtotal_fcfa,
           case
             when o.payment_status = 'paid' then 'mtc'
             when o.payment_method = 'on_delivery'
                  and g.delivery_mode = 'mtc_delivery'
                  and exists (
                    select 1 from public.deliveries d
                     where d.supplier_group_id = g.id
                       and d.status = 'delivered'
                       and d.courier_id is not null
                  ) then 'mtc'
             when o.payment_method = 'on_delivery'
                  and g.delivery_mode = 'self_delivery' then 'boutique'
             else 'en_attente'
           end as encaisse_par
      from public.order_supplier_groups g
      join public.orders o on o.id = g.order_id
     where g.supplier_id = p_supplier_id
       and g.status = 'delivered'
  ),
  taux as (
    -- MTC ne se prend pas de commission sur ses propres ventes.
    select case
             when s.supplier_type = 'principal' then 0::double precision
             else coalesce(
               (select f.commission_rate_percent from public.supplier_finance_settings f
                 where f.supplier_id = s.id),
               10.0
             )
           end as pourcentage
      from public.suppliers s
     where s.id = p_supplier_id
  ),
  sommes as (
    select coalesce(sum(subtotal_fcfa), 0)::bigint as brut,
           coalesce(sum(subtotal_fcfa) filter (where encaisse_par = 'mtc'), 0)::bigint as par_mtc,
           coalesce(sum(subtotal_fcfa) filter (where encaisse_par = 'boutique'), 0)::bigint as par_boutique,
           coalesce(sum(subtotal_fcfa) filter (where encaisse_par = 'en_attente'), 0)::bigint as en_attente
      from ventes
  ),
  commissions as (
    -- Arrondi au franc, une fois par case : la même règle que l'ancienne
    -- garde (`round(... ::numeric)`), sans quoi l'écran et la garde
    -- différeraient d'un franc.
    select round((s.par_mtc * t.pourcentage / 100)::numeric)::bigint as sur_mtc,
           round((s.par_boutique * t.pourcentage / 100)::numeric)::bigint as due
      from sommes s, taux t
  ),
  retraits as (
    -- Un retrait refusé n'a rien versé ; les autres réservent leur montant.
    select coalesce(sum(r.amount_fcfa) filter (where r.status <> 'rejected'), 0)::bigint as verse
      from public.payout_requests r
     where r.supplier_id = p_supplier_id
  )
  select jsonb_build_object(
    'gross_fcfa', s.brut,
    'collected_by_mtc_fcfa', s.par_mtc,
    'collected_by_supplier_fcfa', s.par_boutique,
    'awaiting_payment_fcfa', s.en_attente,
    'commission_rate_percent', t.pourcentage,
    'commission_on_mtc_fcfa', c.sur_mtc,
    'commission_owed_fcfa', c.due,
    'commission_fcfa', c.sur_mtc + c.due,
    'net_fcfa', s.par_mtc - c.sur_mtc - c.due,
    'paid_out_fcfa', r.verse,
    'available_fcfa', s.par_mtc - c.sur_mtc - c.due - r.verse
  )
    from sommes s, taux t, commissions c, retraits r;
$$;

revoke all on function public.supplier_ledger(uuid) from public, anon, authenticated, service_role;

-- ---- la garde des retraits ------------------------------------------------------------

-- Reprise de `0101`, avec le grand livre à la place du calcul recopié, et
-- la demande remise d'aplomb avant d'être comptée.
create or replace function public.guard_payout_amount()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_disponible bigint;
begin
  -- `auth.uid() is null` : le jeu de démonstration, qui insère ses
  -- demandes de retrait d'un bloc — même repli que les autres gardes.
  if auth.uid() is null then
    return new;
  end if;

  -- Ce que la demande dit d'elle-même ne compte pas (`0131`) : elle naît
  -- demandée, maintenant, sans décision.
  new.status := 'requested';
  new.requested_at := now();
  new.processed_at := null;
  new.rejection_reason := null;
  if new.payout_destination is null or btrim(new.payout_destination) = '' then
    raise exception 'Indiquez le numéro qui recevra le versement.';
  end if;

  -- Verrou sur la fiche de la boutique, **avant** de calculer le solde
  -- (`0101`) : deux demandes simultanées ne lisent pas le même solde.
  perform 1 from public.suppliers where id = new.supplier_id for update;

  if new.amount_fcfa is null or new.amount_fcfa <= 0 then
    raise exception 'Le montant demandé doit être positif.';
  end if;

  v_disponible := coalesce((public.supplier_ledger(new.supplier_id) ->> 'available_fcfa')::bigint, 0);
  if new.amount_fcfa > v_disponible then
    raise exception 'Montant demandé (% FCFA) supérieur au solde disponible (% FCFA).',
      new.amount_fcfa, v_disponible;
  end if;

  return new;
end;
$$;

-- ---- ce que l'app lit ------------------------------------------------------------------

-- Le grand livre de la boutique que l'on opère. Le propriétaire seulement :
-- l'argent ne se délègue pas à un collaborateur (`0093`). Le staff lit
-- celui de la boutique MTC, sans commission.
create or replace function public.fetch_my_finance_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_boutique uuid := public.operating_supplier_id();
begin
  if v_boutique is null or not (public.is_supplier_owner() or public.is_staff()) then
    raise exception 'Les finances de la boutique sont réservées à son propriétaire.';
  end if;
  return public.supplier_ledger(v_boutique);
end;
$$;

revoke all on function public.fetch_my_finance_summary() from public, anon;
grant execute on function public.fetch_my_finance_summary() to authenticated;

-- Le total des commissions de la plateforme, pour l'administration : la
-- même règle, boutique par boutique, et non plus un taux appliqué en Dart
-- à toutes les commandes livrées.
create or replace function public.fetch_platform_commission_fcfa()
returns bigint
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Réservé aux administrateurs MTC.';
  end if;
  return (
    select coalesce(sum((public.supplier_ledger(s.id) ->> 'commission_fcfa')::bigint), 0)
      from public.suppliers s
     where s.supplier_type = 'tiers'
  );
end;
$$;

revoke all on function public.fetch_platform_commission_fcfa() from public, anon;
grant execute on function public.fetch_platform_commission_fcfa() to authenticated;

-- Reprise de `0092` : le tableau de bord porte le grand livre pour le
-- propriétaire, et plus rien d'argent pour un collaborateur — `paid_out_fcfa`
-- lui parvenait jusqu'ici, l'écran se contentant de ne pas l'afficher.
create or replace function public.fetch_supplier_dashboard_stats()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with moi as (
    select public.operating_supplier_id() as id,
           public.is_supplier_owner() or public.is_staff() as voit_l_argent
  ),
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
      -- plateforme, pas au vendeur.
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
    'paid_out_fcfa', case when moi.voit_l_argent
      then (public.supplier_ledger(moi.id) ->> 'paid_out_fcfa')::bigint else 0 end,
    'finance', case when moi.voit_l_argent then public.supplier_ledger(moi.id) end,
    'best_sellers', articles.top
  )
    from moi, produits, groupes, articles;
$$;

notify pgrst, 'reload schema';
