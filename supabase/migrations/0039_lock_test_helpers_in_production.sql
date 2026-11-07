-- Neutralise les RPC réservées aux tests partout sauf en local.
--
-- Pourquoi : ces fonctions vivent dans `supabase/migrations/`, donc
-- `supabase db push` les installe aussi sur le projet hébergé — y compris
-- `test_reset_and_seed()`, dont le corps est
-- `truncate table auth.users, public.suppliers, ... cascade`. En production
-- elle efface tous les comptes et toutes les données avant de réinjecter le
-- jeu de démo. Elle est `security definer` (donc exécutée avec les droits du
-- propriétaire) et était accordée à `service_role` : la clé `service_role`
-- de production, ou n'importe quel script pointé par erreur sur le mauvais
-- environnement, suffisait à vider la base.
--
-- Le correctif retire le droit d'exécution à TOUS les rôles, `service_role`
-- compris. Les fonctions restent présentes (pas de `drop` : l'historique des
-- migrations doit rester rejouable à l'identique) mais plus personne ne peut
-- les appeler via l'API.
--
-- En local, `supabase/seed.sql` les ré-autorise juste après — et ce fichier
-- n'est joué que par `supabase db reset`, jamais par `db push` (vérifié :
-- la sortie de push rapporte `"seeds":[]`). C'est donc le seul
-- environnement où elles redeviennent utilisables, par construction plutôt
-- que par convention.
--
-- À ajouter ici si une nouvelle RPC de test apparaît — et à ré-accorder
-- symétriquement dans `seed.sql`.

revoke all on function public.test_reset_and_seed()
  from public, anon, authenticated, service_role;

revoke all on function public.test_fetch_stock_movements(text)
  from public, anon, authenticated, service_role;

revoke all on function public.test_adjust_stock(text, int)
  from public, anon, authenticated, service_role;

revoke all on function public.test_fetch_notifications_for_user(uuid)
  from public, anon, authenticated, service_role;

revoke all on function public.test_give_product_a_variant(text, integer, integer)
  from public, anon, authenticated, service_role;

revoke all on function public.test_fetch_device_tokens_for_user(uuid)
  from public, anon, authenticated, service_role;

revoke all on function public.test_fetch_account_deletion_state(uuid)
  from public, anon, authenticated, service_role;
