-- **Remplacé par `verif_0132.sql`** : depuis `0132`, la récupération ne dit
-- plus « Aucun compte ne correspond », ni l'adresse masquée, ni les essais
-- restants — ce que ce fichier vérifiait. Gardé pour l'historique.
--
-- Vérifie la migration 0127 (mot de passe oublié) contre la base locale,
-- sans rien y laisser : tout se passe dans une transaction annulée, mots de
-- passe et sessions compris, et les e-mails mis en file disparaissent avec
-- elle — rien ne part.
--
--   docker exec -i supabase_db_MTC_project psql -U postgres -d postgres -q \
--     < supabase/snippets/verif_0127.sql
--
-- Dernière ligne attendue : « TOUTES LES VÉRIFICATIONS PASSENT ».
--
-- Joué comme le serait l'app avant connexion : en `anon`. S'appuie sur Awa
-- (client1) et Moussa (client2).
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

-- Le dernier e-mail mis en file, et le code qu'il porte.
create function verif.dernier_mail() returns jsonb language sql
security definer set search_path = public as $$
  select convert_from(q.body, 'utf8')::jsonb from net.http_request_queue q order by q.id desc limit 1;
$$;
create function verif.code_recu() returns text language sql as $$
  select substring(verif.dernier_mail() ->> 'Subject' from '([0-9]{6})$');
$$;
grant execute on all functions in schema verif to anon, authenticated;

-- Awa a une adresse vérifiée ; celle de Moussa ne l'a jamais été, comme
-- celles d'avant `0124`. Awa a une session ouverte ailleurs, qui devra être
-- fermée.
update public.profiles set contact_email = 'awa@example.com', contact_email_verified_at = now()
 where id = '04060d99-e34d-520e-8b75-631ff4d3c10c';
update public.profiles set contact_email = 'non-verifiee@example.com', contact_email_verified_at = null
 where id = '3355adef-385d-5eee-a565-815c8cf8e4d3';
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
  if has_function_privilege('anon', 'public.password_reset_account(text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.mail_html(text, text, text, text)', 'EXECUTE')
     or has_table_privilege('anon', 'public.password_reset_codes', 'SELECT')
     or has_table_privilege('authenticated', 'public.password_reset_codes', 'SELECT') then
    raise exception 'ÉCHEC : un outil interne de la récupération est ouvert';
  end if;
end $$;

set local role anon;
set local request.jwt.claims to '{"role":"anon"}';

-- ---- ce qui ne part pas -------------------------------------------------------------------
do $$ begin
  perform verif.refuse('compte inconnu', 'select public.request_password_reset(''personne'')', 'Aucun compte ne correspond à cet identifiant.');
  perform verif.refuse('sans adresse vérifiée', 'select public.request_password_reset(''client2'')', '%pas d''adresse e-mail vérifiée%');
  perform verif.refuse('adresse non vérifiée comme identifiant', 'select public.request_password_reset(''non-verifiee@example.com'')', 'Aucun compte ne correspond à cet identifiant.');
  perform verif.refuse('rien en attente', 'select public.reset_password_with_code(''client1'', ''123456'', ''NouveauMdp1'')', 'Aucun code en attente : demandez-en un.');
  perform verif.refuse('lire les codes', 'select * from public.password_reset_codes', '%permission denied%');
end $$;

-- ---- le code part à l'adresse vérifiée, avec l'identifiant -------------------------------
do $$
declare
  v jsonb := public.request_password_reset('  CLIENT1 ');
  v_mail jsonb := verif.dernier_mail();
  v_code text := verif.code_recu();
begin
  if v ->> 'masked_email' <> 'aw•••@example.com' or (v ->> 'resend_after_seconds')::int <> 60 then
    raise exception 'ÉCHEC : réponse (%)', v;
  end if;
  if (select array_agg(k order by k) from jsonb_object_keys(v) k)
     <> array['expires_at', 'masked_email', 'resend_after_seconds'] then
    raise exception 'ÉCHEC : la réponse dit plus qu''il ne faut (%)', v;
  end if;
  if v_mail -> 'To' -> 0 ->> 'Email' <> 'awa@example.com' then
    raise exception 'ÉCHEC : e-mail adressé ailleurs (%)', v_mail;
  end if;
  if v_code is null or position(v_code in v_mail ->> 'Text') = 0 or position(v_code in v_mail ->> 'HTML') = 0
     or position('« client1 »' in v_mail ->> 'Text') = 0 then
    raise exception 'ÉCHEC : code ou identifiant absent de l''e-mail (%)', v_mail;
  end if;
  perform set_config('verif.code', v_code, true);
  -- Par l'adresse e-mail, c'est le même compte : le délai d'envoi le dit.
  perform verif.refuse('même compte, par l''adresse', 'select public.request_password_reset(''Awa@Example.com'')', 'Patientez % s avant de demander un nouveau code.');
end $$;

-- ---- un code faux est compté ; un mot de passe refusé ne coûte rien ------------------------
do $$
declare
  v jsonb;
  v_code text := current_setting('verif.code');
  v_faux text := case when current_setting('verif.code') = '000000' then '111111' else '000000' end;
begin
  v := public.reset_password_with_code('client1', v_faux, 'NouveauMdp1');
  if (v ->> 'ok')::boolean or v ->> 'message' <> 'Code incorrect. Il vous reste 4 essais.' then
    raise exception 'ÉCHEC : code faux (%)', v;
  end if;
  perform verif.refuse('mot de passe trop court', format('select public.reset_password_with_code(''client1'', %L, ''12345'')', v_code), '%au moins 6 caractères%');
  perform verif.refuse('mot de passe trop long', format('select public.reset_password_with_code(''client1'', %L, %L)', v_code, repeat('é', 37)), '%72 caractères%');
end $$;
reset role;
do $$ begin
  if (select attempts from public.password_reset_codes where user_id = '04060d99-e34d-520e-8b75-631ff4d3c10c') <> 1 then
    raise exception 'ÉCHEC : l''essai manqué n''est pas gardé, ou un refus de mot de passe a coûté un essai';
  end if;
  if (select encrypted_password from auth.users where id = '04060d99-e34d-520e-8b75-631ff4d3c10c') <> current_setting('verif.ancien_hash') then
    raise exception 'ÉCHEC : le mot de passe a changé sans le bon code';
  end if;
end $$;

-- ---- le bon code change le mot de passe et ferme les sessions --------------------------------
set local role anon;
set local request.jwt.claims to '{"role":"anon"}';
do $$
declare
  v jsonb := public.reset_password_with_code('awa@example.com', current_setting('verif.code'), 'NouveauMdp1');
begin
  if not (v ->> 'ok')::boolean or v ->> 'username' <> 'client1' then
    raise exception 'ÉCHEC : bon code, par l''adresse e-mail (%)', v;
  end if;
  if verif.dernier_mail() ->> 'Subject' <> 'Votre mot de passe MTC a été changé'
     or verif.dernier_mail() -> 'To' -> 0 ->> 'Email' <> 'awa@example.com' then
    raise exception 'ÉCHEC : pas d''e-mail d''alerte (%)', verif.dernier_mail();
  end if;
  perform verif.refuse('code réutilisé', format('select public.reset_password_with_code(''client1'', %L, ''AutreMdp1'')', current_setting('verif.code')), 'Aucun code en attente : demandez-en un.');
end $$;
reset role;
do $$
declare
  v_hash text;
begin
  select encrypted_password into v_hash from auth.users where id = '04060d99-e34d-520e-8b75-631ff4d3c10c';
  if v_hash = current_setting('verif.ancien_hash') or crypt('NouveauMdp1', v_hash) <> v_hash then
    raise exception 'ÉCHEC : le nouveau mot de passe n''est pas celui enregistré';
  end if;
  if crypt('password123', v_hash) = v_hash then
    raise exception 'ÉCHEC : l''ancien mot de passe marche encore';
  end if;
  if v_hash !~ '^\$2[aby]\$10\$' then
    raise exception 'ÉCHEC : hachage inattendu pour Supabase Auth (%)', left(v_hash, 7);
  end if;
  if exists (select 1 from auth.sessions where user_id = '04060d99-e34d-520e-8b75-631ff4d3c10c') then
    raise exception 'ÉCHEC : une session est restée ouverte';
  end if;
  if exists (select 1 from public.password_reset_codes where user_id = '04060d99-e34d-520e-8b75-631ff4d3c10c') then
    raise exception 'ÉCHEC : le code est resté en attente';
  end if;
  -- Personne d'autre n'a changé.
  if (select encrypted_password from auth.users where id = '3355adef-385d-5eee-a565-815c8cf8e4d3') = v_hash then
    raise exception 'ÉCHEC : le mot de passe de Moussa a bougé';
  end if;
end $$;

-- ---- l'ancien mot de passe dicté ne compte plus (collaborateur, `0098`) ----------------------
update public.profiles set must_change_password = true where id = '04060d99-e34d-520e-8b75-631ff4d3c10c';
set local role anon;
set local request.jwt.claims to '{"role":"anon"}';
select public.request_password_reset('client1');
select public.reset_password_with_code('client1', verif.code_recu(), 'EncoreUnMdp1');
reset role;
do $$ begin
  if (select must_change_password from public.profiles where id = '04060d99-e34d-520e-8b75-631ff4d3c10c') then
    raise exception 'ÉCHEC : un mot de passe choisi reste à changer';
  end if;
end $$;

-- ---- expiré, trop d'essais, trop d'envois ---------------------------------------------------
set local role anon;
set local request.jwt.claims to '{"role":"anon"}';
select public.request_password_reset('client1');
reset role;
update public.password_reset_codes set expires_at = now() - interval '1 second'
 where user_id = '04060d99-e34d-520e-8b75-631ff4d3c10c';
set local role anon;
set local request.jwt.claims to '{"role":"anon"}';
do $$ begin
  perform verif.refuse('code expiré', format('select public.reset_password_with_code(''client1'', %L, ''NouveauMdp2'')', verif.code_recu()), 'Ce code a expiré : demandez-en un nouveau.');
end $$;
reset role;
update public.password_reset_codes
   set expires_at = now() + interval '5 minutes', attempts = 5
 where user_id = '04060d99-e34d-520e-8b75-631ff4d3c10c';
set local role anon;
set local request.jwt.claims to '{"role":"anon"}';
do $$ begin
  perform verif.refuse('cinq essais manqués', format('select public.reset_password_with_code(''client1'', %L, ''NouveauMdp2'')', verif.code_recu()), 'Trop d''essais : demandez un nouveau code.');
end $$;
reset role;
update public.password_reset_codes
   set last_sent_at = now() - interval '2 minutes', sends_in_window = 5, window_started_at = now() - interval '10 minutes'
 where user_id = '04060d99-e34d-520e-8b75-631ff4d3c10c';
set local role anon;
set local request.jwt.claims to '{"role":"anon"}';
do $$ begin
  perform verif.refuse('sixième envoi de l''heure', 'select public.request_password_reset(''client1'')', 'Trop de codes demandés : réessayez dans % min.');
end $$;
reset role;

-- ---- un compte supprimé ne se récupère pas ----------------------------------------------------
update public.profiles set deleted_at = now() where id = '04060d99-e34d-520e-8b75-631ff4d3c10c';
set local role anon;
set local request.jwt.claims to '{"role":"anon"}';
do $$ begin
  perform verif.refuse('compte supprimé', 'select public.request_password_reset(''client1'')', 'Aucun compte ne correspond à cet identifiant.');
end $$;
reset role;

rollback;
\o
\echo 'TOUTES LES VÉRIFICATIONS PASSENT'
