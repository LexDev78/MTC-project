-- RPC locale-only, test uniquement : lit l'état de suppression d'UN AUTRE
-- compte que la session en cours, en contournant la RLS
-- (`profiles_select_own`/`suppliers_select_public` exigent respectivement
-- `id = auth.uid()` et `deleted_at is null` — cette dernière condition rend
-- justement un compte supprimé invisible via le chemin normal, ce qui est le
-- but, mais empêche un test de vérifier directement le résultat) — même
-- pattern que `test_fetch_notifications_for_user()`
-- (`0007_test_notification_helper.sql`).
create or replace function public.test_fetch_account_deletion_state(p_user_id uuid)
returns table(profile_deleted_at timestamptz, supplier_deleted_at timestamptz)
language sql
security definer
set search_path = public
as $$
  select
    (select deleted_at from public.profiles where id = p_user_id),
    (select deleted_at from public.suppliers where id = p_user_id);
$$;

revoke all on function public.test_fetch_account_deletion_state(uuid) from public, anon, authenticated;
grant execute on function public.test_fetch_account_deletion_state(uuid) to service_role;
