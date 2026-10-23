-- Une adresse e-mail ne s'enregistre plus sans avoir été vérifiée.
--
-- Jusqu'ici, `set_my_contact_email` (`0109`) prenait l'adresse telle quelle :
-- une faute de frappe, ou l'adresse d'un autre, devenait celle du compte. Elle
-- est maintenant prouvée : un code à six chiffres part à l'adresse saisie, et
-- c'est en le donnant qu'on l'enregistre.
--
--   request_contact_email_code(adresse)  envoie un code, valable 10 minutes ;
--   confirm_contact_email(code)          enregistre l'adresse si le code est
--                                        le bon.
--
-- Le code ne passe jamais par l'application : il est tiré ici, envoyé d'ici,
-- et seule son empreinte est gardée (bcrypt). Ce que l'app reçoit, c'est
-- l'adresse, l'échéance et le délai avant de pouvoir en redemander un.
--
-- Les limites, parce qu'un code à six chiffres se devine si l'on peut
-- essayer sans fin :
--
--   * 5 essais par code, puis il faut en redemander un ;
--   * 60 secondes entre deux envois, 5 envois par heure au plus ;
--   * un essai manqué est **compté**, et pour qu'il le reste la fonction le
--     rend comme une réponse plutôt que de lever une erreur — une erreur
--     annulerait la transaction, et le compteur avec elle : on pourrait
--     essayer à l'infini.
--
-- L'envoi passe par `pg_net`, comme les notifications push (`0041`) : la base
-- appelle l'API d'envoi, sans fonction edge de plus — en local, une fonction
-- nouvelle n'est servie qu'après redémarrage de toute la pile. En local,
-- l'API est celle de Mailpit, la boîte de test de Supabase
-- (http://127.0.0.1:54324). En production, rien n'est encore branché : il
-- faudra poser `mail_api_url` (et `mail_api_key`, `mail_from`) dans Vault,
-- vers un service qui accepte le format de Mailpit ou en adaptant
-- `send_mail`.
--
-- Les adresses enregistrées avant ce changement n'ont jamais été vérifiées :
-- elles restent, sans date de vérification, et l'app propose de les vérifier.

alter table public.profiles
  add column if not exists contact_email_verified_at timestamptz;

create table public.contact_email_verifications (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  email text not null,
  -- bcrypt du code : le code lui-même n'est gardé nulle part.
  code_hash text not null,
  expires_at timestamptz not null,
  attempts integer not null default 0,
  last_sent_at timestamptz not null,
  -- La fenêtre d'une heure des envois, et ce qui y a déjà été envoyé.
  window_started_at timestamptz not null,
  sends_in_window integer not null
);

alter table public.contact_email_verifications enable row level security;
-- Aucune policy, aucun droit : tout passe par les deux fonctions.
revoke all on public.contact_email_verifications from public, anon, authenticated;

-- ---- l'envoi ------------------------------------------------------------------

-- Met un e-mail en file d'envoi (`pg_net`) et rend l'identifiant de la
-- requête. Réservée aux fonctions de la base : personne ne l'appelle d'un
-- client, sinon n'importe qui enverrait n'importe quoi en notre nom.
create or replace function public.send_mail(
  p_to text,
  p_subject text,
  p_text text
)
returns bigint
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_url text;
  v_key text;
  v_from text;
begin
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'mail_api_url';
  select decrypted_secret into v_key from vault.decrypted_secrets where name = 'mail_api_key';
  select decrypted_secret into v_from from vault.decrypted_secrets where name = 'mail_from';

  -- Repli local : Mailpit, joint sur le réseau de la pile.
  v_url := coalesce(v_url, 'http://supabase_inbucket_MTC_project:8025/api/v1/send');
  v_from := coalesce(v_from, 'no-reply@mtc.local');

  return net.http_post(
    url := v_url,
    headers := jsonb_strip_nulls(jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', case when v_key is not null then 'Bearer ' || v_key end
    )),
    body := jsonb_build_object(
      'From', jsonb_build_object('Email', v_from, 'Name', 'MTC - Mali Trade Connect'),
      'To', jsonb_build_array(jsonb_build_object('Email', p_to)),
      'Subject', p_subject,
      'Text', p_text
    )
  );
end;
$$;

revoke all on function public.send_mail(text, text, text) from public, anon, authenticated;

-- ---- demander un code -----------------------------------------------------------

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
  -- La même adresse se revérifie tant qu'elle ne l'a jamais été (`0109`).
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

  -- Six chiffres tirés au hasard cryptographique, zéros de tête compris.
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
      || 'MTC - Mali Trade Connect'
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

-- ---- donner le code -------------------------------------------------------------

-- Rend `{"ok": true, "email": …}`, ou `{"ok": false, "message": …}` pour un
-- code faux — une réponse et non une erreur, pour que l'essai reste compté
-- (voir l'en-tête). Les autres refus (rien en attente, code expiré, essais
-- épuisés) ne changent rien : ils restent des erreurs.
create or replace function public.confirm_contact_email(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_code text := regexp_replace(coalesce(p_code, ''), '[[:space:]]', '', 'g');
  v_ligne public.contact_email_verifications;
  v_restants integer;
begin
  if v_uid is null then
    raise exception 'Connectez-vous pour valider votre adresse.';
  end if;

  select * into v_ligne
    from public.contact_email_verifications
   where user_id = v_uid
   for update;
  if not found then
    raise exception 'Aucun code en attente : demandez-en un.';
  end if;
  if v_ligne.expires_at < now() then
    raise exception 'Ce code a expiré : demandez-en un nouveau.';
  end if;
  if v_ligne.attempts >= 5 then
    raise exception 'Trop d''essais : demandez un nouveau code.';
  end if;

  if v_code !~ '^[0-9]{6}$' or crypt(v_code, v_ligne.code_hash) <> v_ligne.code_hash then
    update public.contact_email_verifications
       set attempts = attempts + 1
     where user_id = v_uid;
    v_restants := 5 - (v_ligne.attempts + 1);
    return jsonb_build_object('ok', false, 'message', case
      when v_restants <= 0 then 'Code incorrect. Trop d''essais : demandez un nouveau code.'
      when v_restants = 1 then 'Code incorrect. Il vous reste 1 essai.'
      else format('Code incorrect. Il vous reste %s essais.', v_restants)
    end);
  end if;

  -- Prise entre-temps par un autre compte : le code ne sert plus à rien.
  if exists (
    select 1 from public.profiles
     where lower(contact_email) = v_ligne.email and id <> v_uid
  ) then
    delete from public.contact_email_verifications where user_id = v_uid;
    return jsonb_build_object(
      'ok', false,
      'message', 'Cette adresse vient d''être enregistrée par un autre compte.'
    );
  end if;

  update public.profiles
     set contact_email = v_ligne.email,
         contact_email_verified_at = now()
   where id = v_uid;
  delete from public.contact_email_verifications where user_id = v_uid;

  return jsonb_build_object('ok', true, 'email', v_ligne.email);
end;
$$;

revoke all on function public.confirm_contact_email(text) from public, anon;
grant execute on function public.confirm_contact_email(text) to authenticated;

-- ---- retirer son adresse ------------------------------------------------------

-- `set_my_contact_email` ne fait plus que retirer : une nouvelle adresse passe
-- par le code. L'accepter encore ici rouvrirait l'enregistrement sans preuve.
create or replace function public.set_my_contact_email(p_email text)
returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Connectez-vous pour modifier votre adresse e-mail.';
  end if;
  if nullif(btrim(coalesce(p_email, '')), '') is not null then
    raise exception 'Une nouvelle adresse se valide par le code qu''on vous envoie.';
  end if;

  update public.profiles
     set contact_email = null,
         contact_email_verified_at = null
   where id = auth.uid();
  -- Un code demandé pour une autre adresse n'a plus de raison d'attendre.
  delete from public.contact_email_verifications where user_id = auth.uid();
  return null;
end;
$$;

revoke all on function public.set_my_contact_email(text) from public, anon;
grant execute on function public.set_my_contact_email(text) to authenticated;

notify pgrst, 'reload schema';
