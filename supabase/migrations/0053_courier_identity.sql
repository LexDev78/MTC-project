-- Le nom et le téléphone du livreur, portés par sa propre fiche.
--
-- Bug constaté sur l'écran de validation du staff : il affichait une erreur
-- PostgREST et ne s'ouvrait pas du tout. La requête joignait `profiles` pour
-- lire l'identité du livreur, et `couriers` référence `profiles` **deux
-- fois** — le livreur (`id`) et l'agent qui statue (`reviewed_by_staff_id`).
-- Jointure ambiguë, requête refusée en bloc (PGRST201).
--
-- Lever l'ambiguïté en nommant la clé aurait suffi à ouvrir l'écran, mais
-- les champs seraient revenus **vides** : `profiles` n'est lisible que par
-- son propriétaire (`profiles_select_own`), donc le staff ne voit pas le
-- profil du livreur qu'il doit valider. Il aurait fallu, en plus, ouvrir
-- `profiles` au staff — c'est-à-dire donner accès au profil de **tout le
-- monde** pour afficher deux champs.
--
-- La fiche porte donc son identité, comme `suppliers` porte `business_name`
-- et `city` plutôt que de les lire ailleurs. Plus de jointure, plus
-- d'ambiguïté, et aucune table ouverte.

alter table public.couriers
  add column if not exists display_name text,
  add column if not exists phone_number text;

-- Reprise des livreurs déjà inscrits.
update public.couriers c
   set display_name = p.display_name,
       phone_number = p.phone_number
  from public.profiles p
 where p.id = c.id
   and (c.display_name is null or c.phone_number is null);

-- Reprend `handle_new_user()` (`0046`) : la branche livreur y recopie
-- maintenant l'identité, prise dans les mêmes métadonnées que `profiles`.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  meta jsonb := new.raw_user_meta_data;
  v_role public.account_role := (meta ->> 'role')::public.account_role;
begin
  insert into public.profiles (id, role, username_or_phone, display_name, phone_number, staff_role)
  values (
    new.id,
    v_role,
    meta ->> 'username_or_phone',
    meta ->> 'display_name',
    meta ->> 'phone_number',
    case when v_role = 'supplier_principal' then (meta ->> 'staff_role')::public.staff_role else null end
  );

  if v_role = 'supplier_tiers' then
    insert into public.suppliers (id, business_name, supplier_type, city, verification_status, legal_type)
    values (
      new.id,
      meta ->> 'business_name',
      'tiers',
      meta ->> 'city',
      'unverified',
      (meta ->> 'legal_type')::public.supplier_legal_type
    );
  elsif v_role = 'livreur' then
    insert into public.couriers (id, status, city, vehicle_label, display_name, phone_number)
    values (
      new.id,
      'pending',
      coalesce(meta ->> 'city', 'Bamako'),
      meta ->> 'vehicle_label',
      meta ->> 'display_name',
      meta ->> 'phone_number'
    );
  end if;

  return new;
end;
$$;

-- Lecture du statut d'un livreur sans session, pour les tests.
create or replace function public.test_fetch_courier_status(p_courier_id uuid)
returns text
language sql
security definer
set search_path = public
as $$
  select status::text from public.couriers where id = p_courier_id;
$$;

revoke all on function public.test_fetch_courier_status(uuid) from public, anon, authenticated;
