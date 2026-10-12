-- Pas de course sans point de retrait.
--
-- Constaté sur le parcours livreur : la feuille de route affichait le nom du
-- fournisseur et sa ville, rien d'autre. Les colonnes sont bien lues, mais
-- vides — un livreur ne peut pas aller chercher un colis à « Bamako ».
--
-- Et ce n'est pas qu'un défaut d'affichage : l'attribution « au plus proche »
-- (`offer_delivery_to_next_courier`, `0046`) classe les livreurs par distance
-- au fournisseur. Sans coordonnées, ce tri ne trie rien et la course part au
-- premier venu, quelle que soit sa distance réelle.
--
-- La vérification se fait **au moment où le fournisseur confie la commande à
-- MTC**, pas à l'insertion du groupe :
--
--  * c'est l'instant où la donnée devient nécessaire, et la seule action
--    bloquée est celle du fournisseur qui peut y remédier — l'adresse se
--    saisit depuis sa boutique (`SupplierAccountScreen`) ;
--  * bloquer à la commande punirait le client pour une négligence du
--    fournisseur, après qu'il a payé ;
--  * c'est côté serveur, donc infranchissable depuis l'app : la même
--    tentative faite directement contre l'API est refusée pareil.

create or replace function public.create_delivery_for_group()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delivery_id text;
  v_has_pickup_point boolean;
begin
  if new.delivery_mode <> 'mtc_delivery' then return new; end if;
  if new.status <> 'in_transit' or old.status = 'in_transit' then return new; end if;

  select s.full_address is not null
         and trim(s.full_address) <> ''
         and s.address_latitude is not null
         and s.address_longitude is not null
    into v_has_pickup_point
    from public.suppliers s
   where s.id = new.supplier_id;

  if not coalesce(v_has_pickup_point, false) then
    raise exception 'Renseignez l''adresse de retrait de votre boutique avant de confier une commande à la livraison MTC.';
  end if;

  if exists (select 1 from public.deliveries where supplier_group_id = new.id) then
    return new;
  end if;

  insert into public.deliveries (order_id, supplier_group_id)
  values (new.order_id, new.id)
  returning id into v_delivery_id;

  perform public.offer_delivery_to_next_courier(v_delivery_id);
  return new;
end;
$$;

-- ----------------------------------------------------------------------------
-- Adresses de retrait du jeu de démonstration.
-- ----------------------------------------------------------------------------
-- Les fournisseurs seedés n'en avaient aucune : la démo ne montrait donc pas
-- ce que le livreur voit réellement, et la garde ci-dessus aurait bloqué tout
-- essai de bout en bout.
--
-- Les coordonnées sont celles du centre de la ville, exactement comme ce que
-- produit `SupplierAccountController.save` pour un vrai fournisseur (l'app ne
-- géocode pas une adresse, elle en déduit la ville). Un décor fidèle à la
-- production, donc, et pas plus précis qu'elle.
create or replace function public.test_seed_supplier_pickup_points()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.suppliers s
     set full_address = case s.city
           when 'Bamako' then 'Quartier du Fleuve, Avenue Modibo Keïta'
           when 'Sikasso' then 'Quartier Wayerma, Route de Bougouni'
           when 'Ségou' then 'Quartier Angoulême, Route de Markala'
           when 'Mopti' then 'Quartier Komoguel, Route de Sévaré'
           when 'Kayes' then 'Quartier Légal-Ségou, Avenue du Fleuve'
           when 'Koutiala' then 'Quartier Kaniko, Route de Sikasso'
           else 'Centre-ville'
         end,
         address_latitude = case s.city
           when 'Bamako' then 12.6392
           when 'Sikasso' then 11.3167
           when 'Ségou' then 13.4317
           when 'Mopti' then 14.4843
           when 'Kayes' then 14.4469
           when 'Koutiala' then 12.3912
           else 12.6392
         end,
         address_longitude = case s.city
           when 'Bamako' then -8.0029
           when 'Sikasso' then -5.6667
           when 'Ségou' then -6.2157
           when 'Mopti' then -4.1824
           when 'Kayes' then -11.4443
           when 'Koutiala' then -5.4642
           else -8.0029
         end
   where s.full_address is null or trim(s.full_address) = '';

  -- Un numéro public par boutique : le livreur qui ne trouve pas l'adresse
  -- appelle, c'est la première chose qu'il fait. Le champ était lu par la
  -- feuille de route mais vide partout.
  update public.suppliers s
     set public_phone_numbers = array[p.phone_number]
    from public.profiles p
   where p.id = s.id
     and coalesce(array_length(s.public_phone_numbers, 1), 0) = 0;
end;
$$;

revoke all on function public.test_seed_supplier_pickup_points() from public, anon, authenticated;

-- Pendant du helper ci-dessus, pour les tests : remet un fournisseur dans
-- l'état « sans point de retrait », que le seed ne produit plus.
create or replace function public.test_clear_supplier_pickup_point(p_supplier_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.suppliers
     set full_address = null, address_latitude = null, address_longitude = null
   where id = p_supplier_id;
end;
$$;

revoke all on function public.test_clear_supplier_pickup_point(uuid) from public, anon, authenticated;
