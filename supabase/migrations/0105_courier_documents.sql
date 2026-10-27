-- Le livreur dépose ses pièces, et MTC les examine.
--
-- Jusqu'ici l'agent validait une inscription sur un nom, un téléphone et une
-- ville — `courier_review_queue_screen.dart` le disait lui-même : « un
-- livreur n'a pas encore de pièces à examiner ». Or c'est la personne à qui
-- l'on confie la marchandise d'un fournisseur et l'argent d'un paiement à la
-- livraison. Son dossier prend donc la même forme que celui d'un
-- fournisseur : des pièces déposées dans un bucket privé, une soumission qui
-- gèle le dossier, une décision qui le tranche.
--
-- Ce qui diffère du fournisseur, et pourquoi :
--
--  * Pas de table « dossier » séparée. Un fournisseur a un `supplier_kyc`
--    parce qu'il porte une forme juridique, un RCCM, un NIF, une adresse de
--    siège. Un livreur n'a rien de tout cela : sa fiche `couriers` **est**
--    son dossier, et il suffit d'y ajouter la date de soumission.
--
--  * Pas de délégation. Un fournisseur peut avoir des collaborateurs, d'où
--    `operating_supplier_id()` partout. Un livreur est une personne : ses
--    politiques se lisent sur `auth.uid()`, directement. (C'est précisément
--    la confusion entre les deux qui avait ouvert le dossier KYC du patron à
--    ses employés — `0104`.)
--
--  * Les pièces exigées dépendent du moyen de transport. Exiger un permis et
--    une carte grise de tout le monde interdirait l'inscription aux livreurs
--    à vélo et à pied, qui sont une part réelle de la livraison à Bamako.
--    D'où un type de véhicule **structuré** : la règle devient calculable au
--    lieu d'être devinée depuis le texte libre `vehicle_label` (« Moto »,
--    « Djakarta rouge », « moto 125 »…).

-- ---------------------------------------------------------------------------
-- 1. Le moyen de transport, en valeurs closes.
-- ---------------------------------------------------------------------------

do $$
begin
  if not exists (select 1 from pg_type where typname = 'courier_vehicle_type') then
    create type public.courier_vehicle_type as enum (
      'on_foot', 'bicycle', 'motorcycle', 'tricycle', 'car'
    );
  end if;
end $$;

-- `vehicle_label` reste : le type dit la règle (« moto »), le libellé dit
-- l'objet (« Djakarta rouge »), et c'est le libellé que le client reconnaît
-- à sa porte.
alter table public.couriers
  add column if not exists vehicle_type public.courier_vehicle_type,
  add column if not exists documents_submitted_at timestamp with time zone;

comment on column public.couriers.documents_submitted_at is
  'Date de dépôt du dossier. Nul = pièces pas encore soumises : le livreur '
  'n''apparaît pas dans la file du staff, et aucune décision ne le concerne.';

-- ---------------------------------------------------------------------------
-- 2. Les pièces.
-- ---------------------------------------------------------------------------

do $$
begin
  if not exists (select 1 from pg_type where typname = 'courier_document_type') then
    create type public.courier_document_type as enum (
      'national_id_front',   -- carte NINA, recto
      'national_id_back',    -- carte NINA, verso
      'driving_licence',     -- permis de conduire
      'vehicle_registration',-- carte grise
      'insurance'            -- attestation d'assurance
    );
  end if;
end $$;

create table if not exists public.courier_documents (
  id text primary key,
  courier_id uuid not null references public.couriers(id) on delete cascade,
  type public.courier_document_type not null,
  file_path text not null,
  uploaded_at timestamp with time zone not null default now(),
  -- Une pièce par type : remplacer sa photo d'identité ne doit pas en
  -- empiler deux, l'agent ne saurait pas laquelle fait foi.
  unique (courier_id, type)
);

create index if not exists courier_documents_courier_idx
  on public.courier_documents (courier_id);

alter table public.courier_documents enable row level security;

grant select, insert, update, delete on public.courier_documents to authenticated;

-- Lecture : le livreur et le staff. Personne d'autre — ni un fournisseur,
-- ni un client, même s'ils ont une course en commun avec lui.
drop policy if exists courier_documents_select_self_or_staff on public.courier_documents;
create policy courier_documents_select_self_or_staff on public.courier_documents
  for select
  using (courier_id = auth.uid() or public.is_staff());

-- Écriture : le livreur, et seulement tant que son dossier n'est pas entre
-- les mains de l'agent. Un dossier qu'on peut modifier pendant son examen
-- n'est pas examinable — l'agent validerait des pièces qui ont changé depuis
-- qu'il les a ouvertes.
drop policy if exists courier_documents_write_own_draft on public.courier_documents;
create policy courier_documents_write_own_draft on public.courier_documents
  for insert
  with check (
    courier_id = auth.uid()
    and exists (
      select 1 from public.couriers c
       where c.id = auth.uid()
         and c.documents_submitted_at is null
         and c.status <> 'approved'
    )
  );

drop policy if exists courier_documents_update_own_draft on public.courier_documents;
create policy courier_documents_update_own_draft on public.courier_documents
  for update
  using (
    courier_id = auth.uid()
    and exists (
      select 1 from public.couriers c
       where c.id = auth.uid()
         and c.documents_submitted_at is null
         and c.status <> 'approved'
    )
  )
  with check (courier_id = auth.uid());

drop policy if exists courier_documents_delete_own_draft on public.courier_documents;
create policy courier_documents_delete_own_draft on public.courier_documents
  for delete
  using (
    courier_id = auth.uid()
    and exists (
      select 1 from public.couriers c
       where c.id = auth.uid()
         and c.documents_submitted_at is null
         and c.status <> 'approved'
    )
  );

-- ---------------------------------------------------------------------------
-- 3. Le bucket privé.
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit)
values ('courier-documents', 'courier-documents', false, 10485760)
on conflict (id) do nothing;

-- Le dossier de premier niveau est l'identifiant du livreur : c'est ce
-- découpage qui empêche de lire le dossier du voisin, exactement comme pour
-- `kyc-documents`.
drop policy if exists courier_documents_files_read on storage.objects;
create policy courier_documents_files_read on storage.objects
  for select
  using (
    bucket_id = 'courier-documents'
    and ((storage.foldername(name))[1] = (auth.uid())::text or public.is_staff())
  );

drop policy if exists courier_documents_files_write on storage.objects;
create policy courier_documents_files_write on storage.objects
  for insert
  with check (
    bucket_id = 'courier-documents'
    and (storage.foldername(name))[1] = (auth.uid())::text
  );

drop policy if exists courier_documents_files_manage on storage.objects;
create policy courier_documents_files_manage on storage.objects
  for update
  using (
    bucket_id = 'courier-documents'
    and (storage.foldername(name))[1] = (auth.uid())::text
  )
  with check (
    bucket_id = 'courier-documents'
    and (storage.foldername(name))[1] = (auth.uid())::text
  );

drop policy if exists courier_documents_files_delete on storage.objects;
create policy courier_documents_files_delete on storage.objects
  for delete
  using (
    bucket_id = 'courier-documents'
    and (storage.foldername(name))[1] = (auth.uid())::text
  );

-- ---------------------------------------------------------------------------
-- 4. Les pièces exigées, calculées en un seul endroit.
-- ---------------------------------------------------------------------------

-- Appelée par la soumission **et** lisible par l'application : l'écran doit
-- afficher les mêmes cases que celles que le serveur contrôlera, sinon le
-- livreur remplit un formulaire complet et se fait refuser.
create or replace function public.courier_required_documents(
  p_vehicle_type public.courier_vehicle_type
) returns public.courier_document_type[]
language sql
immutable
set search_path = public
as $$
  select case
    when p_vehicle_type in ('motorcycle', 'tricycle', 'car') then
      array['national_id_front', 'national_id_back',
            'driving_licence', 'vehicle_registration']::public.courier_document_type[]
    else
      array['national_id_front',
            'national_id_back']::public.courier_document_type[]
  end;
$$;

grant execute on function public.courier_required_documents(public.courier_vehicle_type)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Soumettre.
-- ---------------------------------------------------------------------------

create or replace function public.submit_courier_documents(
  p_vehicle_type text,
  p_vehicle_label text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status public.courier_status;
  v_submitted timestamp with time zone;
  v_type public.courier_vehicle_type := p_vehicle_type::public.courier_vehicle_type;
  v_required public.courier_document_type[];
  v_missing public.courier_document_type[];
begin
  select status, documents_submitted_at into v_status, v_submitted
    from public.couriers where id = auth.uid();
  if v_status is null then
    raise exception 'Réservé à un compte livreur.';
  end if;
  if v_status = 'approved' then
    raise exception 'Votre inscription est déjà validée.';
  end if;
  if v_status = 'suspended' then
    raise exception 'Votre compte est suspendu : contactez MTC.';
  end if;
  -- Même règle que `submit_supplier_kyc` : resoumettre pendant l'examen
  -- remettrait le compteur à zéro dans la file du staff.
  if v_submitted is not null then
    raise exception 'Votre dossier est déjà déposé et en cours d''examen.';
  end if;

  v_required := public.courier_required_documents(v_type);

  select array_agg(t) into v_missing
    from unnest(v_required) as t
   where not exists (
     select 1 from public.courier_documents d
      where d.courier_id = auth.uid() and d.type = t
   );

  if v_missing is not null then
    raise exception 'Pièces manquantes : %.', array_to_string(v_missing, ', ');
  end if;

  update public.couriers
     set vehicle_type = v_type,
         vehicle_label = coalesce(nullif(btrim(coalesce(p_vehicle_label, '')), ''),
                                  vehicle_label),
         documents_submitted_at = now(),
         -- Un dossier redéposé après un refus repart en attente, et le motif
         -- du refus précédent ne doit plus s'afficher comme s'il était
         -- toujours d'actualité.
         status = 'pending',
         rejection_reason = null
   where id = auth.uid();
end;
$$;

revoke all on function public.submit_courier_documents(text, text) from public, anon;
grant execute on function public.submit_courier_documents(text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Décider — reprise de la définition **vivante** de `review_courier`
--    (`0055`), à laquelle on ajoute deux règles et rien d'autre.
-- ---------------------------------------------------------------------------

create or replace function public.review_courier(
  p_courier_id uuid,
  p_approve boolean,
  p_reason text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_submitted timestamp with time zone;
begin
  if not public.is_staff() then
    raise exception 'Réservé au staff MTC.';
  end if;
  if not p_approve and coalesce(trim(p_reason), '') = '' then
    raise exception 'Un refus doit être motivé.';
  end if;

  -- Ajout : on ne valide pas un livreur dont on n'a rien vu. Sans cela,
  -- l'ancien écran — un nom, un téléphone, une ville — resterait un chemin
  -- d'approbation parallèle, et les pièces ne serviraient à rien.
  select documents_submitted_at into v_submitted
    from public.couriers where id = p_courier_id;
  if not found then
    raise exception 'Livreur introuvable : %', p_courier_id;
  end if;
  if p_approve and v_submitted is null then
    raise exception 'Ce livreur n''a pas encore déposé ses pièces.';
  end if;

  update public.couriers
     set status = (
           case when p_approve then 'approved' else 'rejected' end
         )::public.courier_status,
         rejection_reason = case when p_approve then null else p_reason end,
         reviewed_at = now(),
         reviewed_by_staff_id = auth.uid(),
         -- Ajout : un refus rend la main au livreur. Il doit pouvoir
         -- corriger la pièce illisible et redéposer — ce que la politique
         -- d'écriture n'autorise que si le dossier n'est plus déposé.
         documents_submitted_at = case when p_approve then documents_submitted_at
                                       else null end
   where id = p_courier_id;

  insert into public.notifications (id, user_id, type, title, body, reference_id)
  values (
    gen_random_uuid()::text,
    p_courier_id,
    'kyc_decision',
    case when p_approve then 'Inscription validée' else 'Inscription refusée' end,
    case
      when p_approve then 'Vous pouvez prendre des courses dès maintenant.'
      else p_reason
    end,
    p_courier_id::text
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Le livreur ne décide pas de son propre statut.
-- ---------------------------------------------------------------------------

-- Vérifié avant d'écrire ce garde, et le résultat contredit ce qu'on
-- pourrait croire : sur `couriers`, `authenticated` ne peut écrire que
-- `is_online` et les trois colonnes de position. Le livreur **ne pouvait
-- donc pas** se valider lui-même — le droit de colonne l'en empêchait déjà.
--
--   select string_agg(column_name, ', ') from information_schema.column_privileges
--    where table_name='couriers' and privilege_type='UPDATE'
--      and grantee='authenticated';
--   -- is_online, last_latitude, last_longitude, last_position_at
--
-- Ce déclencheur n'est donc pas un correctif, c'est un filet. Il existe
-- parce que `suppliers` avait, lui, un droit d'écriture sur **toute** la
-- table : le jour où quelqu'un ajoute `grant update on couriers to
-- authenticated` pour un nouveau champ, le statut et les colonnes de
-- décision ne s'ouvriront pas en silence avec lui. C'est exactement le
-- scénario qui a permis au fournisseur de se décerner son badge (`0103`).
create or replace function public.guard_courier_decision_columns()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_user not in ('anon', 'authenticated') then
    return new;
  end if;
  if public.is_staff() then
    return new;
  end if;

  if new.status is distinct from old.status then
    raise exception 'Votre statut est décidé par MTC.';
  end if;
  if new.documents_submitted_at is distinct from old.documents_submitted_at then
    raise exception 'Le dépôt du dossier passe par submit_courier_documents().';
  end if;
  if new.reviewed_at is distinct from old.reviewed_at
     or new.reviewed_by_staff_id is distinct from old.reviewed_by_staff_id
     or new.rejection_reason is distinct from old.rejection_reason then
    raise exception 'Les colonnes de décision ne s''écrivent pas à la main.';
  end if;
  if new.rating_average is distinct from old.rating_average
     or new.rating_count is distinct from old.rating_count then
    raise exception 'La note d''un livreur se calcule à partir de ses courses.';
  end if;
  return new;
end;
$$;

drop trigger if exists couriers_guard_decision on public.couriers;
create trigger couriers_guard_decision
  before update on public.couriers
  for each row execute function public.guard_courier_decision_columns();

-- ---------------------------------------------------------------------------
-- 8. Le jeu de démonstration : un dossier réellement déposé.
-- ---------------------------------------------------------------------------

-- Sans cela la file du staff est vide par construction, et les deux tests qui
-- l'exercent n'ont plus rien à examiner. Reprend `test_seed_couriers`
-- (`0047`) en y ajoutant les pièces de Fanta Cissé, qui livre en tricycle —
-- donc un véhicule motorisé, donc les quatre pièces exigées. C'est le cas le
-- plus complet, celui qu'on veut voir à l'écran.
--
-- Les chemins pointent vers des fichiers qui n'existent pas dans le bucket :
-- l'écran du staff affichera « Pièce illisible ou introuvable » à leur place.
-- C'est volontaire — le semis ne peut pas créer d'objets de stockage
-- (Supabase interdit l'écriture directe dans `storage.objects` depuis SQL), et
-- ce repli-là est précisément ce qu'on veut voir fonctionner.
create or replace function public.test_seed_couriers()
returns void
language plpgsql
security definer
-- `extensions` en plus de `public` : `crypt`/`gen_salt` (pgcrypto) y vivent
-- dans Supabase. Reprise telle quelle de `0047` — un en-tête se recopie, il
-- ne se réécrit pas de mémoire : ce `search_path` oublié a fait échouer la
-- première version de cette migration sur « function gen_salt(unknown) does
-- not exist ».
set search_path = public, extensions
as $$
begin
  delete from auth.users where id in (
    'f1c4e8a2-0000-5000-9000-000000000001',
    'f1c4e8a2-0000-5000-9000-000000000002'
  );

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token, email_change, email_change_token_new
  ) values
    (
      '00000000-0000-0000-0000-000000000000',
      'f1c4e8a2-0000-5000-9000-000000000001', 'authenticated', 'authenticated',
      'livreur1@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"livreur","username_or_phone":"livreur1","display_name":"Oumar Sidibé","phone_number":"+22378000001","city":"Bamako","vehicle_label":"Moto"}',
      '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      'f1c4e8a2-0000-5000-9000-000000000002', 'authenticated', 'authenticated',
      'livreur2@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"livreur","username_or_phone":"livreur2","display_name":"Fanta Cissé","phone_number":"+22378000002","city":"Bamako","vehicle_label":"Tricycle"}',
      '', '', '', ''
    );

  insert into auth.identities (
    id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  )
  select
    gen_random_uuid(), u.id::text, u.id,
    jsonb_build_object('sub', u.id::text, 'email', u.email),
    'email', now(), now(), now()
  from auth.users u
  where u.id in (
    'f1c4e8a2-0000-5000-9000-000000000001',
    'f1c4e8a2-0000-5000-9000-000000000002'
  );

  -- `handle_new_user()` vient de créer les deux fiches en `pending` ; seule
  -- la première est validée, la seconde reste en attente exprès.
  update public.couriers
     set status = 'approved', reviewed_at = now(),
         vehicle_type = 'motorcycle',
         documents_submitted_at = now() - interval '3 days'
   where id = 'f1c4e8a2-0000-5000-9000-000000000001';

  -- Le dossier en attente d'examen : quatre pièces, déposé hier.
  update public.couriers
     set vehicle_type = 'tricycle',
         documents_submitted_at = now() - interval '1 day'
   where id = 'f1c4e8a2-0000-5000-9000-000000000002';

  insert into public.courier_documents (id, courier_id, type, file_path)
  values
    ('cd-livreur2-nina-recto', 'f1c4e8a2-0000-5000-9000-000000000002',
     'national_id_front', 'f1c4e8a2-0000-5000-9000-000000000002/nina-recto.jpg'),
    ('cd-livreur2-nina-verso', 'f1c4e8a2-0000-5000-9000-000000000002',
     'national_id_back', 'f1c4e8a2-0000-5000-9000-000000000002/nina-verso.jpg'),
    ('cd-livreur2-permis', 'f1c4e8a2-0000-5000-9000-000000000002',
     'driving_licence', 'f1c4e8a2-0000-5000-9000-000000000002/permis.jpg'),
    ('cd-livreur2-grise', 'f1c4e8a2-0000-5000-9000-000000000002',
     'vehicle_registration', 'f1c4e8a2-0000-5000-9000-000000000002/carte-grise.jpg')
  on conflict (courier_id, type) do nothing;
end;
$$;

revoke all on function public.test_seed_couriers() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 9. Remettre un dossier à zéro, pour les tests.
-- ---------------------------------------------------------------------------

-- Un dossier déposé est gelé — c'est tout l'intérêt —, donc un test qui veut
-- repartir d'un livreur fraîchement inscrit ne peut pas le défaire lui-même.
-- Révoquée pour `anon` et `authenticated` comme les autres helpers `test_` :
-- l'audit a vérifié qu'aucun n'est atteignable depuis une session.
create or replace function public.test_reset_courier_dossier(p_courier_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.courier_documents where courier_id = p_courier_id;
  update public.couriers
     set documents_submitted_at = null,
         vehicle_type = null,
         rejection_reason = null,
         status = 'pending'
   where id = p_courier_id;
end;
$$;

revoke all on function public.test_reset_courier_dossier(uuid)
  from public, anon, authenticated;
-- Explicite, et non laissé aux privilèges par défaut : les helpers `test_`
-- plus anciens ont hérité d'un `service_role=X` à leur création, celui-ci ne
-- l'a pas eu, et six tests ont échoué sur « permission denied for function ».
-- Un droit dont dépend le harnais se lit mieux écrit qu'hérité.
grant execute on function public.test_reset_courier_dossier(uuid) to service_role;
