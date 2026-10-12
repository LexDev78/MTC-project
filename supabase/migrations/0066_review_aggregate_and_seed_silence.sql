-- Deux ajustements aux deux migrations précédentes, trouvés en les testant.
--
-- 1. La moyenne d'un fournisseur se **cumule**, elle ne se recalcule pas.
--
-- `0063` recalculait `rating_average` depuis `reviews`. C'est plus vrai en
-- théorie, et faux ici : le jeu de données attribue à chaque fournisseur un
-- historique de notes (4,6 sur 132 avis) sans ligne d'avis correspondante.
-- Recalculer depuis la table ramenait ce fournisseur à « 5,0 sur 1 avis »
-- et effaçait son historique au premier avis déposé.
--
-- Le cumul revient donc, mais **dans l'instruction** et non plus en
-- lecture-modification-écriture côté app. C'était là le vrai défaut du code
-- d'origine : deux clients notant en même temps lisaient le même
-- `rating_count`, et le second écrasait le premier. Fait en un seul
-- `update`, la ligne est verrouillée et les deux avis comptent.
--
-- 2. Rejouer un historique n'envoie pas de notifications.
--
-- Les déclencheurs de `0064` se déclenchent aussi pendant
-- `test_reset_and_seed`, qui insère des conversations et des commandes déjà
-- anciennes : chaque message du jeu de démonstration produisait une
-- notification « Nouveau message ». Même raisonnement que
-- `guard_supplier_verification_status` (`0029`) : `auth.uid()` est nul pour
-- toute connexion sans JWT utilisateur — le semis, `service_role`, tout
-- outillage d'administration. Une notification correspond à l'action d'une
-- personne ; sans session, il n'y a pas d'action à annoncer.

create or replace function public.submit_review(
  p_order_id text,
  p_supplier_group_id text,
  p_stars integer,
  p_comment text,
  p_image_paths text[] default '{}',
  p_video_path text default null
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_client uuid := auth.uid();
  v_supplier_id uuid;
  v_group_status public.order_status;
  v_review_id text := gen_random_uuid()::text;
  v_average double precision;
  v_count integer;
begin
  if v_client is null then
    raise exception 'Vous devez être connecté pour laisser un avis.';
  end if;
  if p_stars is null or p_stars < 1 or p_stars > 5 then
    raise exception 'Une note va de 1 à 5 étoiles.';
  end if;
  if coalesce(btrim(p_comment), '') = '' then
    raise exception 'Un avis doit comporter un commentaire.';
  end if;

  select g.supplier_id, g.status into v_supplier_id, v_group_status
    from public.order_supplier_groups g
    join public.orders o on o.id = g.order_id
   where g.id = p_supplier_group_id
     and g.order_id = p_order_id
     and o.client_id = v_client;

  if v_supplier_id is null then
    raise exception 'Commande introuvable, ou elle n''est pas la vôtre.';
  end if;
  if v_group_status <> 'delivered' then
    raise exception 'Vous pourrez noter cette commande une fois livrée.';
  end if;
  if exists (
    select 1 from public.reviews
     where order_id = p_order_id and supplier_group_id = p_supplier_group_id
  ) then
    raise exception 'Vous avez déjà noté cette commande.';
  end if;

  insert into public.reviews (
    id, order_id, supplier_group_id, client_id, supplier_id,
    stars, comment, image_paths, video_path
  ) values (
    v_review_id, p_order_id, p_supplier_group_id, v_client, v_supplier_id,
    p_stars, btrim(p_comment), coalesce(p_image_paths, '{}'), p_video_path
  );

  -- Le cumul se fait dans l'instruction : la ligne est verrouillée le temps
  -- du calcul, donc deux avis simultanés comptent tous les deux.
  update public.suppliers
     set rating_average =
           ((rating_average * rating_count) + p_stars) / (rating_count + 1),
         rating_count = rating_count + 1
   where id = v_supplier_id
   returning rating_average, rating_count into v_average, v_count;

  -- Recopie dénormalisée sur les produits, pour que le tri du catalogue
  -- n'ait pas à joindre `suppliers`.
  update public.products
     set rating_average = v_average, rating_count = v_count
   where supplier_id = v_supplier_id;

  insert into public.notifications (id, user_id, type, title, body, reference_id)
  values (
    gen_random_uuid()::text, v_supplier_id, 'new_review', 'Nouvel avis',
    p_stars || '★ — ' || btrim(p_comment), v_review_id
  );

  return v_review_id;
end;
$$;

revoke all on function public.submit_review(text, text, integer, text, text[], text)
  from public, anon;
grant execute on function public.submit_review(text, text, integer, text, text[], text)
  to authenticated;

-- Les quatre déclencheurs n'annoncent que des actions de personnes.
create or replace function public.notify_order_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_client_id uuid;
begin
  if auth.uid() is null then return new; end if;
  if new.status is not distinct from old.status then return new; end if;
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
  if auth.uid() is null then return new; end if;

  select c.client_id, c.supplier_id into v_client, v_supplier
    from public.chat_conversations c where c.id = new.conversation_id;
  if v_client is null then return new; end if;

  v_recipient := case when new.sender_id = v_client then v_supplier else v_client end;
  if v_recipient is null or v_recipient = new.sender_id then return new; end if;

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

create or replace function public.notify_new_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recipient uuid;
begin
  if auth.uid() is null then return new; end if;

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

create or replace function public.notify_low_stock()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then return new; end if;
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

-- Les tests ont besoin de poser des notifications pour vérifier ce qui
-- s'affiche et ce qui se marque comme lu. Ils ne peuvent plus passer par
-- une session cliente, et c'est le but.
create or replace function public.test_insert_notification(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_reference_id text default null
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id text := gen_random_uuid()::text;
begin
  insert into public.notifications (id, user_id, type, title, body, reference_id)
  values (v_id, p_user_id, p_type::public.notification_type, p_title, p_body, p_reference_id);
  return v_id;
end;
$$;

revoke all on function public.test_insert_notification(uuid, text, text, text, text)
  from public, anon, authenticated;
