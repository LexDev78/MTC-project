-- Vérifie la migration 0132 (mot de passe oublié : plafond quotidien,
-- réponses uniformes) contre la base locale, sans rien y laisser : tout se
-- passe dans une transaction annulée, mots de passe et sessions compris, et
-- les e-mails mis en file disparaissent avec elle — rien ne part.
--
--   docker exec -i supabase_db_MTC_project psql -U postgres -d postgres -q \
--     < supabase/snippets/verif_0132.sql
--
-- Dernière ligne attendue : « TOUTES LES VÉRIFICATIONS PASSENT ».
--
-- Remplace `verif_0127.sql`, dont les messages (« Aucun compte ne
-- correspond », « Il vous reste 4 essais », l'adresse masquée) sont
-- précisément ceux que `0132` retire.
\set ON_ERROR_STOP 1
\o /dev/null
begin;
set local client_min_messages = warning;

-- Un vrai service d'envoi branché en local est écarté le temps de l'essai.
delete from vault.secrets where name like 'mail\_%';

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

-- Les e-mails mis en file, et le code du dernier.
create function verif.mails() returns integer language sql
security definer set search_path = public as $$
  select count(*)::integer from net.http_request_queue;
$$;
create function verif.dernier_mail() returns jsonb language sql
security definer set search_path = public as $$
  select convert_from(q.body, 'utf8')::jsonb from net.http_request_queue q order by q.id desc limit 1;
$$;
create function verif.code_recu() returns text language sql as $$
  select substring(verif.dernier_mail() ->> 'Subject' from '([0-9]{6})$');
$$;
-- Ce que le serveur tient, lu hors des droits de l'appelant.
create function verif.garde(p_uid uuid) returns public.password_reset_guard language sql
security definer set search_path = public as $$
  select * from public.password_reset_guard where user_id = p_uid;
$$;
-- Le délai d'une minute entre deux envois, écoulé d'un coup : dans une
-- transaction, `now()` ne bouge pas.
create function verif.minute_passee(p_uid uuid) returns void language sql
security definer set search_path = public as $$
  update public.password_reset_codes set last_sent_at = now() - interval '2 minutes',
         window_started_at = now() - interval '2 hours' where user_id = p_uid;
$$;
create function verif.code_faux(p_code text) returns text language sql as $$
  select case when p_code = '000000' then '111111' else '000000' end;
$$;
grant execute on all functions in schema verif to anon, authenticated;

-- Awa a une adresse vérifiée ; celle de Moussa ne l'a jamais été. admin1 a
-- la sienne, pour la règle du staff.
update public.profiles set contact_email = 'awa@example.com', contact_email_verified_at = now()
 where id = '04060d99-e34d-520e-8b75-631ff4d3c10c';
update public.profiles set contact_email = 'non-verifiee@example.com', contact_email_verified_at = null
 where id = '3355adef-385d-5eee-a565-815c8cf8e4d3';
update public.profiles set contact_email = 'admin@example.com', contact_email_verified_at = now()
 where id = '2358888a-b13d-56f8-858b-a0c63831b512';
insert into auth.sessions (id, user_id, created_at, updated_at)
values ('00000000-0000-4000-8000-0000000000aa', '04060d99-e34d-520e-8b75-631ff4d3c10c', now(), now());
select encrypted_password as ancien_hash from auth.users where id = '04060d99-e34d-520e-8b75-631ff4d3c10c' \gset
select set_config('verif.ancien_hash', :'ancien_hash', true);

-- ---- les droits ----------------------------------------------------------------------
do $$ begin
  if not has_function_privilege('anon', 'public.request_password_reset(text)', 'EXECUTE')
     or not has_function_privilege('anon', 'public.reset_password_with_code(text, text, text)', 'EXECUTE') then
    raise exception 'ÉCHEC : la récupération n''est pas ouverte avant connexion';
  end if;
  if has_table_privilege('anon', 'public.password_reset_guard', 'SELECT')
     or has_table_privilege('authenticated', 'public.password_reset_guard', 'SELECT')
     or has_table_privilege('anon', 'public.password_reset_codes', 'SELECT') then
    raise exception 'ÉCHEC : un compteur de la récupération est lisible';
  end if;
end $$;

set local role anon;
set local request.jwt.claims to '{"role":"anon"}';

-- ---- 1. la même réponse pour tout le monde ----------------------------------------------
do $$
declare
  v_inconnu jsonb := public.request_password_reset('personne-ici');
  v_sans_adresse jsonb;
  v_reel jsonb;
  v_avant integer := verif.mails();
begin
  v_sans_adresse := public.request_password_reset('client2');
  if verif.mails() <> v_avant then
    raise exception 'ÉCHEC : un e-mail est parti pour un compte inconnu ou sans adresse vérifiée';
  end if;
  v_reel := public.request_password_reset('  CLIENT1 ');
  if verif.mails() <> v_avant + 1 then
    raise exception 'ÉCHEC : le code n''est pas parti au compte réel';
  end if;
  if v_inconnu <> v_sans_adresse or v_inconnu <> v_reel then
    raise exception 'ÉCHEC : les réponses se distinguent (%, %, %)', v_inconnu, v_sans_adresse, v_reel;
  end if;
  if v_reel ? 'masked_email' or (v_reel ->> 'resend_after_seconds')::int <> 60 then
    raise exception 'ÉCHEC : la réponse dit plus qu''il ne faut (%)', v_reel;
  end if;
  if verif.dernier_mail() -> 'To' -> 0 ->> 'Email' <> 'awa@example.com' then
    raise exception 'ÉCHEC : e-mail adressé ailleurs (%)', verif.dernier_mail();
  end if;
  perform set_config('verif.code', verif.code_recu(), true);

  -- Redemander tout de suite : même réponse, et rien ne part.
  if public.request_password_reset('awa@example.com') <> v_reel or verif.mails() <> v_avant + 1 then
    raise exception 'ÉCHEC : le délai d''une minute se voit, ou ne tient pas';
  end if;
end $$;

-- ---- 2. le même refus pour tout le monde ------------------------------------------------
do $$
declare
  v_refus jsonb := '{"ok": false, "message": "Code incorrect ou expiré. Vérifiez-le, ou demandez-en un nouveau."}';
  v_faux text := verif.code_faux(current_setting('verif.code'));
begin
  if public.reset_password_with_code('personne-ici', '123456', 'NouveauMdp1') <> v_refus
     or public.reset_password_with_code('client2', '123456', 'NouveauMdp1') <> v_refus
     or public.reset_password_with_code('client1', v_faux, 'NouveauMdp1') <> v_refus
     or public.reset_password_with_code('client1', 'abcdef', 'NouveauMdp1') <> v_refus then
    raise exception 'ÉCHEC : un refus se distingue des autres';
  end if;
  -- Les règles communes du mot de passe passent avant, sans coûter d'essai.
  perform verif.refuse('mot de passe trop court', format('select public.reset_password_with_code(''client1'', %L, ''12345'')', current_setting('verif.code')), '%au moins 6 caractères%');
  perform verif.refuse('mot de passe trop long', format('select public.reset_password_with_code(''client1'', %L, %L)', current_setting('verif.code'), repeat('é', 37)), '%72 caractères%');
end $$;
reset role;
do $$ begin
  if (select attempts from public.password_reset_codes where user_id = '04060d99-e34d-520e-8b75-631ff4d3c10c') <> 2
     or (verif.garde('04060d99-e34d-520e-8b75-631ff4d3c10c')).failures_in_window <> 2 then
    raise exception 'ÉCHEC : les deux essais faux ne sont pas comptés (code %, jour %)',
      (select attempts from public.password_reset_codes where user_id = '04060d99-e34d-520e-8b75-631ff4d3c10c'),
      (verif.garde('04060d99-e34d-520e-8b75-631ff4d3c10c')).failures_in_window;
  end if;
  if (select encrypted_password from auth.users where id = '04060d99-e34d-520e-8b75-631ff4d3c10c') <> current_setting('verif.ancien_hash') then
    raise exception 'ÉCHEC : le mot de passe a changé sans le bon code';
  end if;
end $$;

-- ---- 3. le plafond du jour : dix essais faux, et la récupération se bloque ------------------
set local role anon;
do $$
declare
  i integer;
  v_avant integer;
begin
  -- Deux essais déjà comptés ; trois de plus épuisent ce code.
  for i in 1..3 loop
    perform public.reset_password_with_code('client1', verif.code_faux(current_setting('verif.code')), 'NouveauMdp1');
  end loop;
  -- Un code neuf : le compteur du code repart, celui du jour non.
  perform verif.minute_passee('04060d99-e34d-520e-8b75-631ff4d3c10c');
  perform public.request_password_reset('client1');
  perform set_config('verif.code', verif.code_recu(), true);
  for i in 1..4 loop
    perform public.reset_password_with_code('client1', verif.code_faux(current_setting('verif.code')), 'NouveauMdp1');
  end loop;
  if (verif.garde('04060d99-e34d-520e-8b75-631ff4d3c10c')).locked_until is not null then
    raise exception 'ÉCHEC : bloqué avant le dixième essai';
  end if;
  v_avant := verif.mails();
  perform public.reset_password_with_code('client1', verif.code_faux(current_setting('verif.code')), 'NouveauMdp1');
  if (verif.garde('04060d99-e34d-520e-8b75-631ff4d3c10c')).locked_until is distinct from now() + interval '24 hours' then
    raise exception 'ÉCHEC : le dixième essai ne bloque pas 24 heures (%)', (verif.garde('04060d99-e34d-520e-8b75-631ff4d3c10c')).locked_until;
  end if;
  if verif.mails() <> v_avant + 1 or verif.dernier_mail() ->> 'Subject' <> 'Récupération de votre compte MTC suspendue' then
    raise exception 'ÉCHEC : le titulaire n''est pas prévenu du blocage';
  end if;
  -- Bloqué : le bon code ne passe plus, et aucun code ne part.
  if (public.reset_password_with_code('client1', current_setting('verif.code'), 'NouveauMdp1') ->> 'ok')::boolean then
    raise exception 'ÉCHEC : le bon code passe pendant le blocage';
  end if;
  perform verif.minute_passee('04060d99-e34d-520e-8b75-631ff4d3c10c');
  v_avant := verif.mails();
  perform public.request_password_reset('client1');
  if verif.mails() <> v_avant then
    raise exception 'ÉCHEC : un code part pendant le blocage';
  end if;
end $$;

-- ---- 4. la récidive double le blocage ------------------------------------------------------
reset role;
update public.password_reset_guard set locked_until = now() - interval '1 second'
 where user_id = '04060d99-e34d-520e-8b75-631ff4d3c10c';
set local role anon;
do $$
declare
  i integer;
begin
  for i in 1..2 loop
    perform verif.minute_passee('04060d99-e34d-520e-8b75-631ff4d3c10c');
    perform public.request_password_reset('client1');
    perform set_config('verif.code', verif.code_recu(), true);
    for j in 1..5 loop
      perform public.reset_password_with_code('client1', verif.code_faux(current_setting('verif.code')), 'NouveauMdp1');
    end loop;
  end loop;
  if (verif.garde('04060d99-e34d-520e-8b75-631ff4d3c10c')).locked_until is distinct from now() + interval '48 hours'
     or (verif.garde('04060d99-e34d-520e-8b75-631ff4d3c10c')).lockouts <> 2 then
    raise exception 'ÉCHEC : le second blocage ne dure pas 48 heures (%)', verif.garde('04060d99-e34d-520e-8b75-631ff4d3c10c');
  end if;
end $$;

-- ---- 5. le bon code rend l'accès, et efface les compteurs --------------------------------------
reset role;
update public.password_reset_guard set locked_until = now() - interval '1 second'
 where user_id = '04060d99-e34d-520e-8b75-631ff4d3c10c';
set local role anon;
do $$
declare
  v jsonb;
begin
  perform verif.minute_passee('04060d99-e34d-520e-8b75-631ff4d3c10c');
  perform public.request_password_reset('client1');
  v := public.reset_password_with_code('awa@example.com', verif.code_recu(), 'NouveauMdp1');
  if not (v ->> 'ok')::boolean or v ->> 'username' <> 'client1' then
    raise exception 'ÉCHEC : le bon code refusé (%)', v;
  end if;
end $$;
reset role;
do $$ begin
  if (select encrypted_password from auth.users where id = '04060d99-e34d-520e-8b75-631ff4d3c10c') = current_setting('verif.ancien_hash')
     or exists (select 1 from auth.sessions where user_id = '04060d99-e34d-520e-8b75-631ff4d3c10c')
     or (verif.garde('04060d99-e34d-520e-8b75-631ff4d3c10c')).user_id is not null then
    raise exception 'ÉCHEC : mot de passe inchangé, session restée ouverte, ou compteurs gardés';
  end if;
end $$;

-- ---- 6. le staff : 10 caractères, dits seulement à qui tient le code ----------------------------
set local role anon;
do $$
declare
  v jsonb;
  v_code text;
begin
  perform public.request_password_reset('admin1');
  v_code := verif.code_recu();
  -- Un inconnu qui propose un mot de passe court ne l'apprend pas.
  if public.reset_password_with_code('admin1', verif.code_faux(v_code), 'Court123') ->> 'message'
     <> 'Code incorrect ou expiré. Vérifiez-le, ou demandez-en un nouveau.' then
    raise exception 'ÉCHEC : la règle du staff se lit sans le code';
  end if;
  perform verif.refuse('staff, 8 caractères', format('select public.reset_password_with_code(''admin1'', %L, ''Court123'')', v_code),
    'Le mot de passe d''un compte MTC doit compter au moins 10 caractères.');
  -- Le code n'est pas perdu pour autant.
  v := public.reset_password_with_code('admin1', v_code, 'Bamako2026Staff');
  if not (v ->> 'ok')::boolean then
    raise exception 'ÉCHEC : le staff ne peut plus changer son mot de passe (%)', v;
  end if;
end $$;
reset role;

\o
select 'TOUTES LES VÉRIFICATIONS PASSENT' as resultat;
rollback;
