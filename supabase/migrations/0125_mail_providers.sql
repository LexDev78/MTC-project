-- Le service d'envoi d'e-mails : Brevo ou Resend en production, Mailpit en
-- local, choisi par configuration et non par le code.
--
-- `send_mail` (`0124`) ne parlait que le format de Mailpit, la boîte de test
-- de la pile locale. Le voici branché sur deux services réels, dont l'API a
-- été relue dans leur documentation :
--
--   brevo    POST https://api.brevo.com/v3/smtp/email   en-tête `api-key`
--            corps : sender {name, email}, to [{email}], subject,
--            htmlContent (exigé), textContent ; répond 201 {messageId}
--   resend   POST https://api.resend.com/emails         `Authorization: Bearer`
--            corps : from « Nom <adresse> », to [adresse], subject, html,
--            text ; répond 200 {id}
--   mailpit  la boîte locale (http://127.0.0.1:54324), par défaut
--
-- La configuration vit dans Vault, chiffrée, comme celle des notifications
-- push (`0041`) :
--
--   mail_provider   brevo | resend | mailpit (défaut : mailpit)
--   mail_api_key    la clé du service
--   mail_from       l'adresse d'expédition, vérifiée chez le service
--   mail_from_name  le nom affiché (défaut : MTC - Mali Trade Connect)
--   mail_api_url    facultatif : remplace l'URL du service (relais, essais)
--
-- `supabase/snippets/configurer_envoi_mail.sql` dit comment les poser.
--
-- L'envoi reste asynchrone (`pg_net`) : la réponse du service arrive après
-- la transaction. Pour qu'une clé refusée ou un domaine non vérifié ne
-- fassent pas échouer les envois en silence, chaque envoi est noté dans
-- `mail_log`, et `recent_mail_deliveries()` rapproche chaque envoi de la
-- réponse du service — à l'usage de l'administration seule, puisque ce sont
-- des adresses de clients.

-- ---- la configuration -----------------------------------------------------------

create or replace function public.mail_config()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'provider', coalesce(
      (select lower(btrim(decrypted_secret)) from vault.decrypted_secrets where name = 'mail_provider'),
      'mailpit'
    ),
    'api_key', (select btrim(decrypted_secret) from vault.decrypted_secrets where name = 'mail_api_key'),
    'from_email', coalesce(
      (select btrim(decrypted_secret) from vault.decrypted_secrets where name = 'mail_from'),
      'no-reply@mtc.local'
    ),
    'from_name', coalesce(
      (select btrim(decrypted_secret) from vault.decrypted_secrets where name = 'mail_from_name'),
      'MTC - Mali Trade Connect'
    ),
    'url', (select btrim(decrypted_secret) from vault.decrypted_secrets where name = 'mail_api_url')
  );
$$;

revoke all on function public.mail_config() from public, anon, authenticated;

-- Le texte d'un e-mail, sûr dans du HTML.
create or replace function public.html_escape(p_texte text)
returns text
language sql
immutable
set search_path = public
as $$
  select replace(replace(replace(replace(replace(
    coalesce(p_texte, ''),
    '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), '"', '&quot;'), '''', '&#39;');
$$;

revoke all on function public.html_escape(text) from public, anon, authenticated;

-- La requête HTTP d'un envoi, pour le service de [p_config] : l'URL, les
-- en-têtes et le corps. Rien n'est envoyé ici — c'est ce qui se vérifie sans
-- service réel, au caractère près.
create or replace function public.mail_http_request(
  p_config jsonb,
  p_to text,
  p_subject text,
  p_text text,
  p_html text default null
)
returns jsonb
language plpgsql
stable
set search_path = public
as $$
declare
  v_service text := lower(coalesce(p_config ->> 'provider', 'mailpit'));
  v_cle text := nullif(p_config ->> 'api_key', '');
  v_de text := p_config ->> 'from_email';
  -- Un nom affiché ne porte ni chevrons, ni guillemets, ni virgules : dans
  -- « Nom <adresse> », ils casseraient l'en-tête From.
  v_nom text := btrim(regexp_replace(coalesce(p_config ->> 'from_name', ''), '[<>",]', '', 'g'));
  v_url text := nullif(p_config ->> 'url', '');
  -- Brevo exige une version HTML : à défaut, le texte, échappé.
  v_html text := coalesce(
    p_html,
    '<pre style="font-family:inherit;white-space:pre-wrap">' || public.html_escape(p_text) || '</pre>'
  );
begin
  case v_service
    when 'brevo' then
      if v_cle is null then
        raise exception 'Envoi d''e-mails : la clé Brevo manque (secret mail_api_key).';
      end if;
      return jsonb_build_object(
        'url', coalesce(v_url, 'https://api.brevo.com/v3/smtp/email'),
        'headers', jsonb_build_object(
          'Content-Type', 'application/json',
          'Accept', 'application/json',
          'api-key', v_cle
        ),
        'body', jsonb_build_object(
          'sender', jsonb_build_object('name', v_nom, 'email', v_de),
          'to', jsonb_build_array(jsonb_build_object('email', p_to)),
          'subject', p_subject,
          'htmlContent', v_html,
          'textContent', p_text
        )
      );
    when 'resend' then
      if v_cle is null then
        raise exception 'Envoi d''e-mails : la clé Resend manque (secret mail_api_key).';
      end if;
      return jsonb_build_object(
        'url', coalesce(v_url, 'https://api.resend.com/emails'),
        'headers', jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || v_cle
        ),
        'body', jsonb_build_object(
          'from', case when v_nom = '' then v_de else v_nom || ' <' || v_de || '>' end,
          'to', jsonb_build_array(p_to),
          'subject', p_subject,
          'html', v_html,
          'text', p_text
        )
      );
    when 'mailpit' then
      return jsonb_build_object(
        'url', coalesce(v_url, 'http://supabase_inbucket_MTC_project:8025/api/v1/send'),
        'headers', jsonb_strip_nulls(jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', case when v_cle is not null then 'Bearer ' || v_cle end
        )),
        'body', jsonb_build_object(
          'From', jsonb_build_object('Email', v_de, 'Name', v_nom),
          'To', jsonb_build_array(jsonb_build_object('Email', p_to)),
          'Subject', p_subject,
          'Text', p_text,
          'HTML', v_html
        )
      );
    else
      raise exception 'Envoi d''e-mails : service « % » inconnu (brevo, resend ou mailpit).', v_service;
  end case;
end;
$$;

revoke all on function public.mail_http_request(jsonb, text, text, text, text) from public, anon, authenticated;

-- ---- le journal des envois ------------------------------------------------------

create table public.mail_log (
  -- L'identifiant de la requête `pg_net` : c'est lui qui retrouve la réponse
  -- du service dans `net._http_response`.
  request_id bigint primary key,
  purpose text,
  provider text not null,
  to_email text not null,
  created_at timestamptz not null default now()
);

create index mail_log_created_idx on public.mail_log (created_at desc);

alter table public.mail_log enable row level security;
revoke all on public.mail_log from public, anon, authenticated;

-- ---- l'envoi --------------------------------------------------------------------

drop function if exists public.send_mail(text, text, text);

create or replace function public.send_mail(
  p_to text,
  p_subject text,
  p_text text,
  p_html text default null,
  p_purpose text default null
)
returns bigint
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_config jsonb := public.mail_config();
  v_requete jsonb := public.mail_http_request(v_config, p_to, p_subject, p_text, p_html);
  v_id bigint;
begin
  v_id := net.http_post(
    url := v_requete ->> 'url',
    headers := v_requete -> 'headers',
    body := v_requete -> 'body',
    timeout_milliseconds := 10000
  );

  insert into public.mail_log (request_id, purpose, provider, to_email)
  values (v_id, p_purpose, v_config ->> 'provider', p_to);
  -- Un mois suffit pour comprendre un envoi manqué ; au-delà, ce ne sont
  -- plus que des adresses gardées pour rien.
  delete from public.mail_log where created_at < now() - interval '30 days';

  return v_id;
end;
$$;

revoke all on function public.send_mail(text, text, text, text, text) from public, anon, authenticated;

-- Les derniers envois et ce que le service en a dit : `status_code` 200 ou
-- 201 = accepté ; 4xx = refusé (clé, domaine, adresse), le motif dans
-- `error` ; vide = pas encore parti, ou réponse déjà purgée par `pg_net`.
--
-- Lisible par un admin depuis l'app, et depuis l'éditeur SQL de Supabase,
-- où l'on n'est connecté sous aucun compte (`auth.uid()` vide) : `anon`,
-- l'autre appelant sans compte, n'a pas le droit d'exécuter la fonction.
create or replace function public.recent_mail_deliveries(p_limit integer default 50)
returns table (
  sent_at timestamptz,
  purpose text,
  provider text,
  to_email text,
  status_code integer,
  error text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'Réservé à l''administration MTC.';
  end if;
  return query
    select l.created_at,
           l.purpose,
           l.provider,
           l.to_email,
           r.status_code,
           coalesce(
             r.error_msg,
             case when r.timed_out then 'Délai dépassé' end,
             case when r.status_code >= 300 then left(r.content, 300) end
           )
      from public.mail_log l
      left join net._http_response r on r.id = l.request_id
     order by l.created_at desc
     limit least(greatest(coalesce(p_limit, 50), 1), 200);
end;
$$;

revoke all on function public.recent_mail_deliveries(integer) from public, anon;
grant execute on function public.recent_mail_deliveries(integer) to authenticated;

-- ---- le code de vérification, en texte et en HTML ---------------------------------

-- Reprise de `0124`, à l'identique sauf l'envoi : une version HTML (exigée
-- par Brevo, plus lisible partout), et le motif noté au journal.
create or replace function public.request_contact_email_code(p_email text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_actuelle text;
  v_verifiee timestamptz;
  v_nom text;
  v_ligne public.contact_email_verifications;
  v_maintenant timestamptz := now();
  v_code text;
  v_attente integer;
begin
  if v_uid is null then
    raise exception 'Connectez-vous pour ajouter une adresse e-mail.';
  end if;

  select contact_email, contact_email_verified_at, display_name
    into v_actuelle, v_verifiee, v_nom
    from public.profiles
   where id = v_uid and deleted_at is null;
  if not found then
    raise exception 'Ce compte n''existe plus.';
  end if;

  if v_email !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'Adresse e-mail invalide.';
  end if;
  if v_email ~* '@mtc\.local$' then
    raise exception 'Cette adresse n''est pas une vraie boîte e-mail.';
  end if;
  if v_email = lower(coalesce(v_actuelle, '')) and v_verifiee is not null then
    raise exception 'C''est déjà votre adresse, et elle est vérifiée.';
  end if;
  if exists (
    select 1 from public.profiles
     where lower(contact_email) = v_email and id <> v_uid
  ) then
    raise exception 'Cette adresse est déjà utilisée par un autre compte.';
  end if;

  select * into v_ligne
    from public.contact_email_verifications
   where user_id = v_uid
   for update;
  if found then
    v_attente := ceil(extract(epoch from (v_ligne.last_sent_at + interval '60 seconds' - v_maintenant)))::integer;
    if v_attente > 0 then
      raise exception 'Patientez % s avant de demander un nouveau code.', v_attente;
    end if;
    if v_ligne.window_started_at > v_maintenant - interval '1 hour'
       and v_ligne.sends_in_window >= 5 then
      raise exception 'Trop de codes demandés : réessayez dans % min.',
        greatest(1, ceil(extract(epoch from (v_ligne.window_started_at + interval '1 hour' - v_maintenant)) / 60)::integer);
    end if;
  end if;

  v_code := lpad(
    ((('x' || encode(gen_random_bytes(4), 'hex'))::bit(32)::bigint) % 1000000)::text,
    6, '0'
  );

  insert into public.contact_email_verifications as v (
    user_id, email, code_hash, expires_at, attempts,
    last_sent_at, window_started_at, sends_in_window
  ) values (
    v_uid, v_email, crypt(v_code, gen_salt('bf', 8)), v_maintenant + interval '10 minutes', 0,
    v_maintenant, v_maintenant, 1
  )
  on conflict (user_id) do update set
    email = excluded.email,
    code_hash = excluded.code_hash,
    expires_at = excluded.expires_at,
    attempts = 0,
    last_sent_at = excluded.last_sent_at,
    window_started_at = case
      when v.window_started_at > v_maintenant - interval '1 hour' then v.window_started_at
      else v_maintenant
    end,
    sends_in_window = case
      when v.window_started_at > v_maintenant - interval '1 hour' then v.sends_in_window + 1
      else 1
    end;

  perform public.send_mail(
    v_email,
    'Votre code MTC : ' || v_code,
    'Bonjour ' || v_nom || E',\n\n'
      || 'Voici le code pour valider cette adresse e-mail sur votre compte MTC : '
      || v_code || E'\n\n'
      || 'Il est valable 10 minutes. Si vous n''avez rien demandé, ignorez ce '
      || E'message : l''adresse ne sera pas enregistrée.\n\n'
      || 'MTC - Mali Trade Connect',
    '<!doctype html><html lang="fr"><body style="margin:0;padding:24px;'
      || 'background:#f3f3f4;font-family:Arial,Helvetica,sans-serif;color:#16161e">'
      || '<div style="max-width:480px;margin:0 auto;background:#ffffff;'
      || 'border-radius:12px;padding:32px">'
      || '<p style="margin:0 0 16px">Bonjour ' || public.html_escape(v_nom) || ',</p>'
      || '<p style="margin:0 0 16px">Voici le code pour valider cette adresse '
      || 'e-mail sur votre compte MTC :</p>'
      || '<p style="margin:0 0 16px;font-size:32px;font-weight:bold;'
      || 'letter-spacing:8px;color:#7b61ff">' || v_code || '</p>'
      || '<p style="margin:0 0 16px;color:#737378">Il est valable 10 minutes. '
      || 'Si vous n''avez rien demandé, ignorez ce message : l''adresse ne sera '
      || 'pas enregistrée.</p>'
      || '<p style="margin:0;color:#737378">MTC - Mali Trade Connect</p>'
      || '</div></body></html>',
    'contact_email_code'
  );

  return jsonb_build_object(
    'email', v_email,
    'expires_at', v_maintenant + interval '10 minutes',
    'resend_after_seconds', 60
  );
end;
$$;

revoke all on function public.request_contact_email_code(text) from public, anon;
grant execute on function public.request_contact_email_code(text) to authenticated;

notify pgrst, 'reload schema';
