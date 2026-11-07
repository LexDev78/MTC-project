-- Permis et carte grise : pour les voitures, et elles seules.
--
-- `0105` les exigeait de tout véhicule motorisé — moto et tricycle compris.
-- C'est faux sur le terrain : à Bamako l'essentiel de la livraison se fait
-- en moto ou en tricycle (katakata), et réclamer un permis et une carte
-- grise à ces livreurs-là revient à leur fermer l'inscription.
--
-- La règle devient donc : la pièce d'identité pour tous, les papiers du
-- véhicule pour la voiture seulement.
--
-- `CourierVehicleType.requiredDocuments` (Dart) dit la même chose, et un
-- test compare les deux listes pour les cinq moyens de transport — c'est
-- lui qui empêchera les deux copies de diverger après ce changement.
create or replace function public.courier_required_documents(
  p_vehicle_type public.courier_vehicle_type
) returns public.courier_document_type[]
language sql
immutable
set search_path = public
as $$
  select case
    when p_vehicle_type = 'car' then
      array['national_id_front', 'national_id_back',
            'driving_licence', 'vehicle_registration']::public.courier_document_type[]
    else
      array['national_id_front',
            'national_id_back']::public.courier_document_type[]
  end;
$$;
