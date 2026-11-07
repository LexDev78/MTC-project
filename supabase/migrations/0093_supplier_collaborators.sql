-- Une boutique, plusieurs personnes.
--
-- Jusqu'ici un compte fournisseur **était** une personne : `suppliers.id`
-- vaut l'identifiant du compte, et tout le contrôle d'accès en découle par
-- `operating_supplier_id()`, qui rend simplement `auth.uid()`. Le patron
-- d'une boutique qui emploie deux vendeurs n'avait qu'un choix : leur
-- donner son mot de passe.
--
-- Ce fichier défait ce raccourci sans toucher à une seule policy existante.
-- `operating_supplier_id()` apprend à répondre pour un collaborateur, et
-- les quelque quarante règles qui s'appuient dessus suivent d'elles-mêmes.
--
-- ## Ce qui ne se délègue pas
--
-- Étendre cette fonction donnerait **tout** au collaborateur, y compris
-- demander un retrait d'argent et supprimer le compte. On re-verrouille
-- donc les chemins sensibles avec `is_supplier_owner()` :
--
--   * les demandes de retrait — un employé ne vide pas la caisse ;
--   * le dossier de vérification — il engage l'identité du patron ;
--   * la suppression du compte ;
--   * la gestion des collaborateurs elle-même, sans quoi le premier invité
--     pourrait en inviter d'autres, ou évincer celui qui l'a fait entrer.
--
-- ## Le reste est donné à la carte
--
-- Produits, commandes, remises, vitrine, messages, avis : chacun est une
-- permission que le patron accorde ou retire. Un vendeur au comptoir n'a
-- pas besoin de changer les prix ; celui qui tient la page a besoin de la
-- vitrine et de rien d'autre.

create table public.supplier_collaborators (
  supplier_id uuid not null references public.suppliers (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,

  -- Les permissions accordées, parmi celles listées ci-dessous. Un tableau
  -- et non une colonne par droit : en ajouter un plus tard ne doit pas
  -- demander une migration de schéma sur une table que chaque requête
  -- RLS consulte.
  permissions text[] not null default '{}',

  created_at timestamptz not null default now(),
  created_by uuid references public.profiles (id) on delete set null,

  primary key (supplier_id, user_id),

  -- Un collaborateur ne peut travailler que pour une boutique. Deux
  -- rattachements rendraient `operating_supplier_id()` ambigu, et elle
  -- répondrait au hasard.
  unique (user_id),

  constraint permissions_connues check (
    permissions <@ array[
      'products', 'orders', 'promotions', 'storefront', 'messages', 'reviews'
    ]::text[]
  )
);

create index supplier_collaborators_supplier_idx
  on public.supplier_collaborators (supplier_id);

alter table public.supplier_collaborators enable row level security;

-- Lecture : le patron voit son équipe, et chacun voit son propre
-- rattachement — un collaborateur doit pouvoir savoir pour qui il travaille
-- et ce qu'on lui a accordé.
create policy "supplier_collaborators_select" on public.supplier_collaborators
  for select using (
    user_id = auth.uid()
    or supplier_id = auth.uid()
    or public.is_staff()
  );

-- Aucune policy d'écriture : tout passe par les RPC ci-dessous, qui
-- vérifient que l'appelant est bien le **propriétaire** et non un
-- collaborateur à qui l'on aurait étendu les droits.
grant select on public.supplier_collaborators to authenticated;
grant select, insert, update, delete on public.supplier_collaborators to service_role;

-- ---- qui est propriétaire, qui est collaborateur -------------------------

-- Le propriétaire est celui qui possède la ligne `suppliers`. C'est déjà
-- vrai aujourd'hui ; on le nomme pour pouvoir s'y référer.
create or replace function public.is_supplier_owner()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.suppliers s
     where s.id = auth.uid() and s.deleted_at is null
  );
$$;

revoke all on function public.is_supplier_owner() from public, anon;
grant execute on function public.is_supplier_owner() to authenticated;

-- Reprend `0001` en ajoutant une troisième branche. L'ordre compte : un
-- propriétaire reste propriétaire même s'il figurait par erreur dans une
-- table de collaboration.
create or replace function public.operating_supplier_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    case (select role from public.profiles where id = auth.uid())
      when 'supplier_tiers' then (
        select s.id from public.suppliers s where s.id = auth.uid()
      )
      when 'supplier_principal' then '3331cbb4-0a65-5f94-9812-fe4270e50fe2'::uuid
      else null
    end,
    -- Pas de boutique à soi : peut-être travaille-t-on pour celle d'un
    -- autre.
    (
      select c.supplier_id from public.supplier_collaborators c
       where c.user_id = auth.uid()
    )
  );
$$;

-- Vrai si l'appelant a le droit demandé sur la boutique qu'il opère.
--
-- Le propriétaire a tout, sans qu'on ait à lui accorder quoi que ce soit :
-- lui demander de se donner des permissions sur sa propre boutique serait
-- une cérémonie vide, et un oubli le bloquerait chez lui.
create or replace function public.supplier_can(p_permission text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  -- Le staff MTC passe aussi : il opère la boutique officielle sans
  -- posséder de ligne `suppliers` à son nom — `operating_supplier_id()`
  -- lui rend un identifiant fixe depuis `0001`. L'oublier le privait
  -- d'écrire sur son propre catalogue, ce qu'un test a dit aussitôt.
  select public.is_staff() or public.is_supplier_owner() or exists (
    select 1 from public.supplier_collaborators c
     where c.user_id = auth.uid()
       and p_permission = any (c.permissions)
  );
$$;

revoke all on function public.supplier_can(text) from public, anon;
grant execute on function public.supplier_can(text) to authenticated;

-- ---- ce qui ne se délègue pas --------------------------------------------

-- L'argent. `operating_supplier_id()` répondant désormais pour un
-- collaborateur, cette policy l'autoriserait à demander un virement vers
-- son propre numéro.
drop policy if exists "payout_requests_insert_own" on public.payout_requests;
create policy "payout_requests_insert_own" on public.payout_requests
  for insert with check (
    supplier_id = public.operating_supplier_id()
    and public.is_supplier_owner()
  );

-- Le dossier de vérification engage l'identité du patron : personne d'autre
-- ne le soumet en son nom.
create or replace function public.submit_supplier_kyc()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supplier_id uuid := public.operating_supplier_id();
  v_status public.kyc_review_status;
begin
  if v_supplier_id is null then
    raise exception 'Réservé à un compte fournisseur.';
  end if;
  -- La seule ligne ajoutée à `0075`. Le reste en est la copie exacte :
  -- une fonction qu'on remplace se reprend, elle ne se récrit pas de
  -- mémoire — un premier jet y avait inventé un statut `pending` qui
  -- n'existe pas dans l'énumération, et neuf tests l'ont dit.
  if not public.is_supplier_owner() then
    raise exception 'Seul le propriétaire du compte peut soumettre le dossier.';
  end if;

  select status into v_status
    from public.supplier_kyc where supplier_id = v_supplier_id;
  if v_status is null then
    raise exception 'Aucun dossier à soumettre.';
  end if;
  -- Un dossier déjà soumis ou en cours d'examen ne se resoumet pas : cela
  -- remettrait le compteur à zéro dans la file du staff.
  if v_status not in ('draft', 'rejected') then
    raise exception 'Ce dossier est déjà soumis.';
  end if;

  update public.supplier_kyc
     set status = 'submitted',
         submitted_at = now(),
         rejection_reason = null
   where supplier_id = v_supplier_id;
end;
$$;

revoke all on function public.submit_supplier_kyc() from public, anon;
grant execute on function public.submit_supplier_kyc() to authenticated;

-- ---- gérer l'équipe -------------------------------------------------------

-- Rattache un compte déjà créé à la boutique de l'appelant.
--
-- Le compte lui-même naît ailleurs : une fonction edge le crée avec la clé
-- de service, parce qu'une session cliente ne peut pas en inscrire une
-- autre sans se déconnecter elle-même.
create or replace function public.add_supplier_collaborator(
  p_user_id uuid,
  p_permissions text[] default '{}'
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supplier_id uuid := public.operating_supplier_id();
begin
  if v_supplier_id is null or not public.is_supplier_owner() then
    raise exception 'Seul le propriétaire de la boutique peut ajouter un collaborateur.';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'Vous êtes déjà le propriétaire de cette boutique.';
  end if;
  if exists (select 1 from public.suppliers s where s.id = p_user_id) then
    raise exception 'Ce compte possède déjà sa propre boutique.';
  end if;

  insert into public.supplier_collaborators
    (supplier_id, user_id, permissions, created_by)
  values (v_supplier_id, p_user_id, coalesce(p_permissions, '{}'), auth.uid())
  on conflict (supplier_id, user_id) do update
     set permissions = excluded.permissions;
end;
$$;

revoke all on function public.add_supplier_collaborator(uuid, text[]) from public, anon;
grant execute on function public.add_supplier_collaborator(uuid, text[])
  to authenticated, service_role;

create or replace function public.set_collaborator_permissions(
  p_user_id uuid,
  p_permissions text[]
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supplier_id uuid := public.operating_supplier_id();
begin
  if v_supplier_id is null or not public.is_supplier_owner() then
    raise exception 'Seul le propriétaire de la boutique peut modifier les accès.';
  end if;

  update public.supplier_collaborators
     set permissions = coalesce(p_permissions, '{}')
   where supplier_id = v_supplier_id and user_id = p_user_id;

  if not found then
    raise exception 'Ce collaborateur n''est pas rattaché à votre boutique.';
  end if;
end;
$$;

revoke all on function public.set_collaborator_permissions(uuid, text[])
  from public, anon;
grant execute on function public.set_collaborator_permissions(uuid, text[])
  to authenticated;

-- Retire l'accès. Le compte continue d'exister — il porte peut-être des
-- messages envoyés et des commandes traitées, et le supprimer effacerait
-- l'auteur de gestes qui ont eu lieu.
create or replace function public.remove_supplier_collaborator(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supplier_id uuid := public.operating_supplier_id();
begin
  if v_supplier_id is null or not public.is_supplier_owner() then
    raise exception 'Seul le propriétaire de la boutique peut retirer un collaborateur.';
  end if;

  delete from public.supplier_collaborators
   where supplier_id = v_supplier_id and user_id = p_user_id;

  if not found then
    raise exception 'Ce collaborateur n''est pas rattaché à votre boutique.';
  end if;
end;
$$;

revoke all on function public.remove_supplier_collaborator(uuid) from public, anon;
grant execute on function public.remove_supplier_collaborator(uuid) to authenticated;

-- L'équipe, telle que l'écran la montre.
create or replace function public.fetch_my_collaborators()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'user_id', c.user_id,
           'display_name', p.display_name,
           'username_or_phone', p.username_or_phone,
           'phone_number', p.phone_number,
           'permissions', to_jsonb(c.permissions),
           'created_at', c.created_at
         ) order by p.display_name), '[]'::jsonb)
    from public.supplier_collaborators c
    join public.profiles p on p.id = c.user_id
   where c.supplier_id = public.operating_supplier_id()
     and public.is_supplier_owner();
$$;

revoke all on function public.fetch_my_collaborators() from public, anon;
grant execute on function public.fetch_my_collaborators() to authenticated;

-- ---- la création du compte collaborateur ---------------------------------

-- Reprend `handle_new_user()` (`0053`) : un compte créé **pour** une
-- boutique ne crée pas de boutique à lui.
--
-- Sans cette branche, inscrire un collaborateur avec le rôle
-- `supplier_tiers` lui ouvrirait sa propre boutique vide, et
-- `operating_supplier_id()` le renverrait chez lui plutôt que chez son
-- patron — le rattachement serait là, et sans effet.
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
  insert into public.profiles (id, role, username_or_phone, display_name, phone_number, staff_role)
  values (
    new.id,
    v_role,
    meta ->> 'username_or_phone',
    meta ->> 'display_name',
    meta ->> 'phone_number',
    case when v_role = 'supplier_principal' then (meta ->> 'staff_role')::public.staff_role else null end
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
