-- Vérifie la migration 0135 (le staff exige une session confirmée par un
-- code, `aal2`) contre la base locale, sans rien y laisser : tout se passe
-- dans une transaction annulée — y compris l'exigence, rallumée le temps de
-- l'essai alors que le jeu de démonstration l'éteint.
--
--   docker exec -i supabase_db_MTC_project psql -U postgres -d postgres -q \
--     < supabase/snippets/verif_0135.sql
--
-- Dernière ligne attendue : « TOUTES LES VÉRIFICATIONS PASSENT ».
\set ON_ERROR_STOP 1
\o /dev/null
begin;
set local client_min_messages = warning;

create schema verif;
grant usage on schema verif to anon, authenticated;
create function verif.jeton(p_id uuid, p_aal text) returns text language sql as $$
  select jsonb_build_object('sub', p_id, 'role', 'authenticated', 'aal', p_aal,
    'app_metadata', (select raw_app_meta_data from auth.users where id = p_id))::text;
$$;
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
grant execute on all functions in schema verif to anon, authenticated;

select verif.jeton('2358888a-b13d-56f8-858b-a0c63831b512', 'aal1') as admin_aal1 \gset
select verif.jeton('2358888a-b13d-56f8-858b-a0c63831b512', 'aal2') as admin_aal2 \gset
select verif.jeton('0354c601-5e09-57b6-a23c-affaa5acf0d0', 'aal1') as agent_aal1 \gset
select set_config('verif.admin_aal1', :'admin_aal1', true), set_config('verif.admin_aal2', :'admin_aal2', true),
       set_config('verif.agent_aal1', :'agent_aal1', true);

-- ---- 1. sans réglage, la double authentification est exigée ------------------------------
delete from public.app_settings where key = 'staff_mfa_required';
do $$ begin
  if not public.staff_mfa_required() then
    raise exception 'ÉCHEC : sans réglage, la double authentification n''est pas exigée';
  end if;
end $$;

-- ---- 2. le mot de passe seul n'ouvre rien -------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', current_setting('verif.admin_aal1'), true);
do $$ begin
  if public.is_staff() or public.is_admin() or public.operating_supplier_id() is not null then
    raise exception 'ÉCHEC : une session aal1 passe pour du staff';
  end if;
  if (select count(*) from public.orders) > 0
     or (select count(*) from public.supplier_kyc) > 0
     or (select count(*) from public.payout_requests) > 0 then
    raise exception 'ÉCHEC : une session aal1 lit les données du staff';
  end if;
  perform verif.refuse('marquer payé sans code', $q$select public.mark_order_paid('peu-importe')$q$, 'Réservé au staff MTC.');
  -- L'app peut demander s'il faut le code.
  if not public.staff_mfa_required() then
    raise exception 'ÉCHEC : l''app ne peut pas savoir qu''un code est exigé';
  end if;
end $$;
select set_config('request.jwt.claims', current_setting('verif.agent_aal1'), true);
do $$ begin
  if public.is_staff() then
    raise exception 'ÉCHEC : un agent aal1 passe pour du staff';
  end if;
end $$;

-- ---- 3. le code confirmé, tout revient --------------------------------------------------------
select set_config('request.jwt.claims', current_setting('verif.admin_aal2'), true);
do $$ begin
  if not public.is_staff() or not public.is_admin()
     or public.operating_supplier_id() <> '3331cbb4-0a65-5f94-9812-fe4270e50fe2'
     or (select count(*) from public.orders) = 0 then
    raise exception 'ÉCHEC : une session aal2 n''a pas les droits du staff';
  end if;
end $$;

-- ---- 4. le réglage, et qui peut le toucher ------------------------------------------------------
do $$ begin
  perform verif.refuse('lire les réglages', 'select * from public.app_settings', '%permission denied%');
  perform verif.refuse('éteindre l''exigence soi-même',
    $q$insert into public.app_settings (key, value) values ('staff_mfa_required', 'false')$q$, '%permission denied%');
end $$;
reset role;
set local role anon;
do $$ begin
  perform verif.refuse('anon demande le réglage', 'select public.staff_mfa_required()', '%permission denied%');
end $$;
reset role;

-- L'exploitant l'éteint (le jeu de démonstration local le fait) : aal1 suffit.
insert into public.app_settings (key, value) values ('staff_mfa_required', 'false'::jsonb);
set local role authenticated;
select set_config('request.jwt.claims', current_setting('verif.admin_aal1'), true);
do $$ begin
  if not public.is_admin() then
    raise exception 'ÉCHEC : l''exigence éteinte, l''admin aal1 n''a plus ses droits';
  end if;
end $$;
reset role;

\o
select 'TOUTES LES VÉRIFICATIONS PASSENT' as resultat;
rollback;
