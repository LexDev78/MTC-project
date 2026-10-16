-- Le droit « messages », tenu lui aussi.
--
-- `0094` a branché `supplier_can()` sur le catalogue, les remises, la
-- vitrine et les avis. Les conversations y avaient échappé : leur règle
-- passe par une table de participants, et je ne voulais pas y toucher sans
-- l'avoir lue. La voici lue.
--
-- Sans ce fichier, un collaborateur à qui l'on n'avait accordé que
-- « produits » lisait et écrivait quand même toutes les conversations de la
-- boutique — ce que les clients y racontent, leurs adresses, leurs numéros.
--
-- ## Lire et écrire vont ensemble
--
-- On aurait pu n'interdire que l'envoi, en laissant la lecture. Ce serait
-- une demi-mesure : la permission « messages » désigne l'onglet entier, et
-- ce qu'un client confie à la boutique n'a pas à circuler plus loin que
-- ceux qui s'en occupent.
--
-- ## Les définitions sont reprises telles qu'elles vivent
--
-- Pas telles qu'une ancienne migration les a écrites. Trois fois dans cette
-- série, recopier une règle depuis la migration qui l'a créée a défait une
-- correction posée depuis — dont une faille de sécurité. La branche client
-- est donc intacte, au caractère près ; seule la branche fournisseur gagne
-- une condition.

drop policy if exists "chat_conversations_all_participants" on public.chat_conversations;
create policy "chat_conversations_all_participants" on public.chat_conversations
  for all
  using (
    client_id = auth.uid()
    or (
      supplier_id = public.operating_supplier_id()
      and public.supplier_can('messages')
    )
  )
  with check (
    client_id = auth.uid()
    or (
      supplier_id = public.operating_supplier_id()
      and public.supplier_can('messages')
    )
  );

drop policy if exists "chat_messages_select_participants" on public.chat_messages;
create policy "chat_messages_select_participants" on public.chat_messages
  for select using (
    exists (
      select 1 from public.chat_conversations c
       where c.id = chat_messages.conversation_id
         and (
           c.client_id = auth.uid()
           or (
             c.supplier_id = public.operating_supplier_id()
             and public.supplier_can('messages')
           )
         )
    )
  );

drop policy if exists "chat_messages_insert_participants" on public.chat_messages;
create policy "chat_messages_insert_participants" on public.chat_messages
  for insert with check (
    (
      sender_id = auth.uid()
      or (
        sender_id = public.operating_supplier_id()
        and public.supplier_can('messages')
      )
    )
    and exists (
      select 1 from public.chat_conversations c
       where c.id = chat_messages.conversation_id
         and (
           c.client_id = auth.uid()
           or (
             c.supplier_id = public.operating_supplier_id()
             and public.supplier_can('messages')
           )
         )
    )
  );

drop policy if exists "chat_messages_update_participants" on public.chat_messages;
create policy "chat_messages_update_participants" on public.chat_messages
  for update using (
    exists (
      select 1 from public.chat_conversations c
       where c.id = chat_messages.conversation_id
         and (
           c.client_id = auth.uid()
           or (
             c.supplier_id = public.operating_supplier_id()
             and public.supplier_can('messages')
           )
         )
    )
  );
