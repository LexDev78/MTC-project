-- Lot 7 : commentaires produit, avis, chat, notifications.

-- ----------------------------------------------------------------------------
-- notifications : aucune policy INSERT n'existait encore. `add()` est
-- systématiquement appelé pour prévenir un AUTRE compte que l'appelant (le
-- fournisseur d'une commande, le client dont l'avis vient d'être publié...) —
-- il n'existe pas de règle de propriété étroite possible ici, contrairement
-- aux commentaires/messages de chat (toujours scopés à un thread précis dont
-- l'appelant est déjà participant). Une notification n'a aucune valeur
-- exploitable au-delà de son propre affichage (titre/corps/type), donc
-- laisser n'importe quel compte authentifié en créer une pour n'importe qui
-- reste un risque mineur (spam de la liste, pas une fuite ni un accès) —
-- même arbitrage que les policies INSERT déjà ouvertes sur les commentaires.
-- ----------------------------------------------------------------------------
create policy "notifications_insert_authenticated" on public.notifications
  for insert with check (true);

-- ----------------------------------------------------------------------------
-- chat : contrairement aux commentaires/avis/notifications ("notify after my
-- own write" suffit, chaque session ne lit que ce qu'elle vient d'écrire ou
-- relit au prochain écran), un fil de discussion doit apparaître en direct
-- côté destinataire — deux sessions différentes (client / fournisseur)
-- doivent voir les messages de l'autre sans naviguer hors de l'écran. Même
-- besoin que les commandes au Lot 5, même remède : Realtime Postgres.
-- ----------------------------------------------------------------------------
alter publication supabase_realtime add table public.chat_messages;
alter publication supabase_realtime add table public.chat_conversations;
