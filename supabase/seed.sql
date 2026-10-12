-- MTC — données de démo (Lot 1).
--
-- Le contenu réel du seed vit dans `public.test_reset_and_seed()`
-- (migration `0002_test_reset_fn.sql`) pour rester la source unique de
-- vérité : ce fichier (exécuté automatiquement par `supabase db reset`)
-- se contente de l'appeler, et le harnais de test (Lot 3,
-- `test/support/supabase_test_harness.dart`) appellera la même fonction
-- via RPC entre les tests pour repartir d'un état propre.
--
-- Voir `0002_test_reset_fn.sql` pour le détail du port de chaque
-- `_seedXxx()` des 14 `InMemoryXxxDatasource` (comptes réels via
-- auth.users, produits, commandes, chat, commentaires, KYC, avis,
-- retraits...).
-- Ré-autorise les RPC de test, que `0039_lock_test_helpers_in_production.sql`
-- vient de retirer à tout le monde. Ce fichier n'est joué que par
-- `supabase db reset` — jamais par `supabase db push` — donc c'est
-- exactement, et uniquement, l'environnement local qui les retrouve. Voir
-- `0039` pour le détail : sans ce verrou, `test_reset_and_seed()` (qui fait
-- un `truncate ... cascade` sur `auth.users`) était appelable en production
-- avec la clé `service_role`.
grant execute on function public.test_reset_and_seed() to service_role;
grant execute on function public.test_fetch_stock_movements(text) to service_role;
grant execute on function public.test_adjust_stock(text, int) to service_role;
grant execute on function public.test_fetch_notifications_for_user(uuid) to service_role;
grant execute on function public.test_give_product_a_variant(text, integer, integer) to service_role;
grant execute on function public.test_fetch_device_tokens_for_user(uuid) to service_role;
grant execute on function public.test_fetch_account_deletion_state(uuid) to service_role;
grant execute on function public.test_seed_couriers() to service_role;
grant execute on function public.test_set_group_status(text, text) to service_role;
grant execute on function public.test_seed_supplier_pickup_points() to service_role;
grant execute on function public.test_clear_supplier_pickup_point(uuid) to service_role;
grant execute on function public.test_fetch_group_status(text) to service_role;
grant execute on function public.test_fetch_courier_status(uuid) to service_role;
grant execute on function public.test_set_group_delivery_mode(text, text) to service_role;

select public.test_reset_and_seed();
-- Les comptes livreurs vivent dans leur propre helper (voir
-- `0047_test_seed_couriers.sql`), appelé juste après le seed principal.
select public.test_seed_couriers();
-- Adresses de retrait des fournisseurs : sans elles, aucune commande ne peut
-- être confiée à la livraison MTC (voir `0050`).
select public.test_seed_supplier_pickup_points();
grant execute on function public.test_insert_notification(uuid, text, text, text, text) to service_role;
