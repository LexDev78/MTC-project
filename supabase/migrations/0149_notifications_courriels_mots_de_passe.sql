-- 0149 — Notifications, courriels et mots de passe : ce qui part de MTC ne
-- dit que ce que MTC sait (trouvé en corrigeant l'audit du 27/10/2026, le
-- 05/11/2026).
--
--  1. Jetons de notification. L'app enregistrait son jeton FCM par un
--     upsert sur `fcm_token`, refusé par la policy dès que le jeton
--     appartenait à un autre compte : après une déconnexion dont le nettoyage
--     n'atteignait pas le serveur (hors ligne, session expirée), le
--     téléphone recevait pour toujours les notifications du compte précédent
--     — messages, commandes, versements, autre rôle compris —, et le compte
--     courant aucune. Le jeton s'enregistre désormais par
--     `register_device_token` : le détenir prouve qu'on est sur l'appareil,
--     il passe au compte connecté. Les jetons muets depuis 60 jours ne
--     reçoivent plus rien.
--  2. Le crochet des notifications push retombait sur un secret écrit dans
--     le dépôt (`local-dev-push-secret`) dès que le Vault n'en avait pas :
--     sur un projet hébergé mal configuré, n'importe qui l'ayant lu appelait
--     `send-push-notification` et poussait le texte de son choix à qui il
--     voulait. Le repli ne vaut plus que pour la fonction locale ; et la
--     fonction relit la notification en base au lieu de croire le corps de
--     la requête (`notification_for_push`).
--  3. `request_contact_email_code` disait, sans limite, si une adresse
--     appartenait à un compte MTC (le refus passait avant les limites), et
--     envoyait à n'importe quelle adresse un courriel de MTC qui reprenait
--     le nom affiché du demandeur — un texte libre. La réponse est désormais
--     la même que l'adresse soit libre ou prise, le courriel ne contient
--     plus rien d'écrit par le demandeur, une adresse ne reçoit pas plus de
--     cinq codes par jour, et le service entier pas plus de 300 par heure —
--     comptés sur les courriels réellement partis.
--  4. Le changement de mot de passe imposé (`0098`) n'était qu'indicatif :
--     `mark_password_changed()` levait le drapeau sans aucun changement. Il
--     se lève désormais quand le mot de passe change vraiment (déclencheur
--     sur `auth.users`), et la fonction ne fait plus rien.
--
-- `request_contact_email_code` et `mail_html` sont reprises de leur
-- définition en vigueur, ces passages seuls changés.

-- --------------------------------------------------------- 1. les jetons
create or replace function public.register_device_token(p_token text, p_platform text default 'android')
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Connectez-vous pour recevoir des notifications.';
  end if;
  if coalesce(btrim(p_token), '') = '' or char_length(p_token) > 4096 then
    raise exception 'Jeton de notification invalide.';
  end if;
  insert into public.device_tokens (user_id, fcm_token, platform, updated_at, last_seen_at)
  values (auth.uid(), p_token, coalesce(nullif(p_platform, ''), 'android'), now(), now())
  on conflict (fcm_token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        updated_at = now(),
        last_seen_at = now();
end;
$$;

revoke all on function public.register_device_token(text, text) from public, anon;
grant execute on function public.register_device_token(text, text) to authenticated;

drop policy if exists device_tokens_insert_own on public.device_tokens;
drop policy if exists device_tokens_update_own on public.device_tokens;
revoke insert, update on public.device_tokens from anon, authenticated;

-- Reprise de la définition en vigueur, la fraîcheur du jeton ajoutée.
create or replace function public.get_device_tokens_for_notification_user(p_user_id uuid)
 returns table(fcm_token text)
 language sql
 security definer
 set search_path to 'public'
as $function$
  select dt.fcm_token
  from public.device_tokens dt
  where dt.last_seen_at > now() - interval '60 days'
    and (dt.user_id = p_user_id
     or (
       p_user_id = '3331cbb4-0a65-5f94-9812-fe4270e50fe2'::uuid
       and dt.user_id in (
         select p.id
           from public.profiles p
           join auth.users u on u.id = p.id
          where p.role = 'supplier_principal'
            and (u.raw_app_meta_data ->> 'staff_role') = p.staff_role::text
       )
     ));
$function$;

-- ---------------------------------------------------------- 2. le crochet push
create or replace function public.notify_push_on_notification()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public', 'extensions'
as $function$
declare
  v_url text;
  v_secret text;
begin
  begin
    select decrypted_secret into v_url
    from vault.decrypted_secrets
    where name = 'push_function_url';
    select decrypted_secret into v_secret
    from vault.decrypted_secrets
    where name = 'push_function_secret';
    if v_url is null and v_secret is not null then
      -- Un secret sans son adresse : on ne l'envoie pas au repli local, en
      -- clair (contre-vérification du 06/11/2026).
      raise warning 'push ignoré (notification % conservée) : push_function_url absent du Vault.', new.id;
      return new;
    elsif v_url is null then
      -- Repli local : `supabase functions serve` écoute sur l'hôte, que le
      -- conteneur Postgres joint via `host.docker.internal`, avec le secret
      -- de `supabase/functions/.env.example`. Il n'ouvre que la fonction
      -- locale.
      v_url := 'http://host.docker.internal:54321/functions/v1/send-push-notification';
      v_secret := 'local-dev-push-secret';
    elsif v_secret is null then
      -- Une adresse configurée sans son secret : un projet hébergé à moitié
      -- réglé. Pas de repli sur un secret public (`0149`).
      raise warning 'push ignoré (notification % conservée) : push_function_secret absent du Vault.', new.id;
      return new;
    end if;
    perform net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_secret
      ),
      body := jsonb_build_object(
        'type', 'INSERT',
        'table', 'notifications',
        'record', to_jsonb(new)
      )
    );
  exception
    when others then
      -- Jamais `raise exception` : on est dans la transaction de l'INSERT,
      -- la faire échouer perdrait la notification elle-même (voir
      -- `0041_push_webhook_never_blocks_insert.sql`).
      raise warning 'push webhook ignoré (notification % conservée) : %',
        new.id, sqlerrm;
  end;
  return new;
end;
$function$;

-- Ce que la fonction pousse : la notification telle qu'elle est en base, si
-- elle vient d'être créée — jamais ce que dit le corps de la requête, ni une
-- vieille notification rejouée.
create or replace function public.notification_for_push(p_id text)
returns table (user_id uuid, type public.notification_type, title text, body text, reference_id text)
language sql
stable
security definer
set search_path = public
as $$
  select n.user_id, n.type, n.title, n.body, n.reference_id
    from public.notifications n
   where n.id = p_id
     and n.created_at > now() - interval '10 minutes';
$$;

revoke all on function public.notification_for_push(text) from public, anon, authenticated;
grant execute on function public.notification_for_push(text) to service_role;

-- -------------------------------------------------- 3. le code de l'adresse e-mail
-- Les plafonds lisent le journal des envois par destinataire.
create index if not exists mail_log_to_email_idx
  on public.mail_log (lower(to_email), created_at desc);

CREATE OR REPLACE FUNCTION public.request_contact_email_code(p_email text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
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
  v_envoyer boolean := true;
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

  -- Les limites ci-dessus jouent d'abord, pour tout le monde. Ensuite, une
  -- adresse qui appartient déjà à un autre compte, ou que trop de comptes
  -- différents ont demandée aujourd'hui, ne reçoit rien — mais la réponse
  -- est la même qu'un envoi réussi (`0149`) : ni « cette adresse est à
  -- quelqu'un », ni relais pour écrire à n'importe qui. La confirmation
  -- (`confirm_contact_email`) revérifie, et refuse une adresse prise.
  -- Les plafonds comptent les courriels réellement partis (`mail_log`),
  -- de tous les comptes, l'appelant compris : compter les lignes de
  -- vérification se contournait en effaçant la sienne
  -- (`set_my_contact_email(null)`), et des demandes silencieuses suffisaient
  -- à bloquer une adresse pour son vrai propriétaire
  -- (contre-vérification du 06/11/2026).
  if exists (
    select 1 from public.profiles
     where lower(contact_email) = v_email and id <> v_uid
  ) or (
    select count(*) from public.mail_log
     where lower(to_email) = v_email and purpose = 'contact_email_code'
       and created_at > v_maintenant - interval '1 day'
  ) >= 5 then
    v_envoyer := false;
  end if;
  -- Et un plafond pour tout le service, qui protège la réputation de
  -- l'expéditeur si quelqu'un ouvre des comptes à la chaîne.
  if (select count(*) from public.mail_log
       where purpose = 'contact_email_code'
         and created_at > v_maintenant - interval '1 hour') >= 300 then
    raise exception 'Trop de demandes en ce moment : réessayez dans quelques minutes.';
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

  if v_envoyer then
  -- Ni le nom affiché ni rien que le compte écrit lui-même : l'adresse n'est
  -- pas encore la sienne, et un texte libre en ferait un message de MTC à
  -- la teneur choisie par n'importe qui (`0149`).
  perform public.send_mail(
    v_email,
    'Votre code MTC : ' || v_code,
    E'Bonjour,\n\n'
      || 'Voici le code pour valider cette adresse e-mail sur votre compte MTC : '
      || v_code || E'\n\n'
      || 'Il est valable 10 minutes. Si vous n''avez rien demandé, ignorez ce '
      || E'message : l''adresse ne sera pas enregistrée.\n\n'
      || 'MTC - Mali Trade Connect',
    public.mail_html(
      null,
      'Voici le code pour valider cette adresse e-mail sur votre compte MTC :',
      v_code,
      'Il est valable 10 minutes. Si vous n''avez rien demandé, ignorez ce '
        || 'message : l''adresse ne sera pas enregistrée.'
    ),
    'contact_email_code'
  );
  end if;

  return jsonb_build_object(
    'email', v_email,
    'expires_at', v_maintenant + interval '10 minutes',
    'resend_after_seconds', 60
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.mail_html(p_nom text, p_intro text, p_code text DEFAULT NULL::text, p_suite text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select '<!doctype html><html lang="fr"><body style="margin:0;padding:24px;'
    || 'background:#f3f3f4;font-family:Arial,Helvetica,sans-serif;color:#16161e">'
    || '<div style="max-width:480px;margin:0 auto;background:#ffffff;'
    || 'border-radius:12px;padding:32px">'
    -- Sans nom (adresse pas encore vérifiée, `0149`) : « Bonjour, » tout court.
    || '<p style="margin:0 0 16px">Bonjour'
    || coalesce(' ' || nullif(btrim(public.html_escape(p_nom)), ''), '') || ',</p>'
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
$function$;

-- ---------------------------------------- 4. le changement de mot de passe imposé
create or replace function public.clear_forced_password_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
     set must_change_password = false
   where id = new.id and must_change_password;
  return null;
end;
$$;

revoke all on function public.clear_forced_password_change() from public, anon, authenticated;

-- `when` : seul un vrai changement compte. GoTrue réécrit parfois la ligne
-- entière (métadonnées, dernière connexion) ; le même condensat ne lève rien.
drop trigger if exists on_auth_password_changed on auth.users;
create trigger on_auth_password_changed
  after update of encrypted_password on auth.users
  for each row
  when (old.encrypted_password is distinct from new.encrypted_password)
  execute function public.clear_forced_password_change();

-- Gardée pour les versions de l'app déjà installées, qui l'appellent après
-- `updateUser` : le déclencheur a déjà levé le drapeau, et elle ne peut plus
-- le lever sans changement.
create or replace function public.mark_password_changed()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  return;
end;
$$;
