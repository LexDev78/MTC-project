-- Vérifie la migration 0124 contre la base locale, sans rien y laisser :
-- tout se passe dans une transaction annulée à la fin, et l'e-mail mis en
-- file d'envoi disparaît avec elle — rien ne part.
--
--   docker exec -i supabase_db_MTC_project psql -U postgres -d postgres -q \
--     < supabase/snippets/verif_0124.sql
--
-- Dernière ligne attendue : « TOUTES LES VÉRIFICATIONS PASSENT ».
--
-- Le code est lu là où l'utilisateur le lirait : dans l'e-mail, ici encore
-- dans la file de `pg_net`. S'appuie sur Awa (client1) et Moussa (client2).
\set ON_ERROR_STOP 1
\o /dev/null
begin;
set local client_min_messages = warning;

create schema verif;
grant usage on schema verif to authenticated, anon;

create function verif.qui(p_uid uuid) returns void language sql as $$
  select set_config(
    'request.jwt.claims',
    json_build_object('sub', p_uid, 'role', 'authenticated')::text,
    true
  );
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

-- Le dernier e-mail mis en file : destinataire, sujet, texte.
create function verif.dernier_mail() returns jsonb language sql
security definer set search_path = public as $$
  select convert_from(q.body, 'utf8')::jsonb
    from net.http_request_queue q
   order by q.id desc
   limit 1;
$$;

-- Le code, tel qu'on le lirait dans l'e-mail.
create function verif.code_recu() returns text language sql as $$
  select substring(verif.dernier_mail() ->> 'Subject' from '([0-9]{6})$');
$$;

grant execute on all functions in schema verif to authenticated, anon;

-- Un vrai service d'envoi branché en local (`0125`) est écarté le temps de
-- l'essai : les e-mails restent au format de Mailpit, et rien ne part —
-- l'annulation finale les efface de toute façon.
delete from vault.secrets where name like 'mail\_%';

-- Des codes demandés pour de vrai dans l'app (Awa et Moussa sont les comptes
-- de démonstration) ne doivent pas fausser l'essai : écartés ici, ils
-- reviennent avec l'annulation finale.
delete from public.contact_email_verifications
 where user_id in ('04060d99-e34d-520e-8b75-631ff4d3c10c', '3355adef-385d-5eee-a565-815c8cf8e4d3');

-- Moussa a une adresse vérifiée : celle-là, Awa ne pourra pas la prendre.
update public.profiles
   set contact_email = 'moussa@exemple.ml', contact_email_verified_at = now()
 where id = '3355adef-385d-5eee-a565-815c8cf8e4d3';
-- Awa part d'une adresse jamais vérifiée, comme celles d'avant `0124`.
update public.profiles
   set contact_email = 'ancienne@exemple.ml', contact_email_verified_at = null
 where id = '04060d99-e34d-520e-8b75-631ff4d3c10c';

-- ---- les droits -----------------------------------------------------------
do $$ begin
  if has_table_privilege('authenticated', 'public.contact_email_verifications', 'SELECT')
     or has_table_privilege('anon', 'public.contact_email_verifications', 'SELECT') then
    raise exception 'ÉCHEC : les codes en attente sont lisibles';
  end if;
  -- Signature de `0125` (HTML et motif en plus).
  if has_function_privilege('authenticated', 'public.send_mail(text, text, text, text, text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.send_mail(text, text, text, text, text)', 'EXECUTE') then
    raise exception 'ÉCHEC : n''importe qui pourrait envoyer un e-mail au nom de MTC';
  end if;
  if has_function_privilege('anon', 'public.request_contact_email_code(text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.confirm_contact_email(text)', 'EXECUTE') then
    raise exception 'ÉCHEC : anon peut demander ou donner un code';
  end if;
end $$;

set local role authenticated;
select verif.qui('04060d99-e34d-520e-8b75-631ff4d3c10c');

-- ---- les adresses refusées avant tout envoi ---------------------------------
do $$ begin
  perform verif.refuse('adresse invalide', 'select public.request_contact_email_code(''awa@'')', 'Adresse e-mail invalide.');
  perform verif.refuse('pseudo-adresse', 'select public.request_contact_email_code(''awa@mtc.local'')', '%vraie boîte%');
  perform verif.refuse('adresse d''un autre', 'select public.request_contact_email_code(''Moussa@Exemple.ml'')', '%déjà utilisée par un autre compte%');
  perform verif.refuse('lire les codes', 'select * from public.contact_email_verifications', '%permission denied%');
  perform verif.refuse('envoyer soi-même', 'select public.send_mail(''x@y.ml'', ''s'', ''t'')', '%permission denied%');
  perform verif.refuse('enregistrer sans code', 'select public.set_my_contact_email(''awa@exemple.ml'')', '%code%');
  perform verif.refuse('rien en attente', 'select public.confirm_contact_email(''123456'')', 'Aucun code en attente : demandez-en un.');
end $$;

-- ---- un code part, et seule son empreinte reste -----------------------------
do $$
declare
  v_reponse jsonb := public.request_contact_email_code('  Awa@Exemple.ML ');
  v_mail jsonb := verif.dernier_mail();
  v_code text := verif.code_recu();
begin
  if v_reponse ->> 'email' <> 'awa@exemple.ml' then
    raise exception 'ÉCHEC : adresse non normalisée (%)', v_reponse;
  end if;
  if (v_reponse ->> 'resend_after_seconds')::int <> 60 then
    raise exception 'ÉCHEC : délai de renvoi (%)', v_reponse;
  end if;
  -- Rien d'autre que ces trois clés : surtout pas le code.
  if (select array_agg(k order by k) from jsonb_object_keys(v_reponse) k)
     <> array['email', 'expires_at', 'resend_after_seconds'] then
    raise exception 'ÉCHEC : réponse inattendue, le code y est peut-être (%)', v_reponse;
  end if;
  if v_mail -> 'To' -> 0 ->> 'Email' <> 'awa@exemple.ml' then
    raise exception 'ÉCHEC : e-mail adressé ailleurs (%)', v_mail;
  end if;
  if v_code !~ '^[0-9]{6}$' or position(v_code in v_mail ->> 'Text') = 0 then
    raise exception 'ÉCHEC : code absent de l''e-mail (%)', v_mail;
  end if;
  perform set_config('verif.code1', v_code, true);
end $$;

reset role;
do $$
declare
  v public.contact_email_verifications;
begin
  select * into v from public.contact_email_verifications
   where user_id = '04060d99-e34d-520e-8b75-631ff4d3c10c';
  if v.code_hash = current_setting('verif.code1') or v.code_hash !~ '^\$2[abxy]\$' then
    raise exception 'ÉCHEC : le code est gardé en clair (%)', v.code_hash;
  end if;
  if v.expires_at > now() + interval '10 minutes' or v.expires_at < now() + interval '9 minutes' then
    raise exception 'ÉCHEC : échéance (%)', v.expires_at;
  end if;
end $$;
set local role authenticated;
select verif.qui('04060d99-e34d-520e-8b75-631ff4d3c10c');

-- ---- pas de renvoi avant une minute ------------------------------------------
do $$ begin
  perform verif.refuse('renvoi immédiat', 'select public.request_contact_email_code(''awa@exemple.ml'')', 'Patientez % s avant de demander un nouveau code.');
end $$;

-- ---- un code faux est compté, et le compte tient --------------------------------
do $$
declare
  v jsonb;
begin
  v := public.confirm_contact_email('000000');
  if current_setting('verif.code1') = '000000' then
    raise exception 'ÉCHEC : jeu d''essai — le code tiré est 000000, relancez';
  end if;
  if (v ->> 'ok')::boolean or v ->> 'message' <> 'Code incorrect. Il vous reste 4 essais.' then
    raise exception 'ÉCHEC : premier code faux (%)', v;
  end if;
  v := public.confirm_contact_email('abc');
  if v ->> 'message' <> 'Code incorrect. Il vous reste 3 essais.' then
    raise exception 'ÉCHEC : saisie qui n''est pas un code (%)', v;
  end if;
end $$;
reset role;
do $$ begin
  if (select attempts from public.contact_email_verifications
       where user_id = '04060d99-e34d-520e-8b75-631ff4d3c10c') <> 2 then
    raise exception 'ÉCHEC : les essais manqués ne sont pas gardés';
  end if;
  if (select contact_email from public.profiles where id = '04060d99-e34d-520e-8b75-631ff4d3c10c') <> 'ancienne@exemple.ml' then
    raise exception 'ÉCHEC : un code faux a changé l''adresse';
  end if;
end $$;
set local role authenticated;
select verif.qui('04060d99-e34d-520e-8b75-631ff4d3c10c');
do $$
declare
  v jsonb;
begin
  perform public.confirm_contact_email('000000');
  perform public.confirm_contact_email('000000');
  v := public.confirm_contact_email('000000');
  if v ->> 'message' <> 'Code incorrect. Trop d''essais : demandez un nouveau code.' then
    raise exception 'ÉCHEC : cinquième essai (%)', v;
  end if;
  -- Même le bon code ne passe plus.
  perform verif.refuse('bon code après 5 essais',
    format('select public.confirm_contact_email(%L)', current_setting('verif.code1')),
    'Trop d''essais : demandez un nouveau code.');
end $$;

-- ---- un nouveau code remet les essais à zéro ; le bon code enregistre --------
reset role;
update public.contact_email_verifications
   set last_sent_at = now() - interval '2 minutes'
 where user_id = '04060d99-e34d-520e-8b75-631ff4d3c10c';
set local role authenticated;
select verif.qui('04060d99-e34d-520e-8b75-631ff4d3c10c');
do $$
declare
  v jsonb;
  v_ancien text := current_setting('verif.code1');
  v_code text;
begin
  perform public.request_contact_email_code('awa@exemple.ml');
  v_code := verif.code_recu();
  if v_code <> v_ancien then
    v := public.confirm_contact_email(v_ancien);
    if (v ->> 'ok')::boolean then
      raise exception 'ÉCHEC : l''ancien code vaut encore';
    end if;
  end if;
  v := public.confirm_contact_email(' ' || substr(v_code, 1, 3) || ' ' || substr(v_code, 4) || ' ');
  if not (v ->> 'ok')::boolean or v ->> 'email' <> 'awa@exemple.ml' then
    raise exception 'ÉCHEC : le bon code, espaces compris, refusé (%)', v;
  end if;
  if (select contact_email from public.profiles where id = auth.uid()) <> 'awa@exemple.ml'
     or (select contact_email_verified_at from public.profiles where id = auth.uid()) is null then
    raise exception 'ÉCHEC : adresse non enregistrée comme vérifiée';
  end if;
  perform verif.refuse('code réutilisé', format('select public.confirm_contact_email(%L)', v_code), 'Aucun code en attente : demandez-en un.');
  perform verif.refuse('même adresse vérifiée', 'select public.request_contact_email_code(''awa@exemple.ml'')', '%déjà votre adresse%');
end $$;

-- ---- l'ancienne adresse non vérifiée se revérifie ------------------------------
reset role;
update public.profiles set contact_email = 'ancienne@exemple.ml', contact_email_verified_at = null
 where id = '04060d99-e34d-520e-8b75-631ff4d3c10c';
set local role authenticated;
select verif.qui('04060d99-e34d-520e-8b75-631ff4d3c10c');
do $$ begin
  if public.request_contact_email_code('ancienne@exemple.ml') ->> 'email' <> 'ancienne@exemple.ml' then
    raise exception 'ÉCHEC : revérification de l''adresse non vérifiée';
  end if;
end $$;

-- ---- expiré ----------------------------------------------------------------------
reset role;
update public.contact_email_verifications set expires_at = now() - interval '1 second'
 where user_id = '04060d99-e34d-520e-8b75-631ff4d3c10c';
set local role authenticated;
select verif.qui('04060d99-e34d-520e-8b75-631ff4d3c10c');
do $$ begin
  perform verif.refuse('code expiré', format('select public.confirm_contact_email(%L)', verif.code_recu()), 'Ce code a expiré : demandez-en un nouveau.');
end $$;

-- ---- prise entre-temps par un autre compte -------------------------------------
reset role;
update public.contact_email_verifications
   set expires_at = now() + interval '5 minutes', last_sent_at = now() - interval '2 minutes'
 where user_id = '04060d99-e34d-520e-8b75-631ff4d3c10c';
set local role authenticated;
select verif.qui('04060d99-e34d-520e-8b75-631ff4d3c10c');
select public.request_contact_email_code('convoitee@exemple.ml');
reset role;
update public.profiles set contact_email = 'convoitee@exemple.ml', contact_email_verified_at = now()
 where id = '3355adef-385d-5eee-a565-815c8cf8e4d3';
set local role authenticated;
select verif.qui('04060d99-e34d-520e-8b75-631ff4d3c10c');
do $$
declare
  v jsonb := public.confirm_contact_email(verif.code_recu());
begin
  if (v ->> 'ok')::boolean or v ->> 'message' not like '%autre compte%' then
    raise exception 'ÉCHEC : adresse prise entre-temps (%)', v;
  end if;
end $$;

-- ---- cinq envois par heure au plus ---------------------------------------------
reset role;
update public.contact_email_verifications
   set last_sent_at = now() - interval '2 minutes', sends_in_window = 5,
       window_started_at = now() - interval '10 minutes'
 where user_id = '04060d99-e34d-520e-8b75-631ff4d3c10c';
insert into public.contact_email_verifications
  (user_id, email, code_hash, expires_at, last_sent_at, window_started_at, sends_in_window)
select '04060d99-e34d-520e-8b75-631ff4d3c10c', 'x@exemple.ml', 'x', now(), now() - interval '2 minutes', now() - interval '10 minutes', 5
 where not exists (select 1 from public.contact_email_verifications where user_id = '04060d99-e34d-520e-8b75-631ff4d3c10c');
set local role authenticated;
select verif.qui('04060d99-e34d-520e-8b75-631ff4d3c10c');
do $$ begin
  perform verif.refuse('sixième envoi de l''heure', 'select public.request_contact_email_code(''awa2@exemple.ml'')', 'Trop de codes demandés : réessayez dans % min.');
end $$;

-- ---- Moussa ne touche pas au code d'Awa ; retirer efface tout --------------------
select verif.qui('3355adef-385d-5eee-a565-815c8cf8e4d3');
do $$ begin
  perform verif.refuse('Moussa et le code d''Awa', 'select public.confirm_contact_email(''123456'')', 'Aucun code en attente : demandez-en un.');
end $$;
select verif.qui('04060d99-e34d-520e-8b75-631ff4d3c10c');
select public.set_my_contact_email(null);
reset role;
do $$ begin
  if (select contact_email is not null or contact_email_verified_at is not null
        from public.profiles where id = '04060d99-e34d-520e-8b75-631ff4d3c10c') then
    raise exception 'ÉCHEC : retrait incomplet';
  end if;
  if exists (select 1 from public.contact_email_verifications where user_id = '04060d99-e34d-520e-8b75-631ff4d3c10c') then
    raise exception 'ÉCHEC : un code reste en attente après le retrait';
  end if;
end $$;

-- ---- anonyme -----------------------------------------------------------------------
set local role anon;
set local request.jwt.claims to '{"role":"anon"}';
do $$ begin
  perform verif.refuse('anon demande', 'select public.request_contact_email_code(''a@b.ml'')', '%permission denied%');
  perform verif.refuse('anon confirme', 'select public.confirm_contact_email(''123456'')', '%permission denied%');
end $$;
reset role;

rollback;
\o
\echo 'TOUTES LES VÉRIFICATIONS PASSENT'
