-- Les index de `0067`, à créer sur une base **déjà chargée**.
--
-- Pourquoi un fichier à part plutôt qu'une migration : `CREATE INDEX`
-- ordinaire verrouille la table en écriture pendant toute la construction.
-- Sur une base vide c'est instantané ; sur `order_items` ou `chat_messages`
-- en production, c'est une interruption de service de plusieurs minutes.
--
-- `CONCURRENTLY` construit l'index sans ce verrou, mais **ne peut pas
-- s'exécuter dans une transaction** — donc pas dans une migration Supabase,
-- qui en ouvre une. D'où ce fichier, à passer à la main :
--
--   psql "$DATABASE_URL" -f supabase/production/indexes_concurrently.sql
--
-- À exécuter **avant** d'appliquer `0067` sur une base chargée : les
-- `if not exists` font alors de la migration une formalité sans verrou.
-- Sur une base neuve, ne rien faire : `0067` suffit.
--
-- Un `CREATE INDEX CONCURRENTLY` interrompu laisse un index `invalid`, qui
-- ne sert à rien mais pèse sur les écritures. Pour les retrouver :
--
--   select indexrelid::regclass from pg_index where not indisvalid;
--
-- puis `drop index concurrently <nom>;` avant de relancer.

create index concurrently if not exists orders_client_idx
  on public.orders (client_id, placed_at desc);

create index concurrently if not exists order_supplier_groups_order_idx
  on public.order_supplier_groups (order_id);

create index concurrently if not exists order_supplier_groups_supplier_idx
  on public.order_supplier_groups (supplier_id);

create index concurrently if not exists order_items_group_idx
  on public.order_items (group_id);

create index concurrently if not exists order_items_product_idx
  on public.order_items (product_id);

create index concurrently if not exists cart_items_user_idx
  on public.cart_items (user_id);

create index concurrently if not exists favorites_user_idx
  on public.favorites (user_id);

create index concurrently if not exists favorites_product_idx
  on public.favorites (product_id);

create index concurrently if not exists chat_messages_conversation_idx
  on public.chat_messages (conversation_id, sent_at);

create index concurrently if not exists chat_conversations_client_idx
  on public.chat_conversations (client_id, last_message_at desc);

create index concurrently if not exists chat_conversations_supplier_idx
  on public.chat_conversations (supplier_id, last_message_at desc);

create index concurrently if not exists notifications_user_idx
  on public.notifications (user_id, created_at desc);

create index concurrently if not exists products_public_catalog_idx
  on public.products (category, rating_average desc)
  where status = 'active' and is_supplier_verified;

create index concurrently if not exists products_supplier_idx
  on public.products (supplier_id);

create index concurrently if not exists reviews_supplier_idx
  on public.reviews (supplier_id, created_at desc);

create index concurrently if not exists reviews_group_idx
  on public.reviews (supplier_group_id);

create index concurrently if not exists product_comments_product_idx
  on public.product_comments (product_id, created_at desc);

create index concurrently if not exists stock_movements_product_idx
  on public.stock_movements (product_id, occurred_at desc);

create index concurrently if not exists addresses_user_idx
  on public.addresses (user_id);

create index concurrently if not exists deliveries_order_idx
  on public.deliveries (order_id);

create index concurrently if not exists payout_requests_supplier_idx
  on public.payout_requests (supplier_id, requested_at desc);
