-- RPC locale-only, test uniquement : lit les notifications d'UN AUTRE
-- utilisateur que la session en cours, en contournant la RLS
-- (`notifications_select_own` exige `user_id = auth.uid() or user_id =
-- operating_supplier_id()`). Plusieurs tests d'intégration vérifient
-- qu'une action déclenchée par un compte (passer commande, répondre à un
-- avis, décider un dossier KYC/retrait...) crée bien une notification pour
-- le DESTINATAIRE, sans pour autant vouloir se reconnecter comme ce
-- destinataire juste pour lire le résultat — même pattern que
-- `test_fetch_stock_movements()` (`0004_test_admin_helpers.sql`).
create or replace function public.test_fetch_notifications_for_user(p_user_id uuid)
returns setof public.notifications
language sql
security definer
set search_path = public
as $$
  select * from public.notifications where user_id = p_user_id order by created_at desc;
$$;

revoke all on function public.test_fetch_notifications_for_user(uuid) from public, anon, authenticated;
grant execute on function public.test_fetch_notifications_for_user(uuid) to service_role;
