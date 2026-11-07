-- Index sur les colonnes que les lectures chaudes filtrent et joignent.
--
-- 42 clés étrangères du schéma n'en avaient aucun. Postgres n'en crée pas
-- pour une clé étrangère (contrairement aux clés primaires) : sans index, un
-- `where group_id = ...` parcourt la table entière. Sur le jeu de
-- démonstration, le planificateur préfère de toute façon le parcours
-- séquentiel — c'est en production, quand `order_items` et `chat_messages`
-- pèsent des centaines de milliers de lignes, que la différence se voit, et
-- elle est alors de plusieurs ordres de grandeur.
--
-- Toutes ne sont pas ici : chaque index ralentit les écritures et occupe de
-- la place. Celles retenues servent une requête que l'app exécute vraiment,
-- nommée en commentaire. Les autres (pièces de dossier KYC, auteurs de
-- commentaires d'avis, types de caractéristiques) restent sans index tant
-- qu'aucune lecture fréquente ne les filtre.
--
-- En production, les créer avec `concurrently` hors migration : un
-- `create index` ordinaire verrouille la table en écriture le temps de sa
-- construction.

-- Commandes : chaque ouverture de commande descend order -> groupes ->
-- lignes, et chaque liste remonte par le client ou le fournisseur.
create index if not exists orders_client_idx
  on public.orders (client_id, placed_at desc);
create index if not exists order_supplier_groups_order_idx
  on public.order_supplier_groups (order_id);
create index if not exists order_supplier_groups_supplier_idx
  on public.order_supplier_groups (supplier_id);
create index if not exists order_items_group_idx
  on public.order_items (group_id);
-- `get_supplier_product_stats` (nombre de commandes par produit) et le
-- rattachement d'un avis à un produit (`fetch_product_reviews`, `0061`).
create index if not exists order_items_product_idx
  on public.order_items (product_id);

-- Panier et favoris : lus à chaque ouverture de l'app.
create index if not exists cart_items_user_idx
  on public.cart_items (user_id);
create index if not exists favorites_user_idx
  on public.favorites (user_id);
-- Compteur de « j'aime » par produit (`get_supplier_product_stats`).
create index if not exists favorites_product_idx
  on public.favorites (product_id);

-- Messagerie : le fil se lit par conversation et par ordre d'envoi — c'est
-- la table qui grossit le plus vite de tout le schéma.
create index if not exists chat_messages_conversation_idx
  on public.chat_messages (conversation_id, sent_at);
create index if not exists chat_conversations_client_idx
  on public.chat_conversations (client_id, last_message_at desc);
create index if not exists chat_conversations_supplier_idx
  on public.chat_conversations (supplier_id, last_message_at desc);

-- Notifications : la cloche lit « les miennes, les plus récentes d'abord ».
-- `user_id` n'est même pas une clé étrangère ici, donc rien ne l'indexait.
create index if not exists notifications_user_idx
  on public.notifications (user_id, created_at desc);

-- Catalogue public : `status = 'active' and is_supplier_verified` filtre
-- **toutes** les requêtes clientes (`products_select_public` et
-- `watchProducts`). Index partiel : il ne contient que les lignes visibles,
-- donc il reste petit même quand le catalogue grandit en brouillons et en
-- produits archivés.
create index if not exists products_public_catalog_idx
  on public.products (category, rating_average desc)
  where status = 'active' and is_supplier_verified;
-- « Mes produits », la vitrine d'un fournisseur, et la recopie de sa note.
create index if not exists products_supplier_idx
  on public.products (supplier_id);

-- Avis : la liste du fournisseur, le cumul de sa note, et le « ai-je déjà
-- noté cette commande ? » du client.
create index if not exists reviews_supplier_idx
  on public.reviews (supplier_id, created_at desc);
create index if not exists reviews_group_idx
  on public.reviews (supplier_group_id);

-- Questions sous une fiche produit.
create index if not exists product_comments_product_idx
  on public.product_comments (product_id, created_at desc);

-- Historique de stock d'un produit.
create index if not exists stock_movements_product_idx
  on public.stock_movements (product_id, occurred_at desc);

-- Adresses de livraison d'un compte, lues à chaque paiement.
create index if not exists addresses_user_idx
  on public.addresses (user_id);

-- Course rattachée à une commande (écrans client et fournisseur).
create index if not exists deliveries_order_idx
  on public.deliveries (order_id);

-- Demandes de versement d'un fournisseur.
create index if not exists payout_requests_supplier_idx
  on public.payout_requests (supplier_id, requested_at desc);
