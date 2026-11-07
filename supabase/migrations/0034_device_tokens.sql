-- Tokens FCM par appareil, pour l'envoi de notifications push réelles (app
-- fermée/arrière-plan) — voir /Users/solomon/.claude/plans/fluffy-sauteeing-pudding.md.
--
-- `notifications.user_id` a deux formes (voir le commentaire de
-- `AppNotification` et `operating_supplier_id()` dans 0001_initial_schema.sql) :
-- un `profiles.id` littéral pour un client/fournisseur tiers, ou l'uuid MTC
-- partagé pour le staff (`supplier_principal`), vu par tout agent/admin qui
-- opère la même vitrine. `device_tokens`, lui, est toujours ancré sur
-- l'`auth.uid()` réel de qui tient l'appareil — jamais sur cet uuid partagé.
-- `get_device_tokens_for_notification_user()` fait donc le fan-out inverse :
-- reçoit un `notifications.user_id` (les deux formes), retourne tous les
-- tokens des appareils qui doivent être notifiés.
-- `id` gets a server-side default (unlike `notifications.id`, always
-- app-supplied) because a row here is upserted by `fcm_token`, not always
-- freshly inserted — the client never sends `id` at all, so an `on conflict
-- (fcm_token) do update` leaves the existing row's `id` untouched instead of
-- pointlessly rotating it on every token refresh.
create table public.device_tokens (
  id text primary key default gen_random_uuid()::text,
  user_id uuid not null references public.profiles (id) on delete cascade,
  fcm_token text not null unique,
  platform text not null default 'android' check (platform in ('android', 'ios')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create index device_tokens_user_id_idx on public.device_tokens (user_id);

-- `security definer`/`service_role`-only, même famille que
-- `test_fetch_notifications_for_user()` (0007) : seule l'Edge Function
-- d'envoi (authentifiée en `service_role`) a besoin de lire les tokens d'un
-- destinataire — jamais un client, d'où l'absence totale de grant vers
-- `anon`/`authenticated` (contrairement à `device_tokens` elle-même, qui
-- reste lisible/écrivable par son propriétaire via RLS classique plus bas).
create or replace function public.get_device_tokens_for_notification_user(p_user_id uuid)
returns table(fcm_token text)
language sql
security definer
set search_path = public
as $$
  select dt.fcm_token
  from public.device_tokens dt
  where dt.user_id = p_user_id
     or (
       p_user_id = '3331cbb4-0a65-5f94-9812-fe4270e50fe2'::uuid
       and dt.user_id in (select id from public.profiles where role = 'supplier_principal')
     );
$$;

revoke all on function public.get_device_tokens_for_notification_user(uuid) from public, anon, authenticated;
grant execute on function public.get_device_tokens_for_notification_user(uuid) to service_role;

-- Appelée par l'Edge Function quand FCM répond `UNREGISTERED`/`NOT_FOUND`
-- pour un token (app désinstallée, token périmé) — sans ceci les tokens
-- morts s'accumulent et chaque futur envoi gaspille un appel dessus.
create or replace function public.prune_device_token(p_fcm_token text)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.device_tokens where fcm_token = p_fcm_token;
$$;

revoke all on function public.prune_device_token(text) from public, anon, authenticated;
grant execute on function public.prune_device_token(text) to service_role;

alter table public.device_tokens enable row level security;

create policy "device_tokens_select_own" on public.device_tokens
  for select using (user_id = auth.uid());
create policy "device_tokens_insert_own" on public.device_tokens
  for insert with check (user_id = auth.uid());
create policy "device_tokens_update_own" on public.device_tokens
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "device_tokens_delete_own" on public.device_tokens
  for delete using (user_id = auth.uid());

-- Pas de grant à `anon` : un token n'a aucune raison d'être lisible avant
-- connexion, contrairement au catalogue/aux profils publics.
grant select, insert, update, delete on public.device_tokens to authenticated;
