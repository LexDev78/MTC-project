-- 0151 — Huit caractères au moins pour tout mot de passe (fiche de mise en
-- production, point ouvert depuis l'audit du 25/10/2026 : « mot de passe
-- minimum à 6 caractères » ; audit du 27/10/2026, point 9).
--
-- Six caractères, c'est le plancher de Supabase Auth, et un mot de passe
-- qu'un script épuise vite : les comptes MTC ouvrent un portefeuille, des
-- commandes, des conversations privées. La règle passe à huit partout où
-- elle s'écrit : `config.toml` (Supabase Auth en local ; sur le projet
-- hébergé, le réglage du tableau de bord, voir `MISE_EN_PRODUCTION.md`),
-- l'app (`Validators.password`, écrans de changement), et ici la
-- réinitialisation par code, qui pose le mot de passe elle-même. Le staff
-- garde ses dix caractères (`0135`).
--
-- Les mots de passe déjà choisis ne sont pas touchés : la règle joue au
-- prochain changement.
--
-- Reprise de la définition en vigueur (`0132`), ce contrôle seul changé.

CREATE OR REPLACE FUNCTION public.reset_password_with_code(p_identifiant text, p_code text, p_password text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
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
  if char_length(coalesce(p_password, '')) < 8 then
    raise exception 'Le mot de passe doit compter au moins 8 caractères.';
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
$function$;
