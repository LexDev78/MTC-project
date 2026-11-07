-- Un participant pouvait réécrire les mots de l'autre.
--
-- `chat_messages_update_participants` n'exige que d'appartenir à la
-- conversation, et `authenticated` avait le droit de mettre à jour **toutes**
-- les colonnes de la table. Une politique `update` sans `with_check` réutilise
-- son `using` pour contrôler la ligne écrite : être participant suffisait donc
-- à modifier n'importe quelle colonne de n'importe quel message, y compris
-- ceux envoyés par l'autre.
--
-- Mesuré sur la base, dans une transaction annulée — le fournisseur agissant
-- sur le message du client :
--
--   update chat_messages set text = '...' where id = '60c32d08-…';  -- UPDATE 1
--   update chat_messages set sender_id = '<client>' where id = '6f8c…';  -- UPDATE 1
--
-- Autrement dit : réécrire ce que l'acheteur a demandé, et faire dire à
-- l'acheteur ce qu'il n'a pas dit. Sur une place de marché où la
-- conversation **est** la trace de l'accord — « je prends 3 pièces à
-- 15 000 » —, c'est la preuve de la commande qui devient malléable. Un
-- collaborateur ayant la permission `messages` en héritait aussi.
--
-- Ce que l'application écrit réellement sur cette table : une insertion à
-- l'envoi, et `is_read` à la lecture (`markConversationRead`,
-- `supabase_chat_datasource.dart`). Rien d'autre. Le droit accordé était donc
-- vingt fois plus large que l'usage.
--
-- Deux verrous, parce qu'ils n'arrêtent pas la même chose :
--
--  * le droit de colonne arrête la requête directe — Postgres refuse un
--    `update` qui nomme une colonne non accordée, avant toute politique ;
--  * le déclencheur arrête le chemin qui contourne les droits, c'est-à-dire
--    une fonction `security definer` écrite plus tard. C'est exactement ainsi
--    que les gardes de collaborateur ont été posées (`0097`) : la politique
--    pour la requête, le déclencheur pour le reste.

-- 1. Le droit de colonne : seule `is_read` reste modifiable.
revoke update on public.chat_messages from authenticated;
grant update (is_read) on public.chat_messages to authenticated;

-- 2. Le déclencheur : le fond d'un message ne change plus, par aucun chemin.
--
-- Le staff n'est pas exempté. Il n'a aucune raison de récrire un échange
-- entre deux tiers, et s'en exempter rendrait le garde contournable par le
-- rôle le plus puissant — ce qui revient à ne pas l'avoir.
create or replace function public.guard_chat_message_immutable()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.sender_id is distinct from old.sender_id then
    raise exception 'L''expéditeur d''un message ne se change pas.';
  end if;
  if new.text is distinct from old.text then
    raise exception 'Le texte d''un message envoyé ne se réécrit pas.';
  end if;
  if new.conversation_id is distinct from old.conversation_id then
    raise exception 'Un message ne change pas de conversation.';
  end if;
  if new.attachment_path is distinct from old.attachment_path
     or new.attachment_type is distinct from old.attachment_type then
    raise exception 'La pièce jointe d''un message envoyé ne se remplace pas.';
  end if;
  if new.sent_at is distinct from old.sent_at then
    raise exception 'L''horodatage d''envoi ne se réécrit pas.';
  end if;
  return new;
end;
$$;

drop trigger if exists chat_messages_immutable on public.chat_messages;
create trigger chat_messages_immutable
  before update on public.chat_messages
  for each row execute function public.guard_chat_message_immutable();
