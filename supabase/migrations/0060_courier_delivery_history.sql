-- L'historique des courses du livreur, sans les identités.
--
-- Un livreur a besoin de retrouver ce qu'il a fait : combien de courses,
-- quand, pour combien. Il n'a pas besoin de garder, des mois après, le nom
-- et le téléphone d'un client ni l'adresse où il a sonné. Le lui afficher
-- ferait de son app un carnet d'adresses permanent de la clientèle,
-- consultable par quiconque ouvre son téléphone — et récupérable par
-- n'importe quelle app livreur revendue d'occasion.
--
-- Ce n'est pas qu'une question d'écran : la lecture existante
-- (`SupabaseDeliveryDatasource._nestedSelect`) ramène commande, client et
-- fournisseur pour **toutes** les courses du livreur, y compris livrées.
-- D'où une lecture distincte, qui ne sait pas remonter jusqu'à ces champs,
-- plutôt qu'un filtre d'affichage par-dessus les mêmes données.
--
-- Ce qui reste : les villes (le livreur doit reconnaître un trajet), le
-- nombre d'articles, les frais, les horodatages, et la note reçue. Les
-- villes ne désignent personne ; un nom et un numéro, si.

create or replace function public.fetch_courier_delivery_history(
  p_limit integer default 30,
  p_offset integer default 0
) returns table (
  delivery_id text,
  -- Référence courte, pour qu'un livreur puisse citer une course au support
  -- sans passer par un identifiant de 36 caractères.
  reference text,
  status public.delivery_status,
  pickup_city text,
  dropoff_city text,
  item_count integer,
  delivery_fee_fcfa integer,
  accepted_at timestamptz,
  picked_up_at timestamptz,
  delivered_at timestamptz,
  -- La note reçue, côté par côté. `null` quand ce côté n'a pas noté.
  client_stars integer,
  supplier_stars integer
)
language sql
security definer
set search_path = public
as $$
  select
    d.id,
    upper(left(replace(d.id, '-', ''), 6)),
    d.status,
    s.city,
    o.delivery_city,
    coalesce((
      select sum(i.quantity)::integer
        from public.order_items i
       where i.group_id = d.supplier_group_id
    ), 0),
    g.delivery_fee_fcfa,
    d.accepted_at,
    d.picked_up_at,
    d.delivered_at,
    (select r.stars from public.courier_ratings r
      where r.delivery_id = d.id and r.rater_role = 'client'),
    (select r.stars from public.courier_ratings r
      where r.delivery_id = d.id and r.rater_role = 'supplier')
  from public.deliveries d
  join public.orders o on o.id = d.order_id
  join public.order_supplier_groups g on g.id = d.supplier_group_id
  join public.suppliers s on s.id = g.supplier_id
  -- Seules les siennes, et seules celles qui sont finies : une course en
  -- cours s'affiche ailleurs, avec les coordonnées dont le livreur a
  -- justement besoin à ce moment-là.
  where d.courier_id = auth.uid()
    and d.status in ('delivered', 'cancelled')
  order by coalesce(d.delivered_at, d.accepted_at, d.created_at) desc
  limit least(coalesce(p_limit, 30), 100)
 offset greatest(coalesce(p_offset, 0), 0);
$$;

revoke all on function public.fetch_courier_delivery_history(integer, integer) from public, anon;
grant execute on function public.fetch_courier_delivery_history(integer, integer) to authenticated;

-- Le cumul, en une lecture : c'est ce qu'un livreur regarde en premier, et
-- le recomposer côté app obligerait à télécharger tout l'historique pour en
-- faire une somme.
create or replace function public.fetch_courier_stats()
returns table (
  delivered_count integer,
  delivered_fees_fcfa integer,
  month_delivered_count integer,
  month_fees_fcfa integer,
  cancelled_count integer,
  rating_average numeric,
  rating_count integer
)
language sql
security definer
set search_path = public
as $$
  with mine as (
    select d.status, d.delivered_at, g.delivery_fee_fcfa
      from public.deliveries d
      join public.order_supplier_groups g on g.id = d.supplier_group_id
     where d.courier_id = auth.uid()
  )
  select
    count(*) filter (where status = 'delivered')::integer,
    coalesce(sum(delivery_fee_fcfa) filter (where status = 'delivered'), 0)::integer,
    count(*) filter (
      where status = 'delivered'
        and delivered_at >= date_trunc('month', now())
    )::integer,
    coalesce(sum(delivery_fee_fcfa) filter (
      where status = 'delivered'
        and delivered_at >= date_trunc('month', now())
    ), 0)::integer,
    count(*) filter (where status = 'cancelled')::integer,
    (select c.rating_average from public.couriers c where c.id = auth.uid()),
    (select c.rating_count from public.couriers c where c.id = auth.uid())
  from mine;
$$;

revoke all on function public.fetch_courier_stats() from public, anon;
grant execute on function public.fetch_courier_stats() to authenticated;
