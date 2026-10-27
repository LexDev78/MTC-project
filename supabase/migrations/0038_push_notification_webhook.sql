-- Déclencheur d'envoi des notifications push : chaque insertion dans
-- `notifications` appelle l'Edge Function `send-push-notification`, qui
-- résout les appareils du destinataire et passe par FCM.
--
-- Accroché sur `notifications` plutôt que sur les neuf actions qui créent
-- une notification (commande, message, statut, commentaire, stock, KYC,
-- retrait, avis, caractéristique) : toutes passent déjà par ce seul point
-- d'insertion (`NotificationRepository.add`), donc rien à câbler par
-- fonctionnalité, et une dixième à l'avenir sera couverte gratuitement.
--
-- Pourquoi une migration plutôt qu'un clic dans Studio (option proposée par
-- Supabase) : un webhook configuré à la main disparaît au moindre
-- `supabase db reset` et doit être recréé à l'identique sur chaque
-- environnement, en silence quand on l'oublie. Ici l'URL et le secret
-- varient par environnement sans que le code change — voir plus bas.
--
-- `net.http_post` (extension `pg_net`, déjà installée) est asynchrone : la
-- requête est mise en file, la transaction qui insère la notification n'est
-- jamais retardée ni bloquée par l'envoi du push.

create or replace function public.notify_push_on_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text;
  v_secret text;
begin
  -- Réglages par environnement, posés une fois par base :
  --   alter database postgres set app.push_function_url = 'https://<ref>.supabase.co/functions/v1/send-push-notification';
  --   alter database postgres set app.push_function_secret = '<service_role_key>';
  -- Les valeurs par défaut ci-dessous ciblent le stack local : `supabase
  -- functions serve` écoute sur l'hôte, que le conteneur Postgres joint via
  -- `host.docker.internal`, et la clé `service_role` locale est fixe et
  -- publique (le CLI la dérive d'un JWT_SECRET connu — elle est déjà en
  -- clair dans `test/support/supabase_test_harness.dart`).
  v_url := coalesce(
    current_setting('app.push_function_url', true),
    'http://host.docker.internal:54321/functions/v1/send-push-notification'
  );
  v_secret := coalesce(
    current_setting('app.push_function_secret', true),
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU'
  );

  -- Le secret authentifie l'appel auprès de la fonction, qui refuse tout
  -- POST sans lui (sinon n'importe qui pourrait pousser un texte arbitraire
  -- sur le téléphone de n'importe quel compte — l'usurpation que
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

-- `after insert` seulement : une mise à jour sur cette table est un accusé
-- de lecture (`is_read`), qui ne doit surtout pas repousser la notification.
drop trigger if exists notifications_send_push on public.notifications;
create trigger notifications_send_push
  after insert on public.notifications
  for each row execute function public.notify_push_on_notification();

revoke all on function public.notify_push_on_notification() from public, anon, authenticated;
