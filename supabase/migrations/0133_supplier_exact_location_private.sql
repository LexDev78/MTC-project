-- L'adresse exacte d'une boutique n'est plus publique.
--
-- ===========================================================================
-- Ce que l'audit a relevé
-- ===========================================================================
--
-- `suppliers_select_public` (`using (deleted_at is null)`) ouvrait toute la
-- ligne à tout le monde, sans connexion : `full_address`,
-- `address_latitude`, `address_longitude` de chaque vendeur — vérifié ou
-- non, société ou particulier. Pour un vendeur particulier, c'est souvent son
-- domicile, pointé au mètre près sur la carte (`0079`). Une donnée
-- personnelle au sens de la loi malienne, que l'APDP regarde.
--
-- ===========================================================================
-- Ce qui change
-- ===========================================================================
--
-- Le public voit la ville (et les zones de livraison, les horaires, les
-- numéros que la boutique publie elle-même). L'adresse exacte ne se lit
-- plus que par deux chemins :
--
--   * la boutique elle-même, pour la tenir à jour (`fetch_my_shop_location`) ;
--   * le livreur MTC à qui la course est proposée ou confiée, tant qu'elle
--     n'est pas livrée (`pickup_point(deliveries)`), et le staff.
--
-- Le moyen : un droit par colonne. La ligne reste lisible — les politiques
-- qui consultent `suppliers` (`products_select_public` regarde
-- `deleted_at`) continuent de marcher —, mais `anon` et `authenticated` ne
-- peuvent plus lire ces trois colonnes. Les fonctions du serveur, elles,
-- s'exécutent sous leur propriétaire et les lisent comme avant (frais de
-- livraison, livreur le plus proche, garde du point de retrait `0050`).
--
-- Deux conséquences, à connaître pour la suite :
--
--   * `select *` sur `suppliers` échoue désormais pour une session : l'app
--     lit la vue `supplier_storefronts`, qui ne porte que les colonnes
--     publiques ;
--   * une colonne ajoutée plus tard à `suppliers` n'est lisible par
--     personne tant qu'on ne l'accorde pas ici (`grant select (…)`) **et**
--     qu'on ne l'ajoute pas à la vue. C'est voulu : rien ne devient public
--     par défaut.

revoke select on public.suppliers from anon, authenticated;
grant select (
  id, business_name, supplier_type, city, rating_average, rating_count,
  product_count, verification_status, legal_type, description, banner_url,
  public_phone_numbers, delivery_zones, opening_hours_label, is_open,
  deleted_at, position_confirmed_at
) on public.suppliers to anon, authenticated;

-- `security_invoker` : la vue lit avec les droits de qui l'interroge, donc
-- sous la même politique que la table (une boutique supprimée n'y figure
-- pas).
create or replace view public.supplier_storefronts
  with (security_invoker = true) as
  select id, business_name, supplier_type, city, rating_average, rating_count,
         product_count, verification_status, legal_type, description, banner_url,
         public_phone_numbers, delivery_zones, opening_hours_label, is_open,
         deleted_at, position_confirmed_at
    from public.suppliers;

grant select on public.supplier_storefronts to anon, authenticated;

comment on view public.supplier_storefronts is
  'La fiche publique d''une boutique, sans son adresse exacte (0133). '
  'Toute lecture de boutique par l''app passe par ici.';

-- Le compteur de la vitrine (`0123`), pour la vue. Celui de la table ne
-- s'appelle plus depuis une session : PostgREST lui passe la ligne entière,
-- et la ligne entière contient désormais des colonnes qu'on ne lit pas.
create or replace function public.listed_product_count(s public.supplier_storefronts)
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

grant execute on function public.listed_product_count(public.supplier_storefronts) to anon, authenticated;

-- ---- la boutique, chez elle ----------------------------------------------------------

-- L'adresse de retrait de la boutique que l'on opère, pour l'écran qui la
-- tient à jour. Même droit que pour la modifier : la vitrine.
create or replace function public.fetch_my_shop_location()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select case when public.supplier_can('storefront') then jsonb_build_object(
           'full_address', s.full_address,
           'latitude', s.address_latitude,
           'longitude', s.address_longitude,
           'position_confirmed_at', s.position_confirmed_at
         ) end
    from public.suppliers s
   where s.id = public.operating_supplier_id();
$$;

revoke all on function public.fetch_my_shop_location() from public, anon;
grant execute on function public.fetch_my_shop_location() to authenticated;

-- ---- le livreur, pendant la course ----------------------------------------------------

-- Champ calculé de `deliveries` : où prendre le colis. Rendu au livreur à
-- qui la course est proposée (pour juger du trajet avant d'accepter) ou
-- confiée, jusqu'à la remise ; à la boutique concernée ; au staff. Rien au
-- client, rien une fois la course close — même règle que les coordonnées
-- du client (`0120`).
create or replace function public.pickup_point(d public.deliveries)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_strip_nulls(jsonb_build_object(
           'full_address', s.full_address,
           'latitude', s.address_latitude,
           'longitude', s.address_longitude
         ))
    from public.order_supplier_groups g
    join public.suppliers s on s.id = g.supplier_id
   where g.id = d.supplier_group_id
     and (
       public.is_staff()
       or g.supplier_id = public.operating_supplier_id()
       or (
         d.status in ('offered', 'accepted', 'picked_up')
         and (d.courier_id = auth.uid() or d.offered_to_courier_id = auth.uid())
       )
     );
$$;

revoke all on function public.pickup_point(public.deliveries) from public, anon;
grant execute on function public.pickup_point(public.deliveries) to authenticated;

notify pgrst, 'reload schema';
