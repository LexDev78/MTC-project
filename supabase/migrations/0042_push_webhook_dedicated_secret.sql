-- Bascule le secret du webhook push vers une valeur dédiée.
--
-- Jusqu'ici le trigger envoyait la clé `service_role` et la fonction la
-- comparait à son `SUPABASE_SERVICE_ROLE_KEY`. Deux problèmes, le second
-- constaté en production (401 renvoyé par la fonction) :
--
-- 1) Moindre privilège : cette clé ouvre toute la base. En confier une
--    copie à un webhook qui n'a besoin que de s'authentifier est excessif.
-- 2) Sa valeur n'est pas stable : un projet peut utiliser les anciennes
--    clés JWT ou le format récent `sb_secret_...`, et la valeur injectée
--    dans la fonction hébergée ne correspondait pas à celle lisible via
--    l'API de gestion. La comparaison échouait donc systématiquement.
--
-- Désormais : un secret propre au webhook, posé des deux côtés — dans Vault
-- (lu ici) et dans les secrets de la fonction, sous `PUSH_WEBHOOK_SECRET`.
-- En local, le repli ci-dessous et `supabase/functions/.env` partagent la
-- même valeur de développement, pour que `supabase db reset` reste
-- fonctionnel sans aucune étape manuelle.

create or replace function public.notify_push_on_notification()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
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

    -- Repli local : `supabase functions serve` écoute sur l'hôte, que le
    -- conteneur Postgres joint via `host.docker.internal`. Le secret de
    -- repli n'est pas sensible — il n'ouvre que la fonction locale, et doit
    -- rester identique à `PUSH_WEBHOOK_SECRET` dans
    -- `supabase/functions/.env` (voir `.env.example`).
    v_url := coalesce(
      v_url,
      'http://host.docker.internal:54321/functions/v1/send-push-notification'
    );
    v_secret := coalesce(v_secret, 'local-dev-push-secret');

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
$$;

revoke all on function public.notify_push_on_notification() from public, anon, authenticated;
