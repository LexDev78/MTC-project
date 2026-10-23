-- Le client peut fermer une conversation : la boutique ne peut plus lui écrire.
--
-- Une fois la commande livrée, la boutique n'a plus ni le numéro ni l'adresse
-- du client (`0120`) ; il lui reste l'application pour lui écrire. Cette porte
-- doit être au client : il la ferme, et rien de la boutique ne lui parvient
-- plus. Il la rouvre en écrivant lui-même, ou d'un geste.
--
-- « Rien ne lui parvient » se mesure sur tous les chemins par lesquels une
-- boutique atteignait le client, pas seulement sur l'envoi d'un message :
--
--  * un message (`chat_messages`) : refusé par un déclencheur quand la
--    conversation est fermée, quel que soit le chemin d'écriture ;
--  * une pièce jointe déposée dans le dossier de la conversation : refusée
--    par la policy du bucket ;
--  * l'aperçu et les compteurs de `chat_conversations` : l'application les
--    écrivait elle-même, avec un droit de mise à jour sur la ligne. Une
--    boutique pouvait donc mettre n'importe quel texte en aperçu dans la
--    liste du client, et allumer son compteur de non-lus, sans envoyer de
--    message. Ils sont maintenant tenus par la base, à l'insertion d'un
--    message, et plus personne n'écrit cette table directement ;
--  * une nouvelle conversation pour repartir de zéro : une seule par client
--    et par boutique (index unique), plus aucune suppression (elle effaçait
--    au passage les messages de l'autre), et une boutique n'en ouvre qu'avec
--    un client qui lui a commandé.
--
-- Les noms affichés (`client_display_name_snapshot`, `supplier_name`) étaient
-- fournis par l'application à la création : une boutique pouvait s'y
-- présenter sous le nom qu'elle voulait. Ils sont repris des comptes.

alter table public.chat_conversations
  add column closed_at timestamptz;

create unique index chat_conversations_client_supplier_key
  on public.chat_conversations (client_id, supplier_id);

-- ---- qui ouvre une conversation -------------------------------------------

-- Vrai si le client a déjà commandé à la boutique de l'appelant. Sans
-- paramètre de boutique : on ne peut interroger que pour soi.
create or replace function public.can_open_conversation_with_client(p_client_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.order_supplier_groups g
      join public.orders o on o.id = g.order_id
     where g.supplier_id = public.operating_supplier_id()
       and o.client_id = p_client_id
  );
$$;

revoke all on function public.can_open_conversation_with_client(uuid) from public, anon;
grant execute on function public.can_open_conversation_with_client(uuid) to authenticated;

drop policy if exists chat_conversations_all_participants on public.chat_conversations;

create policy chat_conversations_select_participants on public.chat_conversations
  for select
  using (
    client_id = auth.uid()
    or (supplier_id = public.operating_supplier_id() and public.supplier_can('messages'))
  );

create policy chat_conversations_insert_client on public.chat_conversations
  for insert
  with check (client_id = auth.uid());

create policy chat_conversations_insert_supplier on public.chat_conversations
  for insert
  with check (
    supplier_id = public.operating_supplier_id()
    and public.supplier_can('messages')
    and public.can_open_conversation_with_client(client_id)
  );

-- Aucune policy de mise à jour ni de suppression : tout passe par les
-- déclencheurs et les fonctions plus bas.
revoke insert, update, delete on public.chat_conversations from authenticated;
grant insert (id, client_id, client_display_name_snapshot, supplier_id, supplier_name)
  on public.chat_conversations to authenticated;

-- Une conversation naît ouverte, sous les vrais noms.
create or replace function public.chat_conversation_defaults()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.closed_at := null;
  new.client_display_name_snapshot := coalesce(
    (select p.display_name from public.profiles p where p.id = new.client_id),
    new.client_display_name_snapshot
  );
  new.supplier_name := coalesce(
    (select s.business_name from public.suppliers s where s.id = new.supplier_id),
    new.supplier_name
  );
  return new;
end;
$$;

drop trigger if exists chat_conversations_defaults on public.chat_conversations;
create trigger chat_conversations_defaults
  before insert on public.chat_conversations
  for each row execute function public.chat_conversation_defaults();

-- Les participants ne changent pas, et seul le client ouvre ou ferme. Le
-- second verrou, comme en `0102` : il tient même face à une fonction
-- `security definer` écrite plus tard.
create or replace function public.guard_chat_conversation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.id is distinct from old.id
     or new.client_id is distinct from old.client_id
     or new.supplier_id is distinct from old.supplier_id then
    raise exception 'Une conversation ne change pas de participants.';
  end if;
  if new.closed_at is distinct from old.closed_at
     and auth.uid() is not null
     and auth.uid() is distinct from old.client_id then
    raise exception 'Seul le client ferme ou rouvre une conversation.';
  end if;
  return new;
end;
$$;

drop trigger if exists chat_conversations_guard on public.chat_conversations;
create trigger chat_conversations_guard
  before update on public.chat_conversations
  for each row execute function public.guard_chat_conversation();

-- ---- fermer, rouvrir --------------------------------------------------------

-- `p_closed` à vrai ferme, à faux rouvre. Rend la date de fermeture, `null`
-- une fois rouverte. Même message pour une conversation inconnue et pour
-- celle d'un autre : ne rien apprendre de ce qui ne nous regarde pas.
create or replace function public.set_my_conversation_closed(
  p_conversation_id text,
  p_closed boolean
)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ferme timestamptz;
begin
  if auth.uid() is null then
    raise exception 'Connectez-vous pour gérer vos conversations.';
  end if;

  update public.chat_conversations
     set closed_at = case when p_closed then coalesce(closed_at, now()) end
   where id = p_conversation_id
     and client_id = auth.uid()
  returning closed_at into v_ferme;
  if not found then
    raise exception 'Conversation introuvable.';
  end if;

  return v_ferme;
end;
$$;

revoke all on function public.set_my_conversation_closed(text, boolean) from public, anon;
grant execute on function public.set_my_conversation_closed(text, boolean) to authenticated;

-- ---- écrire dans une conversation fermée ------------------------------------

-- La boutique est arrêtée ; le client, lui, rouvre en écrivant — écrire à
-- quelqu'un, c'est lui permettre de répondre. Le verrou de ligne sérialise
-- l'envoi avec une fermeture simultanée.
create or replace function public.guard_closed_conversation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_client uuid;
  v_ferme timestamptz;
begin
  select c.client_id, c.closed_at into v_client, v_ferme
    from public.chat_conversations c
   where c.id = new.conversation_id
   for update;

  if v_ferme is null then
    return new;
  end if;
  if new.sender_id = v_client then
    update public.chat_conversations set closed_at = null where id = new.conversation_id;
    return new;
  end if;
  raise exception 'Ce client a fermé la conversation : vous ne pouvez plus lui écrire.';
end;
$$;

drop trigger if exists chat_messages_closed_guard on public.chat_messages;
create trigger chat_messages_closed_guard
  before insert on public.chat_messages
  for each row execute function public.guard_closed_conversation();

-- ---- aperçu et compteurs, tenus par la base ---------------------------------

-- Ce que `SupabaseChatDatasource.sendMessage` calculait côté application :
-- le même aperçu, la même date, le compteur du destinataire. Sans session
-- (le jeu de démonstration), rien ne bouge : il pose lui-même ses valeurs.
create or replace function public.chat_message_touch_conversation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_client uuid;
  v_apercu text;
begin
  if auth.uid() is null then
    return new;
  end if;

  select c.client_id into v_client
    from public.chat_conversations c
   where c.id = new.conversation_id;
  if v_client is null then
    return new;
  end if;

  v_apercu := case
    when new.attachment_type = 'image' then '📷 Photo'
    when new.attachment_type = 'voice' then '🎤 Message vocal'
    when new.product_name_snapshot is not null then '📦 ' || new.product_name_snapshot
    else new.text
  end;

  update public.chat_conversations
     set last_message_preview = coalesce(v_apercu, ''),
         last_message_at = now(),
         unread_count_supplier = unread_count_supplier
           + case when new.sender_id = v_client then 1 else 0 end,
         unread_count_client = unread_count_client
           + case when new.sender_id = v_client then 0 else 1 end
   where id = new.conversation_id;
  return new;
end;
$$;

drop trigger if exists chat_messages_touch_conversation on public.chat_messages;
create trigger chat_messages_touch_conversation
  after insert on public.chat_messages
  for each row execute function public.chat_message_touch_conversation();

-- Lire une conversation : remet à zéro le compteur de son côté, et marque lus
-- les messages de l'autre côté — pas les siens, que l'autre n'a pas lus.
-- Une boutique lit aussi une conversation fermée : c'est écrire qu'on lui
-- retire, pas relire.
create or replace function public.mark_my_conversation_read(p_conversation_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_client uuid;
  v_shop uuid;
begin
  if auth.uid() is null then
    raise exception 'Connectez-vous pour lire vos conversations.';
  end if;

  select c.client_id, c.supplier_id into v_client, v_shop
    from public.chat_conversations c
   where c.id = p_conversation_id;

  if v_client is not null and v_client = auth.uid() then
    update public.chat_conversations set unread_count_client = 0
     where id = p_conversation_id and unread_count_client <> 0;
    update public.chat_messages set is_read = true
     where conversation_id = p_conversation_id
       and sender_id <> v_client
       and not is_read;
  elsif v_shop is not null
        and v_shop = public.operating_supplier_id()
        and public.supplier_can('messages') then
    update public.chat_conversations set unread_count_supplier = 0
     where id = p_conversation_id and unread_count_supplier <> 0;
    update public.chat_messages set is_read = true
     where conversation_id = p_conversation_id
       and sender_id = v_client
       and not is_read;
  else
    raise exception 'Conversation introuvable.';
  end if;
end;
$$;

revoke all on function public.mark_my_conversation_read(text) from public, anon;
grant execute on function public.mark_my_conversation_read(text) to authenticated;

-- ---- pièces jointes ---------------------------------------------------------

-- Reprise de la policy d'écriture du bucket, avec deux ajouts : la permission
-- `messages` pour un collaborateur (la lecture de la conversation l'exigeait
-- déjà, pas le dépôt), et la fermeture.
drop policy if exists chat_attachments_write on storage.objects;
create policy chat_attachments_write on storage.objects
  for insert
  with check (
    bucket_id = 'chat-attachments'
    and exists (
      select 1 from public.chat_conversations c
       where c.id = (storage.foldername(objects.name))[1]
         and (
           c.client_id = auth.uid()
           or (
             c.supplier_id = public.operating_supplier_id()
             and public.supplier_can('messages')
             and c.closed_at is null
           )
         )
    )
  );

notify pgrst, 'reload schema';
