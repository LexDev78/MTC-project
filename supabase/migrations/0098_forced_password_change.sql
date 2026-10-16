-- Un mot de passe que le patron ne connaît pas longtemps.
--
-- `0093` faisait saisir le mot de passe au propriétaire, qui le remettait à
-- son employé. Deux défauts, et le second est le vrai :
--
--   * le patron connaît le mot de passe de son vendeur, indéfiniment. Tout
--     ce que fait ce compte porte le nom du vendeur, mais n'importe qui
--     ayant vu la fiche peut s'y connecter — y compris longtemps après son
--     départ ;
--   * et le patron **choisit** ce mot de passe. Il prendra le même pour les
--     trois vendeurs, ou celui de la boutique, ou son propre mot de passe.
--
-- Désormais le serveur en engendre un, à usage unique : il s'affiche une
-- fois au patron, qui le dicte, et le collaborateur doit le remplacer à sa
-- première connexion avant d'aller où que ce soit.

alter table public.profiles
  add column if not exists must_change_password boolean not null default false;

-- Reprend `handle_new_user()` telle qu'elle vit après `0093`, en posant le
-- drapeau pour les seuls comptes créés *pour* une boutique. Un fournisseur
-- qui s'inscrit lui-même a choisi son mot de passe : rien à lui imposer.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  meta jsonb := new.raw_user_meta_data;
  v_role public.account_role := (meta ->> 'role')::public.account_role;
  v_collaborator_of uuid := nullif(meta ->> 'collaborator_of', '')::uuid;
begin
  insert into public.profiles (
    id, role, username_or_phone, display_name, phone_number, staff_role,
    must_change_password
  )
  values (
    new.id,
    v_role,
    meta ->> 'username_or_phone',
    meta ->> 'display_name',
    meta ->> 'phone_number',
    case when v_role = 'supplier_principal' then (meta ->> 'staff_role')::public.staff_role else null end,
    v_collaborator_of is not null
  );

  if v_collaborator_of is not null then
    insert into public.supplier_collaborators (supplier_id, user_id, permissions)
    values (
      v_collaborator_of,
      new.id,
      coalesce(
        array(select jsonb_array_elements_text(meta -> 'permissions')),
        '{}'
      )
    );
  elsif v_role = 'supplier_tiers' then
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

-- Lève le drapeau, une fois le mot de passe réellement changé.
--
-- Le changement lui-même passe par `auth.updateUser` côté client — c'est
-- le seul chemin qui sache hacher un mot de passe. Cette fonction ne fait
-- que constater ; elle ne peut pas vérifier que l'appel a eu lieu, et c'est
-- acceptable : le pire qu'un collaborateur puisse faire est de lever le
-- drapeau en gardant le mot de passe qu'on lui a dicté — exactement ce qui
-- se passerait s'il le ressaisissait à l'identique.
create or replace function public.mark_password_changed()
returns void
language sql
security definer
set search_path = public
as $$
  update public.profiles
     set must_change_password = false
   where id = auth.uid();
$$;

revoke all on function public.mark_password_changed() from public, anon;
grant execute on function public.mark_password_changed() to authenticated;

-- Le patron peut remettre le drapeau : un vendeur qui a perdu son mot de
-- passe reçoit un nouveau code à usage unique.
create or replace function public.reset_collaborator_password_flag(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supplier_id uuid := public.operating_supplier_id();
begin
  if v_supplier_id is null or not public.is_supplier_owner() then
    raise exception 'Seul le propriétaire de la boutique peut faire cela.';
  end if;
  if not exists (
    select 1 from public.supplier_collaborators c
     where c.supplier_id = v_supplier_id and c.user_id = p_user_id
  ) then
    raise exception 'Ce collaborateur n''est pas rattaché à votre boutique.';
  end if;

  update public.profiles set must_change_password = true where id = p_user_id;
end;
$$;

revoke all on function public.reset_collaborator_password_flag(uuid) from public, anon;
grant execute on function public.reset_collaborator_password_flag(uuid) to authenticated;
