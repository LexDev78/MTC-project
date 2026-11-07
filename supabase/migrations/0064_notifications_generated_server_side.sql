-- Les notifications sont désormais écrites par la base, plus par l'app.
--
-- `notifications_insert_authenticated` laissait **tout compte connecté**
-- insérer une notification pour **n'importe quel destinataire**, avec le
-- type, le titre et le texte de son choix — seuls trois types de décisions
-- staff étaient réservés (`0033`). De quoi écrire à n'importe qui « Votre
-- commande est bloquée, appelez le 70 00 00 00 », à l'échelle, depuis
-- l'intérieur de l'app.
--
-- La policy était large parce que l'app émettait elle-même : après avoir
-- passé commande, elle notifiait le fournisseur ; après avoir envoyé un
-- message, le destinataire ; etc. Impossible de distinguer dans un
-- `with check` une notification légitime d'une forgée, puisque les deux
-- viennent de la même session et ont la même forme.
--
-- Donc on retire la raison : chaque notification est produite par
-- l'événement qui la justifie, dans la même transaction que lui. Un compte
-- connecté n'insère plus rien.
--
-- Trois effets secondaires, tous souhaitables :
--
--  * un aller-retour réseau de moins par action (commande, message,
--    commentaire, changement de statut) ;
--  * plus de notification orpheline : l'app pouvait échouer entre l'écriture
--    et la notification (les deux appels `try/catch` de `ChatController` et
--    `CommentController` avalaient d'ailleurs l'échec en silence) ;
--  * le client est enfin prévenu quand un **livreur** clôt sa commande par
--    un scan — jusqu'ici la notification venait du bouton du fournisseur,
--    retiré depuis `0054`.

-- Libellés de statut, identiques à `OrderStatus.label` côté app : c'est le
-- texte que le client a déjà lu dans ses commandes.
create or replace function public.order_status_label(p_status public.order_status)
returns text
language sql
immutable
set search_path = public
as $$
  select case p_status
    when 'pending' then 'En attente'
    when 'confirmed' then 'Confirmée'
    when 'preparing' then 'En préparation'
    when 'in_transit' then 'En livraison'
    when 'delivered' then 'Livrée'
    when 'cancelled' then 'Annulée'
  end;
$$;

create or replace function public.notify_order_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_client_id uuid;
begin
  if new.status is not distinct from old.status then return new; end if;

  -- Une annulation par le client n'a pas à lui être annoncée : il vient de
  -- la demander.
  if new.status = 'cancelled' and new.cancelled_by = 'client' then
    return new;
  end if;

  select o.client_id into v_client_id from public.orders o where o.id = new.order_id;
  if v_client_id is null then return new; end if;

  insert into public.notifications (id, user_id, type, title, body, reference_id)
  values (
    gen_random_uuid()::text,
    v_client_id,
    'order_status_update',
    'Commande ' || new.supplier_name,
    case
      when new.status = 'cancelled' and coalesce(new.cancellation_reason, '') <> ''
        then 'Votre commande a été refusée : ' || new.cancellation_reason
      else 'Votre commande est maintenant : '
           || lower(public.order_status_label(new.status)) || '.'
    end,
    new.order_id
  );
  return new;
end;
$$;

create trigger order_supplier_groups_notify_status
  after update of status on public.order_supplier_groups
  for each row execute function public.notify_order_status_change();

create or replace function public.notify_new_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recipient uuid;
  v_client uuid;
  v_supplier uuid;
begin
  select c.client_id, c.supplier_id into v_client, v_supplier
    from public.chat_conversations c where c.id = new.conversation_id;
  if v_client is null then return new; end if;

  v_recipient := case when new.sender_id = v_client then v_supplier else v_client end;
  if v_recipient is null or v_recipient = new.sender_id then return new; end if;

  -- Même aperçu que celui que l'app composait : le texte s'il y en a, sinon
  -- ce qui a été joint.
  insert into public.notifications (id, user_id, type, title, body, reference_id)
  values (
    gen_random_uuid()::text, v_recipient, 'new_message', 'Nouveau message',
    coalesce(
      nullif(btrim(coalesce(new.text, '')), ''),
      case
        when new.product_name_snapshot is not null
          then '📦 ' || new.product_name_snapshot
        when new.attachment_type = 'image' then '📷 Photo'
        when new.attachment_type = 'voice' then '🎤 Message vocal'
        else 'Nouveau message'
      end
    ),
    new.conversation_id
  );
  return new;
end;
$$;

create trigger chat_messages_notify
  after insert on public.chat_messages
  for each row execute function public.notify_new_message();

create or replace function public.notify_new_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recipient uuid;
begin
  -- Un commentaire de premier niveau s'adresse au vendeur ; une réponse
  -- s'adresse à celui qu'on cite.
  if new.parent_id is null then
    v_recipient := new.supplier_id;
  else
    select author_id into v_recipient
      from public.product_comments where id = new.parent_id;
  end if;

  if v_recipient is null or v_recipient = new.author_id then return new; end if;

  insert into public.notifications (id, user_id, type, title, body, reference_id)
  values (
    gen_random_uuid()::text, v_recipient, 'new_comment', 'Nouveau commentaire',
    coalesce(nullif(btrim(coalesce(new.text, '')), ''), 'Nouveau commentaire'),
    new.product_id
  );
  return new;
end;
$$;

create trigger product_comments_notify
  after insert on public.product_comments
  for each row execute function public.notify_new_comment();

create or replace function public.notify_low_stock()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.low_stock_threshold is null then return new; end if;
  if new.stock_quantity is not distinct from old.stock_quantity then return new; end if;
  if new.stock_quantity > new.low_stock_threshold then return new; end if;

  insert into public.notifications (id, user_id, type, title, body, reference_id)
  values (
    gen_random_uuid()::text, new.supplier_id, 'low_stock', 'Stock faible',
    new.name || ' : ' || new.stock_quantity || ' en stock',
    new.id
  );
  return new;
end;
$$;

-- Sur `stock_quantity` et non sur toute la ligne : sans cette restriction,
-- le déclencheur s'exécuterait à chaque modification de libellé ou de prix.
--
-- Il couvre maintenant les ventes autant que les corrections manuelles —
-- c'est précisément quand le stock part en commandes qu'un fournisseur veut
-- l'apprendre, et l'app ne le disait que sur ajustement manuel.
create trigger products_notify_low_stock
  after update of stock_quantity on public.products
  for each row execute function public.notify_low_stock();

-- Plus personne n'insère de notification depuis une session cliente. Les
-- trois décisions du staff (dossier, versement, type de caractéristique)
-- restent écrites par l'app staff, comme avant.
drop policy if exists "notifications_insert_authenticated" on public.notifications;

create policy "notifications_insert_staff_only" on public.notifications
  for insert with check (public.is_staff());
