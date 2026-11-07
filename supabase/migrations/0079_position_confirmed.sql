-- Savoir si une position a été réellement pointée, ou seulement héritée.
--
-- Les comptes créés avant le sélecteur de carte portent les coordonnées du
-- **centre de leur ville**, pas de leur adresse. Rien ne distingue ces
-- valeurs d'une position choisie, et c'est ce qui donne l'impression que la
-- carte se trompe : le livreur va au centre-ville parce que c'est
-- littéralement ce qui est enregistré.
--
-- La date de confirmation est posée par un trigger, et non par l'app : le
-- moment où une position devient fiable est exactement celui où quelqu'un
-- écrit des coordonnées différentes. Aucun écran n'a à s'en souvenir, et un
-- futur chemin d'écriture en bénéficie sans rien faire.
--
-- Les lignes existantes restent à `null` : c'est tout l'intérêt. Elles
-- déclenchent le bandeau qui demande de vérifier le point sur la carte.
alter table public.suppliers
  add column if not exists position_confirmed_at timestamptz;
alter table public.addresses
  add column if not exists position_confirmed_at timestamptz;

grant select (position_confirmed_at) on public.suppliers to anon, authenticated;
grant select (position_confirmed_at) on public.addresses to authenticated;

create or replace function public.stamp_position_confirmed()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_lat double precision;
  v_lng double precision;
  v_old_lat double precision;
  v_old_lng double precision;
begin
  if tg_table_name = 'suppliers' then
    v_lat := new.address_latitude;
    v_lng := new.address_longitude;
    v_old_lat := case when tg_op = 'UPDATE' then old.address_latitude end;
    v_old_lng := case when tg_op = 'UPDATE' then old.address_longitude end;
  else
    v_lat := new.latitude;
    v_lng := new.longitude;
    v_old_lat := case when tg_op = 'UPDATE' then old.latitude end;
    v_old_lng := case when tg_op = 'UPDATE' then old.longitude end;
  end if;

  if v_lat is null or v_lng is null then
    return new;
  end if;
  -- Seul un **déplacement** confirme. Réenregistrer sa fiche sans toucher au
  -- point ne doit pas faire passer pour vérifiée une position héritée.
  if tg_op = 'UPDATE'
     and v_lat is not distinct from v_old_lat
     and v_lng is not distinct from v_old_lng then
    return new;
  end if;

  new.position_confirmed_at := now();
  return new;
end;
$$;

create trigger suppliers_stamp_position
  before insert or update of address_latitude, address_longitude
  on public.suppliers
  for each row execute function public.stamp_position_confirmed();

create trigger addresses_stamp_position
  before insert or update of latitude, longitude
  on public.addresses
  for each row execute function public.stamp_position_confirmed();
