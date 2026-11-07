-- Mot de passe oublié : un plafond par jour, et plus rien à apprendre d'un
-- refus.
--
-- ===========================================================================
-- Ce que l'audit a mesuré
-- ===========================================================================
--
-- `0127` limitait chaque code à 5 essais, et les envois à 5 par heure. Soit
-- 25 essais par heure, indéfiniment, sur un code de 6 chiffres : environ
-- 219 000 essais par an pour 1 000 000 de codes possibles, une chance sur
-- cinq de prendre un compte visé.
--
-- Et un inconnu apprenait en chemin :
--   * si un identifiant existe (« Aucun compte ne correspond ») ;
--   * s'il a une adresse vérifiée, et laquelle à demi (« aw•••@gmail.com ») ;
--   * s'il a un code en attente (« Il vous reste 4 essais »).
--
-- ===========================================================================
-- Ce qui change
-- ===========================================================================
--
-- 1. Un plafond qui ne se remet pas à zéro avec le code : 10 essais faux sur
--    24 heures bloquent la récupération du compte, 24 heures la première
--    fois, puis le double à chaque récidive (48 h, 4 jours… 30 jours au
--    plus). Le titulaire en est prévenu par e-mail. Au pire, une dizaine de
--    séries de 10 essais par an : moins de 2 chances sur 10 000.
--
--    Revers assumé : un inconnu peut bloquer la récupération d'un compte
--    dont il connaît l'identifiant. Il ne bloque pas la connexion — le mot
--    de passe reste valable —, et l'équipe MTC peut lever le blocage
--    (`delete from password_reset_guard where user_id = …`).
--
-- 2. Les deux fonctions répondent la même chose quel que soit le compte :
--    « si ce compte existe et a une adresse vérifiée, un code y est parti »,
--    et « code incorrect ou expiré ». Les délais (une minute entre deux
--    envois, cinq par heure) s'appliquent sans le dire. Un calcul bcrypt
--    factice égalise le temps de réponse : la durée de l'appel ne trahit
--    pas plus que son contenu.
--
-- 3. Un compte du staff MTC exige 10 caractères. La règle n'est dite
--    qu'une fois le bon code donné, pour ne pas désigner à un inconnu les
--    comptes qui sont du staff.

create table if not exists public.password_reset_guard (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  -- La fenêtre de 24 heures s'ouvre au premier essai faux.
  failures_window_started_at timestamptz,
  failures_in_window integer not null default 0,
  locked_until timestamptz,
  -- Le nombre de blocages déjà subis : il double la durée du suivant.
  lockouts integer not null default 0
);

alter table public.password_reset_guard enable row level security;
revoke all on public.password_reset_guard from public, anon, authenticated;

comment on table public.password_reset_guard is
  'Plafond quotidien des essais de code de récupération, par compte (0132). '
  'Propriété exclusive de request_password_reset / reset_password_with_code.';

-- ---- demander un code ---------------------------------------------------------------

create or replace function public.request_password_reset(p_identifiant text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_maintenant timestamptz := now();
  -- La seule réponse, quoi qu'il arrive : elle ne dit ni si le compte
  -- existe, ni s'il a une adresse, ni si un code est vraiment parti.
  v_reponse constant jsonb := jsonb_build_object(
    'expires_at', v_maintenant + interval '10 minutes',
    'resend_after_seconds', 60
  );
  v_uid uuid := public.password_reset_account(p_identifiant);
  v_email text;
  v_verifiee timestamptz;
  v_nom text;
  v_identifiant text;
  v_ligne public.password_reset_codes;
  v_code text;
  v_intro text;
  v_suite text;
begin
  if v_uid is not null then
    select contact_email, contact_email_verified_at, display_name, username_or_phone
      into v_email, v_verifiee, v_nom, v_identifiant
      from public.profiles
     where id = v_uid;
  end if;

  -- Rien à envoyer : compte inconnu, sans adresse vérifiée, récupération
  -- bloquée, ou délai d'envoi pas écoulé. Le même coût qu'un envoi, et la
  -- même réponse.
  if v_uid is null or v_email is null or v_verifiee is null
     or exists (
       select 1 from public.password_reset_guard g
        where g.user_id = v_uid and g.locked_until > v_maintenant
     ) then
    perform crypt('000000', gen_salt('bf', 8));
    return v_reponse;
  end if;

  select * into v_ligne from public.password_reset_codes where user_id = v_uid for update;
  if found and (
       v_ligne.last_sent_at + interval '60 seconds' > v_maintenant
       or (v_ligne.window_started_at > v_maintenant - interval '1 hour'
           and v_ligne.sends_in_window >= 5)
     ) then
    perform crypt('000000', gen_salt('bf', 8));
    return v_reponse;
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

  return v_reponse;
end;
$$;

revoke all on function public.request_password_reset(text) from public;
grant execute on function public.request_password_reset(text) to anon, authenticated;

-- ---- changer le mot de passe ----------------------------------------------------------

-- `{"ok": true, "username": …}`, ou `{"ok": false, "message": …}` — le même
-- message pour tout refus de code. Une réponse et non une erreur, pour que
-- l'essai manqué reste compté (`0124`).
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
  v_refus constant jsonb := jsonb_build_object(
    'ok', false,
    'message', 'Code incorrect ou expiré. Vérifiez-le, ou demandez-en un nouveau.'
  );
  v_uid uuid := public.password_reset_account(p_identifiant);
  v_code text := regexp_replace(coalesce(p_code, ''), '[[:space:]]', '', 'g');
  v_ligne public.password_reset_codes;
  v_garde public.password_reset_guard;
  v_email text;
  v_nom text;
  v_identifiant text;
  v_staff boolean;
  v_jusqua text;
begin
  -- Le mot de passe d'abord, par des règles qui valent pour tous les
  -- comptes : les refuser ne coûte pas un essai, et ne dit rien du compte.
  -- Mêmes règles que Supabase Auth (`minimum_password_length`), et la
  -- limite de bcrypt, qui ignorerait le reste sans rien dire.
  if char_length(coalesce(p_password, '')) < 6 then
    raise exception 'Le mot de passe doit compter au moins 6 caractères.';
  end if;
  if octet_length(p_password) > 72 then
    raise exception 'Le mot de passe est trop long : 72 caractères au plus.';
  end if;

  if v_uid is null then
    perform crypt(v_code, gen_salt('bf', 8));
    return v_refus;
  end if;

  select * into v_garde from public.password_reset_guard where user_id = v_uid for update;
  select * into v_ligne from public.password_reset_codes where user_id = v_uid for update;
  if v_garde.locked_until > now()
     or v_ligne.user_id is null
     or v_ligne.expires_at < now()
     or v_ligne.attempts >= 5 then
    perform crypt(v_code, gen_salt('bf', 8));
    return v_refus;
  end if;

  if v_code !~ '^[0-9]{6}$' or crypt(v_code, v_ligne.code_hash) <> v_ligne.code_hash then
    update public.password_reset_codes set attempts = attempts + 1 where user_id = v_uid;

    -- Le compteur du jour : il survit au code, et c'est tout son intérêt.
    insert into public.password_reset_guard as g (user_id, failures_window_started_at, failures_in_window)
    values (v_uid, now(), 1)
    on conflict (user_id) do update set
      failures_window_started_at = case
        when g.failures_window_started_at is null
          or g.failures_window_started_at <= now() - interval '24 hours' then now()
        else g.failures_window_started_at
      end,
      failures_in_window = case
        when g.failures_window_started_at is null
          or g.failures_window_started_at <= now() - interval '24 hours' then 1
        else g.failures_in_window + 1
      end
    returning * into v_garde;

    if v_garde.failures_in_window >= 10 then
      update public.password_reset_guard
         set locked_until = now() + least(interval '24 hours' * power(2, lockouts), interval '30 days'),
             lockouts = lockouts + 1,
             failures_in_window = 0,
             failures_window_started_at = null
       where user_id = v_uid
      returning * into v_garde;
      -- Le code en cours meurt avec le blocage.
      delete from public.password_reset_codes where user_id = v_uid;

      select contact_email, display_name, username_or_phone
        into v_email, v_nom, v_identifiant
        from public.profiles where id = v_uid;
      v_jusqua := to_char(v_garde.locked_until at time zone 'Africa/Bamako', 'DD/MM/YYYY à HH24:MI');
      if v_email is not null then
        perform public.send_mail(
          v_email,
          'Récupération de votre compte MTC suspendue',
          'Bonjour ' || v_nom || E',\n\n'
            || 'Plusieurs codes faux ont été saisis pour changer le mot de passe de votre '
            || 'compte MTC (« ' || v_identifiant || ' »). Par sécurité, la récupération par '
            || 'e-mail est suspendue jusqu''au ' || v_jusqua || E' (heure de Bamako).\n\n'
            || 'Votre mot de passe n''a pas changé : vous pouvez toujours vous connecter. '
            || 'Si ce n''est pas vous, contactez MTC.'
            || E'\n\nMTC - Mali Trade Connect',
          public.mail_html(
            v_nom,
            'Plusieurs codes faux ont été saisis pour changer le mot de passe de votre '
              || 'compte MTC (« ' || v_identifiant || ' »). Par sécurité, la récupération par '
              || 'e-mail est suspendue jusqu''au ' || v_jusqua || ' (heure de Bamako).',
            null,
            'Votre mot de passe n''a pas changé : vous pouvez toujours vous connecter. '
              || 'Si ce n''est pas vous, contactez MTC.'
          ),
          'password_reset_locked'
        );
      end if;
    end if;

    return v_refus;
  end if;

  -- Le bon code : la personne tient la boîte du compte. On peut lui dire
  -- la règle propre aux comptes du staff, sans lui coûter son code.
  select staff_role is not null into v_staff from public.profiles where id = v_uid;
  if v_staff and char_length(p_password) < 10 then
    raise exception 'Le mot de passe d''un compte MTC doit compter au moins 10 caractères.';
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
  -- La preuve est faite : le compteur et les blocages repartent de zéro.
  delete from public.password_reset_guard where user_id = v_uid;

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

notify pgrst, 'reload schema';
