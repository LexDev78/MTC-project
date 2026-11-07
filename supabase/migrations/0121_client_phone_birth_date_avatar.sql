-- Le client change son numéro, sa photo et sa date de naissance.
--
-- Même chemin que le nom (`0116`) et l'adresse de contact (`0109`) :
-- `authenticated` n'a aucun droit d'écriture sur `profiles` (`0103`), chaque
-- champ a sa fonction, qui ne touche que la ligne de `auth.uid()` et ne sert
-- qu'aux comptes client. Un livreur ou une boutique a son numéro ailleurs
-- (`couriers.phone_number`, `suppliers.public_phone_numbers`) : le changer ici
-- les ferait diverger.
--
-- Le numéro n'est pas l'identifiant de connexion — c'est le nom d'utilisateur
-- (`username_or_phone`, `pseudoEmail`). Le changer ne touche donc pas à la
-- connexion.

alter table public.profiles
  add column if not exists birth_date date,
  add column if not exists avatar_path text;

-- La borne haute (pas dans le futur) dépend du jour : elle est vérifiée par
-- la fonction, une contrainte ne pouvant pas lire la date courante.
alter table public.profiles
  add constraint profiles_birth_date_plausible
  check (birth_date is null or birth_date >= date '1900-01-01');

-- ---- le numéro --------------------------------------------------------------

-- Rendu sous une seule forme, `+223XXXXXXXX`, quelle que soit la saisie
-- (« 70 12 34 56 », « 0022370123456 », « 223 70 12 34 56 »,
-- « +223 70-12-34-56 »).
--
-- Les commandes en cours suivent : c'est le numéro qu'on appellera pour les
-- livrer, et l'ancien ne répond peut-être plus. Le numéro donné au paiement
-- pour le livreur suit aussi, mais seulement s'il était l'ancien numéro du
-- compte — s'il en différait, c'était un choix (celui d'un proche, d'un
-- bureau) qu'on ne défait pas. Les commandes terminées gardent le leur :
-- personne d'autre que le client ne le voit plus (`0120`).
create or replace function public.set_my_phone_number(p_phone text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_saisi text := regexp_replace(coalesce(p_phone, ''), '[[:space:].()-]', '', 'g');
  v_numero text;
  v_role public.account_role;
  v_ancien text;
begin
  if v_uid is null then
    raise exception 'Connectez-vous pour changer votre numéro.';
  end if;

  select role, phone_number into v_role, v_ancien
    from public.profiles
   where id = v_uid and deleted_at is null
   for update;
  if not found then
    raise exception 'Ce compte n''existe plus.';
  end if;
  if v_role <> 'client' then
    raise exception 'Ce numéro se change depuis l''espace de votre compte.';
  end if;

  if v_saisi !~ '^(\+223|00223|223)?[5-9][0-9]{7}$' then
    raise exception 'Numéro malien invalide (ex : 70 12 34 56).';
  end if;
  v_numero := '+223' || right(v_saisi, 8);

  update public.profiles set phone_number = v_numero where id = v_uid;

  update public.order_contacts c
     set client_phone = v_numero,
         courier_phone = case
           when c.courier_phone is not null
            and right(regexp_replace(c.courier_phone, '[^0-9]', '', 'g'), 8)
              = right(regexp_replace(v_ancien, '[^0-9]', '', 'g'), 8)
           then v_numero
           else c.courier_phone
         end
    from public.orders o
   where o.id = c.order_id
     and o.client_id = v_uid
     and exists (
       select 1 from public.order_supplier_groups g
        where g.order_id = o.id
          and g.status not in ('delivered', 'cancelled')
     );

  return v_numero;
end;
$$;

revoke all on function public.set_my_phone_number(text) from public, anon;
grant execute on function public.set_my_phone_number(text) to authenticated;

-- ---- la date de naissance ----------------------------------------------------

-- `null` la retire. Personne d'autre que le client ne la lit :
-- `profiles_select_own`.
create or replace function public.set_my_birth_date(p_birth_date date)
returns date
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_role public.account_role;
begin
  if v_uid is null then
    raise exception 'Connectez-vous pour indiquer votre date de naissance.';
  end if;

  select role into v_role
    from public.profiles
   where id = v_uid and deleted_at is null;
  if not found then
    raise exception 'Ce compte n''existe plus.';
  end if;
  if v_role <> 'client' then
    raise exception 'La date de naissance ne se renseigne que sur un compte client.';
  end if;

  if p_birth_date > current_date then
    raise exception 'La date de naissance ne peut pas être dans le futur.';
  end if;
  if p_birth_date < date '1900-01-01' then
    raise exception 'La date de naissance doit être postérieure au 1er janvier 1900.';
  end if;

  update public.profiles set birth_date = p_birth_date where id = v_uid;
  return p_birth_date;
end;
$$;

revoke all on function public.set_my_birth_date(date) from public, anon;
grant execute on function public.set_my_birth_date(date) to authenticated;

-- ---- la photo ---------------------------------------------------------------

-- Un bucket privé : la photo n'est montrée qu'à son propriétaire. Une boutique
-- qui écrit à un client ne voit que son nom.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

-- Le dossier de premier niveau est l'identifiant du compte : c'est lui qui
-- borne chacun à ses propres fichiers.
create policy avatars_owner_read on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy avatars_owner_write on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy avatars_owner_update on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy avatars_owner_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- Retient le chemin d'une photo déjà déposée, ou la retire (`null`).
--
-- Le chemin doit être dans le dossier de l'appelant et le fichier exister :
-- sans ça, un compte pourrait pointer vers la photo d'un autre, ou vers rien.
-- L'ancienne photo part dans la file d'effacement (`0088`) : l'application
-- la supprime aussi tout de suite, la file couvre le cas où elle n'y arrive
-- pas.
create or replace function public.set_my_avatar(p_path text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_role public.account_role;
  v_ancien text;
  v_chemin text := nullif(btrim(coalesce(p_path, '')), '');
begin
  if v_uid is null then
    raise exception 'Connectez-vous pour changer votre photo.';
  end if;

  select role, avatar_path into v_role, v_ancien
    from public.profiles
   where id = v_uid and deleted_at is null
   for update;
  if not found then
    raise exception 'Ce compte n''existe plus.';
  end if;
  if v_role <> 'client' then
    raise exception 'La photo de profil ne se change que sur un compte client.';
  end if;

  if v_chemin is not null then
    if v_chemin !~ ('^' || v_uid::text || '/[^/]+$')
       or not exists (
         select 1 from storage.objects
          where bucket_id = 'avatars' and name = v_chemin
       ) then
      raise exception 'Photo introuvable : envoyez-la de nouveau.';
    end if;
  end if;

  update public.profiles set avatar_path = v_chemin where id = v_uid;

  if v_ancien is not null and v_ancien is distinct from v_chemin then
    insert into public.storage_purge_queue (bucket_id, object_path)
    values ('avatars', v_ancien)
    on conflict (bucket_id, object_path) do nothing;
  end if;

  return v_chemin;
end;
$$;

revoke all on function public.set_my_avatar(text) from public, anon;
grant execute on function public.set_my_avatar(text) to authenticated;

notify pgrst, 'reload schema';
