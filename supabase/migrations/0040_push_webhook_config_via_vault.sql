-- Remplace la configuration du webhook push par Vault.
--
-- `0038_push_notification_webhook.sql` lisait l'URL et le secret via
-- `current_setting('app.push_function_url')`, posés par
-- `alter database postgres set ...`. Ça marche en local, mais Supabase
-- hébergé refuse cette commande (`42501: permission denied to set
-- parameter`) : le rôle de connexion n'a pas les privilèges nécessaires.
-- La configuration était donc impossible à appliquer en production.
--
-- Vault (`supabase_vault`, présent en local comme en hébergé) est le
-- mécanisme prévu pour ça, et chiffre les valeurs au repos — le secret
-- stocké ici est la clé `service_role`, donc ce n'est pas un détail.
--
-- Les valeurs par défaut (stack local) restent en repli, pour que
-- `supabase db reset` donne une base fonctionnelle sans aucune étape
-- manuelle. En production, les deux secrets Vault sont posés une fois :
--   select vault.create_secret('<url>',    'push_function_url');
--   select vault.create_secret('<secret>', 'push_function_secret');

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
  select decrypted_secret into v_url
  from vault.decrypted_secrets
  where name = 'push_function_url';

  select decrypted_secret into v_secret
  from vault.decrypted_secrets
  where name = 'push_function_secret';

  -- Repli sur le stack local : `supabase functions serve` écoute sur
  -- l'hôte, que le conteneur Postgres joint via `host.docker.internal`, et
  -- la clé `service_role` locale est fixe et publique (dérivée d'un
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
  -- arbitraire sur le téléphone de n'importe quel compte (l'usurpation que
  -- `0033_fix_notification_spoofing_payout_amount_and_upload_limits.sql` a
  -- fermée côté RLS).
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

  return new;
end;
$$;

revoke all on function public.notify_push_on_notification() from public, anon, authenticated;
