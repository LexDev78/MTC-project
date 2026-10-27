-- RPC locale-only, test uniquement : lit les tokens d'appareil d'UN AUTRE
-- utilisateur que la session en cours, en contournant la RLS
-- (`device_tokens_select_own` exige `user_id = auth.uid()`) — même pattern
-- que `test_fetch_notifications_for_user()` (0007_test_notification_helper.sql).
create or replace function public.test_fetch_device_tokens_for_user(p_user_id uuid)
returns setof public.device_tokens
language sql
security definer
set search_path = public
as $$
  select * from public.device_tokens where user_id = p_user_id order by created_at desc;
$$;

revoke all on function public.test_fetch_device_tokens_for_user(uuid) from public, anon, authenticated;
grant execute on function public.test_fetch_device_tokens_for_user(uuid) to service_role;
