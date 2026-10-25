-- Vérifie la migration 0128 (rôles venus d'app_metadata) contre la base
-- locale, sans rien y laisser : tout se passe dans une transaction annulée.
--
--   docker exec -i supabase_db_MTC_project psql -U postgres -d postgres -q \
--     < supabase/snippets/verif_0128.sql
--
-- Dernière ligne attendue : « TOUTES LES VÉRIFICATIONS PASSENT ».
--
-- Les inscriptions sont jouées par des `insert into auth.users`, ce que
-- fait GoTrue : depuis `0128`, `handle_new_user` ne regarde plus qui écrit,
-- seulement ce qui est écrit. Le chemin de l'API d'administration (compte
-- inséré, puis `app_metadata` posé par une mise à jour) est rejoué tel que
-- GoTrue v2.195 le fait. Le passage par la vraie API est dans
-- `verif_0128_api.sh`.
\set ON_ERROR_STOP 1
\o /dev/null
begin;
set local client_min_messages = warning;

create schema verif;
grant usage on schema verif to anon, authenticated;

create function verif.refuse(p_cas text, p_sql text, p_motif text)
returns void language plpgsql as $$
declare
  v_message text;
begin
  begin
    execute p_sql;
  exception when others then
    v_message := sqlerrm;
  end;
  if v_message is null then
    raise exception 'ÉCHEC % : accepté alors qu''il devait être refusé', p_cas;
  end if;
  if v_message not like p_motif then
    raise exception 'ÉCHEC % : refusé, mais pour une autre raison : %', p_cas, v_message;
  end if;
end $$;

-- Une inscription telle que GoTrue l'écrit.
create function verif.inscrire(p_id uuid, p_user jsonb, p_app jsonb default '{"provider":"email","providers":["email"]}')
returns void language sql as $$
  insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token, email_change, email_change_token_new)
  values ('00000000-0000-0000-0000-000000000000', p_id, 'authenticated', 'authenticated',
    (p_user ->> 'username_or_phone') || '@mtc.local', '', now(), now(), now(), p_app, p_user, '', '', '', '');
$$;

-- Se présenter comme PostgREST le ferait, avec les claims d'un vrai jeton.
create function verif.jeton(p_id uuid) returns text language sql as $$
  select jsonb_build_object(
    'sub', p_id, 'role', 'authenticated', 'aal', 'aal1',
    'app_metadata', (select raw_app_meta_data from auth.users where id = p_id)
  )::text;
$$;
grant execute on all functions in schema verif to anon, authenticated;

-- ---- 1. ce que l'inscription publique refuse --------------------------------------------
do $$ begin
  perform verif.refuse('admin par user_metadata',
    $q$select verif.inscrire('a0000000-0000-4000-8000-000000000001',
      '{"role":"supplier_principal","staff_role":"admin","username_or_phone":"v-admin","display_name":"X","phone_number":"+22370000001"}')$q$,
    'Inscription refusée : le rôle « supplier_principal »%');
  perform verif.refuse('staff_role glissé dans un compte client',
    $q$select verif.inscrire('a0000000-0000-4000-8000-000000000002',
      '{"role":"client","staff_role":"admin","username_or_phone":"v-admin2","display_name":"X","phone_number":"+22370000001"}')$q$,
    'Inscription refusée : l''appartenance%');
  perform verif.refuse('collaborateur par user_metadata',
    $q$select verif.inscrire('a0000000-0000-4000-8000-000000000003',
      '{"role":"supplier_tiers","collaborator_of":"b7eb8585-4091-5b6f-83f7-5d70724e97a3","permissions":["products"],"username_or_phone":"v-intrus","display_name":"X","phone_number":"+22370000001","business_name":"B","city":"Bamako","legal_type":"company"}')$q$,
    'Inscription refusée : l''appartenance%');
  perform verif.refuse('rôle inventé',
    $q$select verif.inscrire('a0000000-0000-4000-8000-000000000004',
      '{"role":"admin","username_or_phone":"v-invente","display_name":"X","phone_number":"+22370000001"}')$q$,
    'Inscription refusée : le rôle « admin »%');
end $$;

-- ---- 2. ce qu'elle accepte ---------------------------------------------------------------
select verif.inscrire('a0000000-0000-4000-8000-000000000010',
  '{"role":"client","username_or_phone":"v-client","display_name":"Client","phone_number":"+22370000010"}');
select verif.inscrire('a0000000-0000-4000-8000-000000000011',
  '{"role":"supplier_tiers","username_or_phone":"v-boutique","display_name":"Patron","phone_number":"+22370000011","business_name":"Boutique V","city":"Bamako","legal_type":"individual"}');
select verif.inscrire('a0000000-0000-4000-8000-000000000012',
  '{"role":"livreur","username_or_phone":"v-livreur","display_name":"Livreur","phone_number":"+22370000012","city":"Bamako"}');
select verif.inscrire('a0000000-0000-4000-8000-000000000013',
  '{"username_or_phone":"v-sans-role","display_name":"Sans rôle","phone_number":"+22370000013"}');
do $$ begin
  if (select role from public.profiles where id = 'a0000000-0000-4000-8000-000000000010') <> 'client'
     or (select verification_status from public.suppliers where id = 'a0000000-0000-4000-8000-000000000011') <> 'unverified'
     or (select status from public.couriers where id = 'a0000000-0000-4000-8000-000000000012') <> 'pending'
     or (select role from public.profiles where id = 'a0000000-0000-4000-8000-000000000013') <> 'client'
     or exists (select 1 from public.profiles where id::text like 'a0000000-0000-4000-8000-00000000001%' and staff_role is not null) then
    raise exception 'ÉCHEC : une inscription ordinaire n''a pas donné le compte attendu';
  end if;
end $$;

-- ---- 3. le staff, par app_metadata ---------------------------------------------------------
-- Inséré directement en base (le jeu de démonstration) : app_metadata est là
-- dès l'insertion.
select verif.inscrire('a0000000-0000-4000-8000-000000000020',
  '{"username_or_phone":"v-staff-seed","display_name":"Staff","phone_number":"+22370000020"}',
  '{"provider":"email","providers":["email"],"staff_role":"agent"}');
-- Par l'API d'administration : inséré client, puis app_metadata posé.
select verif.inscrire('a0000000-0000-4000-8000-000000000021',
  '{"username_or_phone":"v-staff-api","display_name":"Staff","phone_number":"+22370000021"}');
update auth.users set raw_app_meta_data = raw_app_meta_data || '{"staff_role":"admin"}'
 where id = 'a0000000-0000-4000-8000-000000000021';
do $$ begin
  if (select (role, staff_role)::text from public.profiles where id = 'a0000000-0000-4000-8000-000000000020') <> '(supplier_principal,agent)'
     or (select (role, staff_role)::text from public.profiles where id = 'a0000000-0000-4000-8000-000000000021') <> '(supplier_principal,admin)' then
    raise exception 'ÉCHEC : app_metadata.staff_role n''a pas fait un membre du staff';
  end if;
  perform verif.refuse('un livreur ne devient pas staff',
    $q$update auth.users set raw_app_meta_data = raw_app_meta_data || '{"staff_role":"admin"}' where id = 'a0000000-0000-4000-8000-000000000012'$q$,
    'Ce compte est déjà livreur%');
  perform verif.refuse('un fournisseur ne devient pas staff',
    $q$update auth.users set raw_app_meta_data = raw_app_meta_data || '{"staff_role":"admin"}' where id = 'a0000000-0000-4000-8000-000000000011'$q$,
    'Ce compte est déjà supplier_tiers%');
  perform verif.refuse('rôle de staff inconnu',
    $q$update auth.users set raw_app_meta_data = raw_app_meta_data || '{"staff_role":"superadmin"}' where id = 'a0000000-0000-4000-8000-000000000010'$q$,
    'Rôle de staff inconnu%');
end $$;
-- Retirer staff_role retire l'accès.
update auth.users set raw_app_meta_data = raw_app_meta_data - 'staff_role'
 where id = 'a0000000-0000-4000-8000-000000000020';
do $$ begin
  if (select (role, staff_role)::text from public.profiles where id = 'a0000000-0000-4000-8000-000000000020') <> '(client,)' then
    raise exception 'ÉCHEC : retirer staff_role n''a pas retiré le rôle';
  end if;
end $$;

-- ---- 4. le collaborateur, par app_metadata ---------------------------------------------------
select verif.inscrire('a0000000-0000-4000-8000-000000000030',
  '{"username_or_phone":"v-vendeur","display_name":"Vendeur","phone_number":"+22370000030"}');
update auth.users set raw_app_meta_data = raw_app_meta_data
  || '{"collaborator_of":"b7eb8585-4091-5b6f-83f7-5d70724e97a3","permissions":["products","orders","admin"],"invited_by":"b7eb8585-4091-5b6f-83f7-5d70724e97a3"}'
 where id = 'a0000000-0000-4000-8000-000000000030';
do $$ begin
  if (select (p.role, p.must_change_password, c.supplier_id, c.permissions, c.created_by)::text
        from public.profiles p join public.supplier_collaborators c on c.user_id = p.id
       where p.id = 'a0000000-0000-4000-8000-000000000030')
     is distinct from '(supplier_tiers,t,b7eb8585-4091-5b6f-83f7-5d70724e97a3,"{orders,products}",b7eb8585-4091-5b6f-83f7-5d70724e97a3)' then
    raise exception 'ÉCHEC : le collaborateur n''est pas rattaché comme prévu (%)',
      (select (p.role, p.must_change_password, c.supplier_id, c.permissions, c.created_by)::text
         from public.profiles p left join public.supplier_collaborators c on c.user_id = p.id
        where p.id = 'a0000000-0000-4000-8000-000000000030');
  end if;
  if exists (select 1 from public.suppliers where id = 'a0000000-0000-4000-8000-000000000030') then
    raise exception 'ÉCHEC : le collaborateur a reçu une boutique à lui';
  end if;
  -- GoTrue réécrit app_metadata pour lui-même : cela ne rattache pas deux fois.
  update auth.users set raw_app_meta_data = raw_app_meta_data || '{"providers":["email","phone"]}'
   where id = 'a0000000-0000-4000-8000-000000000030';
  perform verif.refuse('boutique inexistante',
    $q$update auth.users set raw_app_meta_data = raw_app_meta_data || '{"collaborator_of":"00000000-0000-4000-8000-00000000dead"}' where id = 'a0000000-0000-4000-8000-000000000010'$q$,
    'Boutique introuvable%');
  perform verif.refuse('la boutique MTC ne recrute pas ainsi',
    $q$update auth.users set raw_app_meta_data = raw_app_meta_data || '{"collaborator_of":"3331cbb4-0a65-5f94-9812-fe4270e50fe2"}' where id = 'a0000000-0000-4000-8000-000000000010'$q$,
    'Boutique introuvable%');
  perform verif.refuse('un livreur ne devient pas vendeur',
    $q$update auth.users set raw_app_meta_data = raw_app_meta_data || '{"collaborator_of":"b7eb8585-4091-5b6f-83f7-5d70724e97a3"}' where id = 'a0000000-0000-4000-8000-000000000012'$q$,
    'Seul un compte créé pour la boutique%');
  perform verif.refuse('staff et vendeur à la fois',
    $q$update auth.users set raw_app_meta_data = raw_app_meta_data || '{"collaborator_of":"b7eb8585-4091-5b6f-83f7-5d70724e97a3","staff_role":"agent"}' where id = 'a0000000-0000-4000-8000-000000000010'$q$,
    'Un compte est staff MTC ou collaborateur%');
end $$;

-- ---- 5. un faux administrateur d'avant 0128 n'est plus rien ------------------------------------
-- Tel que la faille le fabriquait : un profil staff, et rien dans app_metadata.
select verif.inscrire('a0000000-0000-4000-8000-000000000040',
  '{"username_or_phone":"v-faux-admin","display_name":"Faux","phone_number":"+22370000040"}');
select set_config('app.trusted_role_provisioning', 'on', true);
update public.profiles set role = 'supplier_principal', staff_role = 'admin'
 where id = 'a0000000-0000-4000-8000-000000000040';
select set_config('app.trusted_role_provisioning', 'off', true);

select verif.jeton('a0000000-0000-4000-8000-000000000040') as faux \gset
select verif.jeton('2358888a-b13d-56f8-858b-a0c63831b512') as admin1 \gset
select verif.jeton('0354c601-5e09-57b6-a23c-affaa5acf0d0') as agent1 \gset
select verif.jeton('a0000000-0000-4000-8000-000000000010') as client \gset
select set_config('verif.faux', :'faux', true), set_config('verif.admin1', :'admin1', true),
       set_config('verif.agent1', :'agent1', true), set_config('verif.client', :'client', true);

set local role authenticated;
select set_config('request.jwt.claims', current_setting('verif.faux'), true);
do $$ begin
  if public.is_staff() or public.is_admin() or public.operating_supplier_id() is not null then
    raise exception 'ÉCHEC : le faux administrateur passe encore pour du staff';
  end if;
  if (select count(*) from public.orders) > 0
     or (select count(*) from public.supplier_kyc) > 0
     or (select count(*) from public.supplier_documents) > 0
     or (select count(*) from public.courier_documents) > 0
     or (select count(*) from public.payout_requests) > 0 then
    raise exception 'ÉCHEC : le faux administrateur lit encore des données du staff';
  end if;
end $$;

-- Les vrais comptes staff, eux, passent toujours.
select set_config('request.jwt.claims', current_setting('verif.admin1'), true);
do $$ begin
  if not public.is_staff() or not public.is_admin()
     or public.operating_supplier_id() <> '3331cbb4-0a65-5f94-9812-fe4270e50fe2'
     or (select count(*) from public.orders) = 0 then
    raise exception 'ÉCHEC : admin1 a perdu ses droits';
  end if;
end $$;
select set_config('request.jwt.claims', current_setting('verif.agent1'), true);
do $$ begin
  if not public.is_staff() or public.is_admin() then
    raise exception 'ÉCHEC : agent1 n''est pas staff, ou se retrouve admin';
  end if;
end $$;
-- Un jeton resté sur l'ancien rôle ne vaut pas plus que le profil.
select set_config('request.jwt.claims',
  jsonb_set(current_setting('verif.agent1')::jsonb, '{app_metadata,staff_role}', '"admin"')::text, true);
do $$ begin
  if public.is_admin() then
    raise exception 'ÉCHEC : un jeton qui dit admin suffit à un profil agent';
  end if;
end $$;

-- ---- 6. personne ne change son rôle lui-même --------------------------------------------------
select set_config('request.jwt.claims', current_setting('verif.client'), true);
do $$ begin
  perform verif.refuse('se nommer admin',
    $q$update public.profiles set role = 'supplier_principal', staff_role = 'admin' where id = 'a0000000-0000-4000-8000-000000000010'$q$,
    'permission denied for table profiles');
  perform verif.refuse('appeler la conversion soi-même',
    $q$select public.apply_account_provisioning('a0000000-0000-4000-8000-000000000010', '{}', '{"staff_role":"admin"}')$q$,
    '%permission denied%');
end $$;
-- Et même une fonction `security definer` qui s'y essaierait bute sur la
-- garde, hors de `apply_account_provisioning`.
reset role;
do $$ begin
  perform verif.refuse('changer le rôle hors de la conversion',
    $q$update public.profiles set role = 'supplier_principal', staff_role = 'admin' where id = 'a0000000-0000-4000-8000-000000000010'$q$,
    'Le rôle d''un compte ne se change pas après coup%');
  if current_setting('app.trusted_role_provisioning', true) = 'on' then
    raise exception 'ÉCHEC : la conversion laisse son laissez-passer ouvert après elle';
  end if;
end $$;
set local role authenticated;

-- ---- 7. un patron ne rattache pas n'importe qui ------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"b7eb8585-4091-5b6f-83f7-5d70724e97a3","role":"authenticated","app_metadata":{}}', true);
do $$ begin
  perform verif.refuse('rattacher un client',
    $q$select public.add_supplier_collaborator('a0000000-0000-4000-8000-000000000010', '{products}')$q$,
    'Ce compte n''a pas été créé pour votre boutique.');
  perform verif.refuse('rattacher un livreur',
    $q$select public.add_supplier_collaborator('a0000000-0000-4000-8000-000000000012', '{products}')$q$,
    'Ce compte n''a pas été créé pour votre boutique.');
  -- Son propre vendeur, oui : le rejouer met à jour ses droits.
  perform public.add_supplier_collaborator('a0000000-0000-4000-8000-000000000030', '{messages}');
  if (select permissions from public.supplier_collaborators where user_id = 'a0000000-0000-4000-8000-000000000030') <> '{messages}' then
    raise exception 'ÉCHEC : le patron ne peut plus mettre à jour son vendeur';
  end if;
end $$;
reset role;

-- ---- 8. les notifications MTC ne partent qu'au vrai staff -------------------------------------
insert into public.device_tokens (user_id, fcm_token, platform)
values ('a0000000-0000-4000-8000-000000000040', 'jeton-faux-admin', 'android'),
       ('2358888a-b13d-56f8-858b-a0c63831b512', 'jeton-admin1', 'android');
do $$ begin
  if exists (select 1 from public.get_device_tokens_for_notification_user('3331cbb4-0a65-5f94-9812-fe4270e50fe2') t where t.fcm_token = 'jeton-faux-admin')
     or not exists (select 1 from public.get_device_tokens_for_notification_user('3331cbb4-0a65-5f94-9812-fe4270e50fe2') t where t.fcm_token = 'jeton-admin1') then
    raise exception 'ÉCHEC : les notifications MTC partent au mauvais monde';
  end if;
end $$;

\o
select 'TOUTES LES VÉRIFICATIONS PASSENT' as resultat;
rollback;
