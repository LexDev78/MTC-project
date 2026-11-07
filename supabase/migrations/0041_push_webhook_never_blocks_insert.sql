-- Deux correctifs sur le déclencheur d'envoi des push, tous deux révélés en
-- testant sur le projet hébergé.
--
-- 1) `pg_net` n'est pas installée par défaut sur un projet Supabase hébergé
--    (elle l'est en local). Sans elle, `net.http_post` n'existe pas, le
--    trigger lève `3F000: schema "net" does not exist`, et comme un trigger
--    `after insert` s'exécute dans la transaction de l'insertion, c'est
--    l'INSERT lui-même qui échoue : plus aucune notification ne peut être
--    créée. Un canal secondaire cassé bloquait la fonctionnalité
--    principale.
--
-- 2) Même une fois l'extension en place, l'envoi reste faillible (réseau,
--    fonction indisponible, secret Vault absent…). Le `perform` est donc
--    enveloppé : toute erreur est avalée et journalisée en `warning`, et la
--    notification est enregistrée quoi qu'il arrive. C'est la même règle
--    que côté application — `SupabaseNotificationRepository.add()` avale
--    déjà ses échecs pour qu'un push manqué ne fasse jamais échouer la
--    commande, le message ou le changement de statut qui l'a déclenché.

create extension if not exists pg_net with schema extensions;

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

    -- Repli sur le stack local : `supabase functions serve` écoute sur
    -- l'hôte, que le conteneur Postgres joint via `host.docker.internal`,
    -- et la clé `service_role` locale est fixe et publique (dérivée d'un
    -- JWT_SECRET connu du CLI — déjà en clair dans
    -- `test/support/supabase_test_harness.dart`).
    v_url := coalesce(
      v_url,
      'http://host.docker.internal:54321/functions/v1/send-push-notification'
    );
    v_secret := coalesce(
      v_secret,
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU'
    );

    -- Le secret authentifie l'appel auprès de la fonction, qui refuse tout
    -- POST sans lui — sinon n'importe qui pourrait pousser un texte
    -- arbitraire sur le téléphone de n'importe quel compte (l'usurpation
    -- fermée côté RLS par
    -- `0033_fix_notification_spoofing_payout_amount_and_upload_limits.sql`).
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
      -- Jamais `raise exception` ici : on est dans la transaction de
      -- l'INSERT, la faire échouer perdrait la notification elle-même.
      raise warning 'push webhook ignoré (notification % conservée) : %',
        new.id, sqlerrm;
  end;

  return new;
end;
$$;

revoke all on function public.notify_push_on_notification() from public, anon, authenticated;
