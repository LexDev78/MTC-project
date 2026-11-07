-- Retirer un collaborateur ne le supprime plus : son accès est désactivé.
--
-- Jusqu'ici `remove_supplier_collaborator` effaçait la ligne de
-- rattachement. Le collaborateur disparaissait de l'écran de l'équipe, et le
-- reprendre plus tard obligeait le patron à recréer un compte — avec un
-- nouveau nom d'utilisateur, puisque l'ancien restait pris, et un nouveau
-- mot de passe à dicter. Un vendeur saisonnier, un employé en congé : c'est
-- le cas ordinaire, pas l'exception.
--
-- La ligne reste donc, marquée `deactivated_at`. Le patron la voit, et la
-- rétablit d'un geste (`reactivate_supplier_collaborator`).
--
-- ## Pourquoi c'est sûr
--
-- Aucune politique RLS ne lit `supplier_collaborators` directement — vérifié
-- avant d'écrire cette migration. Tous les droits d'un collaborateur passent
-- par deux fonctions : `operating_supplier_id()` (quelle boutique j'opère)
-- et `supplier_can()` (ai-je cette permission). Toutes deux ignorent
-- désormais un rattachement désactivé. Chaque politique, garde et RPC en
-- aval suit donc d'office : un collaborateur retiré n'opère plus aucune
-- boutique et n'a plus aucune permission, exactement comme quand sa ligne
-- était supprimée.
--
-- Il peut en revanche **lire sa propre ligne** (politique
-- `supplier_collaborators_select`, `user_id = auth.uid()`) : c'est ce qui
-- permet à l'app de lui dire, à la connexion, que son accès a été retiré —
-- au lieu de lui afficher un code d'erreur.

alter table public.supplier_collaborators
  add column if not exists deactivated_at timestamp with time zone;

CREATE OR REPLACE FUNCTION public.operating_supplier_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
         -- Ajouté (`0110`) : un collaborateur dont l'accès est retiré garde
         -- sa ligne — le patron le voit encore et peut le rétablir —, mais
         -- n'opère plus aucune boutique.
         and c.deactivated_at is null
    )
  );
$function$;

CREATE OR REPLACE FUNCTION public.supplier_can(p_permission text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  -- Le staff MTC passe aussi : il opère la boutique officielle sans
  -- posséder de ligne `suppliers` à son nom — `operating_supplier_id()`
  -- lui rend un identifiant fixe depuis `0001`. L'oublier le privait
  -- d'écrire sur son propre catalogue, ce qu'un test a dit aussitôt.
  select public.is_staff() or public.is_supplier_owner() or exists (
    select 1 from public.supplier_collaborators c
     where c.user_id = auth.uid()
       and c.deactivated_at is null
       and p_permission = any (c.permissions)
  );
$function$;

CREATE OR REPLACE FUNCTION public.remove_supplier_collaborator(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_supplier_id uuid := public.operating_supplier_id();
begin
  if v_supplier_id is null or not public.is_supplier_owner() then
    raise exception 'Seul le propriétaire de la boutique peut retirer un collaborateur.';
  end if;

  -- Désactiver plutôt que supprimer (`0110`) : la ligne reste, avec ses
  -- permissions, pour que le patron puisse rétablir l'accès d'un geste au
  -- lieu de recréer un compte — et un nouveau mot de passe à dicter.
  update public.supplier_collaborators
     set deactivated_at = now()
   where supplier_id = v_supplier_id
     and user_id = p_user_id
     and deactivated_at is null;

  if not found then
    if exists (
      select 1 from public.supplier_collaborators
       where supplier_id = v_supplier_id and user_id = p_user_id
    ) then
      raise exception 'L''accès de ce collaborateur est déjà retiré.';
    end if;
    raise exception 'Ce collaborateur n''est pas rattaché à votre boutique.';
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.add_supplier_collaborator(p_user_id uuid, p_permissions text[] DEFAULT '{}'::text[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
     set permissions = excluded.permissions,
         -- Rattacher à nouveau un collaborateur retiré lui rend l'accès.
         deactivated_at = null;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fetch_my_collaborators()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(jsonb_agg(jsonb_build_object(
           'user_id', c.user_id,
           'display_name', p.display_name,
           'username_or_phone', p.username_or_phone,
           'phone_number', p.phone_number,
           'permissions', to_jsonb(c.permissions),
           'must_change_password', p.must_change_password,
           'created_at', c.created_at,
           'deactivated_at', c.deactivated_at
         -- Les actifs d'abord : c'est l'équipe du jour. Les accès retirés
         -- suivent, pour pouvoir être rétablis.
         ) order by (c.deactivated_at is not null), p.display_name), '[]'::jsonb)
    from public.supplier_collaborators c
    join public.profiles p on p.id = c.user_id
   where c.supplier_id = public.operating_supplier_id()
     and public.is_supplier_owner();
$function$;

-- Rétablir l'accès d'un collaborateur retiré. Réservé au patron, comme le
-- retrait lui-même.
create or replace function public.reactivate_supplier_collaborator(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supplier_id uuid := public.operating_supplier_id();
begin
  if v_supplier_id is null or not public.is_supplier_owner() then
    raise exception 'Seul le propriétaire de la boutique peut rétablir un collaborateur.';
  end if;

  update public.supplier_collaborators
     set deactivated_at = null
   where supplier_id = v_supplier_id
     and user_id = p_user_id
     and deactivated_at is not null;

  if not found then
    if exists (
      select 1 from public.supplier_collaborators
       where supplier_id = v_supplier_id and user_id = p_user_id
    ) then
      raise exception 'Ce collaborateur a déjà accès à votre boutique.';
    end if;
    raise exception 'Ce collaborateur n''est pas rattaché à votre boutique.';
  end if;
end;
$$;

revoke all on function public.reactivate_supplier_collaborator(uuid) from public, anon;
grant execute on function public.reactivate_supplier_collaborator(uuid) to authenticated;
