-- Vérifie la migration 0125 contre la base locale, sans rien y laisser :
-- tout se passe dans une transaction annulée à la fin — secrets de Vault
-- compris, et les e-mails mis en file disparaissent avec elle.
--
--   docker exec -i supabase_db_MTC_project psql -U postgres -d postgres -q \
--     < supabase/snippets/verif_0125.sql
--
-- Dernière ligne attendue : « TOUTES LES VÉRIFICATIONS PASSENT ».
--
-- Les formats sont ceux des documentations de Brevo
-- (developers.brevo.com/reference/sendtransacemail) et de Resend
-- (resend.com/docs/api-reference/emails/send-email). Les secrets `mail_*`
-- éventuellement posés en local sont écartés le temps de l'essai, et
-- reviennent avec l'annulation.
\set ON_ERROR_STOP 1
\o /dev/null
begin;
set local client_min_messages = warning;

create schema verif;
create function verif.egal(p_cas text, p_obtenu jsonb, p_attendu jsonb)
returns void language plpgsql as $$
begin
  if p_obtenu is distinct from p_attendu then
    raise exception 'ÉCHEC % : obtenu %, attendu %',
      p_cas, coalesce(p_obtenu::text, 'null'), coalesce(p_attendu::text, 'null');
  end if;
end $$;

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

delete from vault.secrets where name like 'mail\_%';

grant usage on schema verif to authenticated;
grant execute on all functions in schema verif to authenticated;

-- ---- les droits ----------------------------------------------------------------------
do $$ begin
  if has_function_privilege('authenticated', 'public.mail_config()', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.mail_http_request(jsonb, text, text, text, text)', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.send_mail(text, text, text, text, text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.recent_mail_deliveries(integer)', 'EXECUTE') then
    raise exception 'ÉCHEC : une fonction d''envoi est ouverte à qui ne doit pas';
  end if;
  if has_table_privilege('authenticated', 'public.mail_log', 'SELECT') then
    raise exception 'ÉCHEC : le journal des envois est lisible';
  end if;
end $$;

-- ---- la configuration par défaut : Mailpit -----------------------------------------
select verif.egal('configuration locale', public.mail_config(), jsonb_build_object(
  'provider', 'mailpit', 'api_key', null, 'from_email', 'no-reply@mtc.local',
  'from_name', 'MTC - Mali Trade Connect', 'url', null));

-- ---- Brevo, au caractère près ---------------------------------------------------------
select verif.egal('Brevo', public.mail_http_request(
  '{"provider":"brevo","api_key":"cle-brevo","from_email":"no-reply@mtc.ml","from_name":"MTC - Mali Trade Connect"}',
  'awa@exemple.ml', 'Sujet', 'Texte', '<p>Texte</p>'),
  jsonb_build_object(
    'url', 'https://api.brevo.com/v3/smtp/email',
    'headers', jsonb_build_object('Content-Type', 'application/json', 'Accept', 'application/json', 'api-key', 'cle-brevo'),
    'body', jsonb_build_object(
      'sender', jsonb_build_object('name', 'MTC - Mali Trade Connect', 'email', 'no-reply@mtc.ml'),
      'to', jsonb_build_array(jsonb_build_object('email', 'awa@exemple.ml')),
      'subject', 'Sujet',
      'htmlContent', '<p>Texte</p>',
      'textContent', 'Texte')));

-- Sans HTML fourni, Brevo reçoit quand même le sien : le texte, échappé.
select verif.egal('Brevo sans HTML',
  public.mail_http_request('{"provider":"brevo","api_key":"k","from_email":"a@b.ml"}',
    'x@y.ml', 'S', 'a < b & "c"', null) -> 'body' -> 'htmlContent',
  to_jsonb('<pre style="font-family:inherit;white-space:pre-wrap">a &lt; b &amp; &quot;c&quot;</pre>'::text));

-- ---- Resend ------------------------------------------------------------------------------
select verif.egal('Resend', public.mail_http_request(
  '{"provider":"resend","api_key":"re_cle","from_email":"no-reply@mtc.ml","from_name":"MTC - Mali Trade Connect"}',
  'awa@exemple.ml', 'Sujet', 'Texte', '<p>Texte</p>'),
  jsonb_build_object(
    'url', 'https://api.resend.com/emails',
    'headers', jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer re_cle'),
    'body', jsonb_build_object(
      'from', 'MTC - Mali Trade Connect <no-reply@mtc.ml>',
      'to', jsonb_build_array('awa@exemple.ml'),
      'subject', 'Sujet',
      'html', '<p>Texte</p>',
      'text', 'Texte')));

-- Un nom qui casserait l'en-tête From est nettoyé.
select verif.egal('nom nettoyé',
  public.mail_http_request('{"provider":"resend","api_key":"k","from_email":"a@b.ml","from_name":"MTC, \"<officiel>\""}',
    'x@y.ml', 'S', 'T', null) -> 'body' -> 'from',
  to_jsonb('MTC officiel <a@b.ml>'::text));

-- L'URL se remplace (relais, essais).
select verif.egal('URL remplacée',
  public.mail_http_request('{"provider":"resend","api_key":"k","from_email":"a@b.ml","url":"http://relais.local/emails"}',
    'x@y.ml', 'S', 'T', null) -> 'url',
  to_jsonb('http://relais.local/emails'::text));

-- ---- Mailpit (local) ---------------------------------------------------------------------
select verif.egal('Mailpit', public.mail_http_request(public.mail_config(), 'awa@exemple.ml', 'Sujet', 'Texte', '<p>Texte</p>'),
  jsonb_build_object(
    'url', 'http://supabase_inbucket_MTC_project:8025/api/v1/send',
    'headers', jsonb_build_object('Content-Type', 'application/json'),
    'body', jsonb_build_object(
      'From', jsonb_build_object('Email', 'no-reply@mtc.local', 'Name', 'MTC - Mali Trade Connect'),
      'To', jsonb_build_array(jsonb_build_object('Email', 'awa@exemple.ml')),
      'Subject', 'Sujet',
      'Text', 'Texte',
      'HTML', '<p>Texte</p>')));

-- ---- les erreurs de configuration se disent ----------------------------------------------
do $$ begin
  perform verif.refuse('Brevo sans clé',
    'select public.mail_http_request(''{"provider":"brevo","from_email":"a@b.ml"}'', ''x@y.ml'', ''S'', ''T'', null)',
    '%clé Brevo manque%');
  perform verif.refuse('Resend sans clé',
    'select public.mail_http_request(''{"provider":"resend","from_email":"a@b.ml"}'', ''x@y.ml'', ''S'', ''T'', null)',
    '%clé Resend manque%');
  perform verif.refuse('service inconnu',
    'select public.mail_http_request(''{"provider":"sendgrid"}'', ''x@y.ml'', ''S'', ''T'', null)',
    '%service « sendgrid » inconnu%');
end $$;

-- ---- configurée dans Vault, la base part chez Brevo -----------------------------------------
select vault.create_secret('brevo', 'mail_provider');
select vault.create_secret(' xkeysib-essai ', 'mail_api_key');
select vault.create_secret('no-reply@mtc.ml', 'mail_from');
select verif.egal('configuration lue dans Vault', public.mail_config(), jsonb_build_object(
  'provider', 'brevo', 'api_key', 'xkeysib-essai', 'from_email', 'no-reply@mtc.ml',
  'from_name', 'MTC - Mali Trade Connect', 'url', null));

-- Awa demande un code : l'e-mail part chez Brevo, en texte et en HTML.
update public.profiles set display_name = 'Awa <Traoré>' where id = '04060d99-e34d-520e-8b75-631ff4d3c10c';
delete from public.contact_email_verifications where user_id = '04060d99-e34d-520e-8b75-631ff4d3c10c';
set local role authenticated;
set local request.jwt.claims to '{"sub":"04060d99-e34d-520e-8b75-631ff4d3c10c","role":"authenticated"}';
select public.request_contact_email_code('awa.verif@exemple.ml');
reset role;
do $$
declare
  q record;
  v_corps jsonb;
  v_code text;
begin
  select * into q from net.http_request_queue order by id desc limit 1;
  v_corps := convert_from(q.body, 'utf8')::jsonb;
  if q.url <> 'https://api.brevo.com/v3/smtp/email' then
    raise exception 'ÉCHEC : envoi ailleurs que chez Brevo (%)', q.url;
  end if;
  if q.headers ->> 'api-key' <> 'xkeysib-essai' then
    raise exception 'ÉCHEC : clé absente ou mal recopiée (%)', q.headers;
  end if;
  if q.timeout_milliseconds <> 10000 then
    raise exception 'ÉCHEC : délai d''attente (%)', q.timeout_milliseconds;
  end if;
  v_code := substring(v_corps ->> 'subject' from '([0-9]{6})$');
  if v_code is null or position(v_code in v_corps ->> 'textContent') = 0
     or position(v_code in v_corps ->> 'htmlContent') = 0 then
    raise exception 'ÉCHEC : le code manque au texte ou au HTML (%)', v_corps;
  end if;
  -- Le nom du client est échappé dans le HTML : pas de balise injectée.
  if position('Awa &lt;Traoré&gt;' in v_corps ->> 'htmlContent') = 0
     or position('<Traoré>' in v_corps ->> 'htmlContent') > 0 then
    raise exception 'ÉCHEC : nom non échappé dans le HTML';
  end if;
  if v_corps -> 'to' <> '[{"email": "awa.verif@exemple.ml"}]'::jsonb then
    raise exception 'ÉCHEC : destinataire (%)', v_corps -> 'to';
  end if;
  -- Le journal note l'envoi, sans le code.
  if not exists (
    select 1 from public.mail_log
     where request_id = q.id and provider = 'brevo'
       and purpose = 'contact_email_code' and to_email = 'awa.verif@exemple.ml'
  ) then
    raise exception 'ÉCHEC : envoi absent du journal';
  end if;
end $$;

-- ---- le rapport des envois : l'administration seule ------------------------------------------
set local role authenticated;
set local request.jwt.claims to '{"sub":"2358888a-b13d-56f8-858b-a0c63831b512","role":"authenticated"}';
do $$
declare
  r record;
begin
  select * into r from public.recent_mail_deliveries(5) limit 1;
  if r.to_email <> 'awa.verif@exemple.ml' or r.provider <> 'brevo' or r.status_code is not null then
    raise exception 'ÉCHEC : rapport de l''admin (%)', r;
  end if;
end $$;
set local request.jwt.claims to '{"sub":"0354c601-5e09-57b6-a23c-affaa5acf0d0","role":"authenticated"}';
do $$ begin
  perform verif.refuse('agent', 'select * from public.recent_mail_deliveries(5)', 'Réservé à l''administration MTC.');
end $$;
set local request.jwt.claims to '{"sub":"04060d99-e34d-520e-8b75-631ff4d3c10c","role":"authenticated"}';
do $$ begin
  perform verif.refuse('client', 'select * from public.recent_mail_deliveries(5)', 'Réservé à l''administration MTC.');
  perform verif.refuse('client et le journal', 'select * from public.mail_log', '%permission denied%');
  perform verif.refuse('client et l''envoi', 'select public.send_mail(''x@y.ml'', ''s'', ''t'')', '%permission denied%');
end $$;
reset role;

-- Depuis l'éditeur SQL (aucun compte), le rapport se lit.
set local request.jwt.claims to '{}';
do $$ begin
  if not exists (select 1 from public.recent_mail_deliveries(5) where to_email = 'awa.verif@exemple.ml') then
    raise exception 'ÉCHEC : rapport illisible depuis l''éditeur SQL';
  end if;
end $$;

rollback;
\o
\echo 'TOUTES LES VÉRIFICATIONS PASSENT'
