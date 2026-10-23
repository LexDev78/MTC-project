-- Mot de passe oublié : un code envoyé à l'adresse e-mail vérifiée du compte.
--
-- La récupération intégrée de Supabase Auth ne peut pas servir : le compte
-- Auth porte une pseudo-adresse (`identifiant@mtc.local`, `pseudoEmail`),
-- qui ne reçoit rien. La seule boîte réelle d'un compte est son adresse de
-- contact, et seulement une fois vérifiée par code (`0124`) — une adresse
-- jamais vérifiée pourrait être celle d'un autre.
--
--   request_password_reset(identifiant)   envoie un code, valable 10 min ;
--   reset_password_with_code(identifiant, code, mot de passe)
--                                         change le mot de passe.
--
-- L'identifiant est le nom d'utilisateur (ou téléphone) de connexion, ou
-- l'adresse e-mail vérifiée elle-même : on oublie aussi son identifiant.
-- L'e-mail du code le rappelle.
--
-- Ouvertes à `anon` : on les appelle justement sans pouvoir se connecter.
-- D'où les mêmes limites que les codes d'adresse (5 essais par code, une
-- minute entre deux envois, 5 envois par heure), et un essai manqué rendu
-- comme une réponse, pour qu'il reste compté (voir `0124`).
--
-- Le mot de passe est écrit dans `auth.users`, haché par bcrypt comme le
-- fait Supabase Auth (le jeu de démonstration l'écrit déjà ainsi). Toutes
-- les sessions du compte sont fermées : si quelqu'un d'autre y était
-- connecté, il ne l'est plus. Un e-mail prévient du changement.
--
-- Ce que ces fonctions disent à un inconnu : qu'un compte existe, et s'il a
-- une adresse vérifiée (masquée). L'inscription disait déjà le premier
-- (« identifiant déjà pris ») ; le second aide la personne à savoir où
-- chercher son code.

create table public.password_reset_codes (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  code_hash text not null,
  expires_at timestamptz not null,
  attempts integer not null default 0,
  last_sent_at timestamptz not null,
  window_started_at timestamptz not null,
  sends_in_window integer not null
);

alter table public.password_reset_codes enable row level security;
revoke all on public.password_reset_codes from public, anon, authenticated;

-- ---- outils ---------------------------------------------------------------------

-- Le compte désigné par un identifiant de connexion, ou par une adresse
-- e-mail **vérifiée** — jamais une adresse qui ne l'est pas.
create or replace function public.password_reset_account(p_identifiant text)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select p.id
    from public.profiles p
   where p.deleted_at is null
     and case
       when position('@' in btrim(coalesce(p_identifiant, ''))) > 0 then
         lower(p.contact_email) = lower(btrim(p_identifiant))
         and p.contact_email_verified_at is not null
       else
         lower(p.username_or_phone) = lower(btrim(coalesce(p_identifiant, '')))
     end
   limit 1;
$$;

revoke all on function public.password_reset_account(text) from public, anon, authenticated;

-- « labatigassamba72@gmail.com » → « la•••@gmail.com » : de quoi reconnaître
-- sa boîte, sans livrer l'adresse.
create or replace function public.mask_email(p_email text)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when position('@' in coalesce(p_email, '')) = 0 then '•••'
    else left(split_part(p_email, '@', 1),
              case when length(split_part(p_email, '@', 1)) > 2 then 2 else 1 end)
         || '•••@' || split_part(p_email, '@', 2)
  end;
$$;

revoke all on function public.mask_email(text) from public, anon, authenticated;

-- Le corps HTML des e-mails de MTC : bonjour, un paragraphe, le code en
-- grand s'il y en a un, une suite, la signature. Tout est échappé. Les
-- e-mails à code partagent ainsi la même mise en page.
create or replace function public.mail_html(
  p_nom text,
  p_intro text,
  p_code text default null,
  p_suite text default null
)
returns text
language sql
immutable
set search_path = public
as $$
  select '<!doctype html><html lang="fr"><body style="margin:0;padding:24px;'
    || 'background:#f3f3f4;font-family:Arial,Helvetica,sans-serif;color:#16161e">'
    || '<div style="max-width:480px;margin:0 auto;background:#ffffff;'
    || 'border-radius:12px;padding:32px">'
    || '<p style="margin:0 0 16px">Bonjour ' || public.html_escape(p_nom) || ',</p>'
    || '<p style="margin:0 0 16px">' || public.html_escape(p_intro) || '</p>'
    || case when p_code is null then '' else
         '<p style="margin:0 0 16px;font-size:32px;font-weight:bold;'
         || 'letter-spacing:8px;color:#7b61ff">' || public.html_escape(p_code) || '</p>'
       end
    || case when p_suite is null then '' else
         '<p style="margin:0 0 16px;color:#737378">' || public.html_escape(p_suite) || '</p>'
       end
    || '<p style="margin:0;color:#737378">MTC - Mali Trade Connect</p>'
    || '</div></body></html>';
$$;

revoke all on function public.mail_html(text, text, text, text) from public, anon, authenticated;

-- ---- demander un code ---------------------------------------------------------------

create or replace function public.request_password_reset(p_identifiant text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := public.password_reset_account(p_identifiant);
  v_email text;
  v_verifiee timestamptz;
  v_nom text;
  v_identifiant text;
  v_ligne public.password_reset_codes;
  v_maintenant timestamptz := now();
  v_attente integer;
  v_code text;
  v_intro text;
  v_suite text;
begin
  if v_uid is null then
    raise exception 'Aucun compte ne correspond à cet identifiant.';
  end if;

  select contact_email, contact_email_verified_at, display_name, username_or_phone
    into v_email, v_verifiee, v_nom, v_identifiant
    from public.profiles
   where id = v_uid;
  if v_email is null or v_verifiee is null then
    raise exception 'Ce compte n''a pas d''adresse e-mail vérifiée : il ne peut pas être récupéré par e-mail. Contactez MTC.';
  end if;

  select * into v_ligne from public.password_reset_codes where user_id = v_uid for update;
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

  insert into public.password_reset_codes as r (
    user_id, code_hash, expires_at, attempts,
    last_sent_at, window_started_at, sends_in_window
  ) values (
    v_uid, crypt(v_code, gen_salt('bf', 8)), v_maintenant + interval '10 minutes', 0,
    v_maintenant, v_maintenant, 1
  )
  on conflict (user_id) do update set
    code_hash = excluded.code_hash,
    expires_at = excluded.expires_at,
    attempts = 0,
    last_sent_at = excluded.last_sent_at,
    window_started_at = case
      when r.window_started_at > v_maintenant - interval '1 hour' then r.window_started_at
      else v_maintenant
    end,
    sends_in_window = case
      when r.window_started_at > v_maintenant - interval '1 hour' then r.sends_in_window + 1
      else 1
    end;

  v_intro := 'Vous avez demandé à changer le mot de passe de votre compte MTC. '
    || 'Votre identifiant de connexion est « ' || v_identifiant || ' ». Voici votre code :';
  v_suite := 'Il est valable 10 minutes. Si vous n''avez rien demandé, ignorez ce '
    || 'message : votre mot de passe ne change pas.';

  perform public.send_mail(
    v_email,
    'Réinitialisation de votre mot de passe MTC : ' || v_code,
    'Bonjour ' || v_nom || E',\n\n' || v_intro || ' ' || v_code || E'\n\n'
      || v_suite || E'\n\nMTC - Mali Trade Connect',
    public.mail_html(v_nom, v_intro, v_code, v_suite),
    'password_reset_code'
  );

  return jsonb_build_object(
    'masked_email', public.mask_email(v_email),
    'expires_at', v_maintenant + interval '10 minutes',
    'resend_after_seconds', 60
  );
end;
$$;

revoke all on function public.request_password_reset(text) from public;
grant execute on function public.request_password_reset(text) to anon, authenticated;

-- ---- changer le mot de passe ----------------------------------------------------------

-- `{"ok": true, "username": …}` — l'identifiant de connexion, pour que l'app
-- connecte la personne aussitôt, même venue par son adresse e-mail ; ou
-- `{"ok": false, "message": …}` pour un code faux.
create or replace function public.reset_password_with_code(
  p_identifiant text,
  p_code text,
  p_password text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := public.password_reset_account(p_identifiant);
  v_code text := regexp_replace(coalesce(p_code, ''), '[[:space:]]', '', 'g');
  v_ligne public.password_reset_codes;
  v_restants integer;
  v_email text;
  v_nom text;
  v_identifiant text;
begin
  if v_uid is null then
    raise exception 'Aucun compte ne correspond à cet identifiant.';
  end if;
  -- Le mot de passe d'abord : le refuser ne doit pas coûter un essai.
  -- Mêmes règles que Supabase Auth (`minimum_password_length`), et la
  -- limite de bcrypt, qui ignorerait le reste sans rien dire.
  if char_length(coalesce(p_password, '')) < 6 then
    raise exception 'Le mot de passe doit compter au moins 6 caractères.';
  end if;
  if octet_length(p_password) > 72 then
    raise exception 'Le mot de passe est trop long : 72 caractères au plus.';
  end if;

  select * into v_ligne from public.password_reset_codes where user_id = v_uid for update;
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
    update public.password_reset_codes set attempts = attempts + 1 where user_id = v_uid;
    v_restants := 5 - (v_ligne.attempts + 1);
    return jsonb_build_object('ok', false, 'message', case
      when v_restants <= 0 then 'Code incorrect. Trop d''essais : demandez un nouveau code.'
      when v_restants = 1 then 'Code incorrect. Il vous reste 1 essai.'
      else format('Code incorrect. Il vous reste %s essais.', v_restants)
    end);
  end if;

  update auth.users
     set encrypted_password = crypt(p_password, gen_salt('bf', 10)),
         updated_at = now()
   where id = v_uid;
  -- Fermer toutes les sessions ; les jetons de rafraîchissement suivent
  -- leur session. Ceux d'avant les sessions sont retirés à part.
  delete from auth.sessions where user_id = v_uid;
  delete from auth.refresh_tokens where user_id = v_uid::text;
  -- Un mot de passe choisi par la personne elle-même : celui que son patron
  -- lui avait dicté ne compte plus (`0098`).
  update public.profiles set must_change_password = false where id = v_uid;
  delete from public.password_reset_codes where user_id = v_uid;

  select contact_email, display_name, username_or_phone
    into v_email, v_nom, v_identifiant
    from public.profiles where id = v_uid;
  perform public.send_mail(
    v_email,
    'Votre mot de passe MTC a été changé',
    'Bonjour ' || v_nom || E',\n\n'
      || 'Le mot de passe de votre compte MTC (« ' || v_identifiant || ' ») vient '
      || E'd''être changé, et vos autres appareils ont été déconnectés.\n\n'
      || 'Si ce n''est pas vous, contactez MTC au plus vite.'
      || E'\n\nMTC - Mali Trade Connect',
    public.mail_html(
      v_nom,
      'Le mot de passe de votre compte MTC (« ' || v_identifiant || ' ») vient '
        || 'd''être changé, et vos autres appareils ont été déconnectés.',
      null,
      'Si ce n''est pas vous, contactez MTC au plus vite.'
    ),
    'password_changed'
  );

  return jsonb_build_object('ok', true, 'username', v_identifiant);
end;
$$;

revoke all on function public.reset_password_with_code(text, text, text) from public;
grant execute on function public.reset_password_with_code(text, text, text) to anon, authenticated;

-- ---- le code d'adresse, même mise en page -----------------------------------------------

-- Reprise de `0125` à l'identique, sauf le HTML : il vient de `mail_html`,
-- comme celui des e-mails de mot de passe, au lieu d'être recopié.
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
    public.mail_html(
      v_nom,
      'Voici le code pour valider cette adresse e-mail sur votre compte MTC :',
      v_code,
      'Il est valable 10 minutes. Si vous n''avez rien demandé, ignorez ce '
        || 'message : l''adresse ne sera pas enregistrée.'
    ),
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
