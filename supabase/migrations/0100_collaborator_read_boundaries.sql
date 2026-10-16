-- Ce qu'un collaborateur ne doit pas **voir**.
--
-- Les trois migrations précédentes ont gardé les écritures : policies
-- (`0094`, `0096`) puis déclencheurs, pour couvrir les fonctions
-- `security definer` qui contournent la RLS (`0097`). Les **lectures**, elles,
-- sont restées ouvertes — et c'est une faute de raisonnement de ma part :
-- une permission qui n'empêche que d'écrire laisse voir, et voir suffit à
-- nuire.
--
-- Trois fuites constatées à l'usage :
--
--  * `payout_requests` était lisible par tout compte opérant la boutique —
--    montants demandés, numéros Mobile Money de destination, statuts. Un
--    vendeur au comptoir voyait où part l'argent de son patron.
--  * `supplier_finance_settings` exposait le taux de commission négocié.
--  * `fetch_my_promo_codes` et `fetch_my_promotion_batches` sont
--    `security definer` : elles passaient outre les policies de `0094` et
--    rendaient codes et remises à un collaborateur sans le droit.
--
-- Le principe qui manquait, et qu'on applique ici : **ce qu'un rôle n'a pas
-- le droit de faire, il n'a pas le droit de le voir.**
--
-- Les corps de fonction ci-dessous sont repris **de la base**, pas récrits :
-- ils sont enveloppés d'une garde, à la ligne près. Trois fois dans cette
-- série, retaper une définition en a perdu une partie.

CREATE OR REPLACE FUNCTION public.fetch_my_promo_codes()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
    -- Sans le droit « remises », il n'y a rien à montrer. Un tableau vide
  -- et non une exception : l'écran n'est de toute façon plus atteignable,
  -- et faire échouer une lecture produirait une erreur technique là où il
  -- n'y a qu'une permission manquante.
  select case when public.supplier_can('promotions') then (
  select coalesce(jsonb_agg(row order by created_at desc), '[]'::jsonb) from (
      select c.created_at, jsonb_build_object(
               'id', c.id,
               'code', c.code,
               'percent', c.percent,
               'label', c.label,
               'is_active', c.is_active,
               'starts_at', c.starts_at,
               'ends_at', c.ends_at,
               'max_uses', c.max_uses,
               'max_uses_per_client', c.max_uses_per_client,
               'min_order_fcfa', c.min_order_fcfa,
               'uses_count', c.uses_count,
               'product_ids', coalesce((
                 select jsonb_agg(pp.product_id)
                   from public.promo_code_products pp
                  where pp.promo_code_id = c.id
               ), '[]'::jsonb),
               'redemptions', coalesce((
                 select jsonb_agg(jsonb_build_object(
                          'id', r.id,
                          'created_at', r.created_at,
                          'discount_fcfa', r.discount_fcfa,
                          'client_name', coalesce(r.client_display_name_snapshot, 'Client MTC'),
                          'items', coalesce((
                            select jsonb_agg(jsonb_build_object(
                                     'product_name', i.product_name_snapshot,
                                     'quantity', i.quantity,
                                     'unit_discount_fcfa', i.unit_discount_fcfa
                                   ))
                              from public.promo_code_redemption_items i
                             where i.redemption_id = r.id
                          ), '[]'::jsonb)
                        ) order by r.created_at desc)
                   from public.promo_code_redemptions r
                  where r.promo_code_id = c.id
               ), '[]'::jsonb)
             ) as row
        from public.promo_codes c
       where c.supplier_id = public.operating_supplier_id()
    ) t
  ) else '[]'::jsonb end;
$function$;

CREATE OR REPLACE FUNCTION public.fetch_my_promotion_batches()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
    -- Même garde que les codes promo : ces deux écrans vont ensemble.
  select case when public.supplier_can('promotions') then (
  select coalesce(jsonb_agg(row order by created_at desc), '[]'::jsonb)
      from (
        select
          min(p.created_at) as created_at,
          jsonb_build_object(
            'batch_id', min(p.batch_id),
            -- Sans lot, l'identifiant de la ligne tient lieu de clé : l'écran
            -- la traite alors comme un lot d'un seul produit.
            'key', coalesce(min(p.batch_id), min(p.id)),
            'kind', min(p.kind::text),
            'value', min(p.value),
            'min_quantity', min(p.min_quantity),
            'starts_at', min(p.starts_at),
            'ends_at', min(p.ends_at),
            'label', min(p.label),
            'created_at', min(p.created_at),
            -- Un lot dont une partie serait arrêtée n'a pas de sens : l'arrêt
            -- est groupé. `bool_and` le dit quand même, plutôt que de
            -- supposer.
            'is_active', bool_and(p.is_active),
            'product_count', count(*),
            'product_names', jsonb_agg(pr.name order by pr.name),
            -- Les identifiants, pour que l'écran puisse rouvrir la remise
            -- avec ses produits déjà cochés. Sans eux, « modifier » obligerait
            -- à re-sélectionner la couverture de mémoire.
            'product_ids', jsonb_agg(pr.id order by pr.name)
          ) as row
          from public.product_promotions p
          join public.products pr on pr.id = p.product_id
         where p.supplier_id = public.operating_supplier_id()
         group by coalesce(p.batch_id, p.id)
      ) s
  ) else '[]'::jsonb end;
$function$;

CREATE OR REPLACE FUNCTION public.fetch_order_promo_codes(p_order_id text)
 RETURNS TABLE(supplier_group_id text, code text, discount_fcfa integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
    -- Cette fonction sert **deux** lecteurs, et un premier jet ne l'avait
  -- pas vu : le fournisseur qui consulte sa commande, et le client qui
  -- relit quel code il a utilisé sur la sienne. Ne garder que le premier
  -- rendait `null` au second — un test de bout en bout l'a dit aussitôt.
  --
  -- Elle rend un **ensemble de lignes**, pas du jsonb : la garde est donc
  -- un `where` sur l'enveloppe, et non un `case` sur le résultat.
  select ligne.* from (
  select r.supplier_group_id, coalesce(r.code_snapshot, '—'), r.discount_fcfa
      from public.promo_code_redemptions r
      join public.orders o on o.id = r.order_id
     where r.order_id = p_order_id
       and (
         o.client_id = auth.uid()
         or exists (
           select 1 from public.order_supplier_groups g
            where g.id = r.supplier_group_id
              and g.supplier_id = public.operating_supplier_id()
         )
       )
  ) ligne
   where public.supplier_can('orders')
      or public.supplier_can('promotions')
      or exists (
        select 1 from public.orders o
         where o.id = p_order_id and o.client_id = auth.uid()
      );
$function$;

-- ---- le tableau de bord, sans l'argent -----------------------------------

CREATE OR REPLACE FUNCTION public.fetch_supplier_dashboard_stats()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
    -- L'argent ne se délègue pas, pas même en lecture. Un collaborateur voit
  -- ce qui s'est vendu — combien de commandes, combien de vues — jamais le
  -- chiffre d'affaires, ni ce qui a été versé, ni le montant que chaque
  -- article a rapporté.
  --
  -- Les clés sont **retirées** du résultat plutôt que mises à zéro : un
  -- zéro se lit comme une information (« la boutique n'a rien vendu »), une
  -- clé absente ne dit rien. Et le corps du calcul n'est pas récrit — il est
  -- enveloppé, pour ne pas risquer d'en perdre une ligne au passage.
  with brut(j) as (
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
        from produits, groupes, retraits, articles
  )
  select case
    when public.is_supplier_owner() or public.is_staff() then brut.j
    else (
      brut.j
        - 'gross_fcfa'
        - 'gross_last_30_days_fcfa'
        - 'gross_last_7_days_fcfa'
        - 'paid_out_fcfa'
    ) || jsonb_build_object(
      'best_sellers',
      coalesce((
        select jsonb_agg(article - 'amount_fcfa')
          from jsonb_array_elements(brut.j -> 'best_sellers') article
      ), '[]'::jsonb)
    )
  end
    from brut;
$function$;

-- ---- les tables d'argent, fermées en lecture -----------------------------

-- Les demandes de retrait portent des montants et des numéros Mobile Money.
-- Un collaborateur n'a aucune raison de les lire, quelle que soit la
-- permission qu'on lui accorde par ailleurs : l'argent ne se délègue pas.
drop policy if exists "payout_requests_select" on public.payout_requests;
create policy "payout_requests_select" on public.payout_requests
  for select using (
    (supplier_id = public.operating_supplier_id() and public.is_supplier_owner())
    or public.is_admin()
  );

-- Le taux de commission est une donnée de négociation entre la boutique et
-- MTC. Elle regarde le propriétaire, et le staff qui l'a fixée.
drop policy if exists "supplier_finance_settings_select" on public.supplier_finance_settings;
create policy "supplier_finance_settings_select" on public.supplier_finance_settings
  for select using (
    (supplier_id = public.operating_supplier_id() and public.is_supplier_owner())
    or public.is_staff()
  );

-- ---- les utilisations de codes promo --------------------------------------

-- Elles nomment des clients et des montants remisés : c'est le sujet
-- « remises », pas un sujet ouvert à tout le personnel.
drop policy if exists "promo_code_redemptions_visible" on public.promo_code_redemptions;
create policy "promo_code_redemptions_visible" on public.promo_code_redemptions
  for select using (
    client_id = auth.uid()
    or (
      public.supplier_can('promotions')
      and exists (
        select 1 from public.promo_codes c
         where c.id = promo_code_id
           and c.supplier_id = public.operating_supplier_id()
      )
    )
    or public.is_staff()
  );
