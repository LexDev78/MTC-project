-- Les fonctions de test quittent les migrations.
--
-- Signalé par l'audit : elles étaient déployées en production. `0039` les
-- verrouillait — plus aucun rôle ne pouvait les appeler —, mais quatre
-- d'entre elles, ajoutées après, avaient gardé leur droit pour
-- `service_role` : `test_reset_ai_scratch`, `test_reset_courier_dossier`,
-- `test_live_app_sessions`, `test_assert_mail_sandbox`. Et une fonction
-- verrouillée reste une fonction présente : la ré-accorder par mégarde
-- suffit à rendre `test_reset_and_seed()` — `truncate table auth.users …
-- cascade` — appelable avec la clé de service de production.
--
-- Elles sont supprimées ici, partout. Le fichier `supabase/seeds/test_helpers.sql`
-- les recrée, et il n'est joué que par `supabase db reset` (`[db.seed]` dans
-- `config.toml`) : en local seulement. En production, `db push` rejoue les
-- anciennes migrations qui les créent, puis celle-ci qui les retire.
--
-- Désormais, un helper de test se modifie dans `seeds/test_helpers.sql`, et
-- jamais dans une migration.

drop function if exists public.test_adjust_stock(text,integer);
drop function if exists public.test_assert_mail_sandbox();
drop function if exists public.test_clear_supplier_pickup_point(uuid);
drop function if exists public.test_fetch_account_deletion_state(uuid);
drop function if exists public.test_fetch_courier_status(uuid);
drop function if exists public.test_fetch_device_tokens_for_user(uuid);
drop function if exists public.test_fetch_group_status(text);
drop function if exists public.test_fetch_notifications_for_user(uuid);
drop function if exists public.test_fetch_stock_movements(text);
drop function if exists public.test_give_product_a_variant(text,integer,integer);
drop function if exists public.test_insert_notification(uuid,text,text,text,text);
drop function if exists public.test_live_app_sessions(text);
drop function if exists public.test_reset_ai_scratch();
drop function if exists public.test_reset_and_seed();
drop function if exists public.test_reset_courier_dossier(uuid);
drop function if exists public.test_seed_couriers();
drop function if exists public.test_seed_delivered_delivery(text,uuid);
drop function if exists public.test_seed_supplier_pickup_points();
drop function if exists public.test_set_group_delivery_mode(text,text);
drop function if exists public.test_set_group_status(text,text);

notify pgrst, 'reload schema';
