-- 0148 — Les messages et leurs fichiers ne bougent plus une fois envoyés
-- (trouvé en corrigeant l'audit du 27/10/2026, le 05/11/2026).
--
--  1. `order-messages` : la note vocale du client à ses boutiques
--     (`checkout_controller.dart`, dossier = la commande). La policy unique
--     `order_messages_visible` valait pour tout (FOR ALL) : chaque boutique
--     d'une commande à plusieurs boutiques pouvait remplacer ou effacer la
--     note que les autres écoutent. Lire reste ouvert à la même audience ;
--     déposer, au seul client de la commande ; rien ne se remplace ni ne
--     s'efface depuis l'app.
--  2. `chat-attachments` : la ligne d'un message envoyé est immuable
--     (`guard_chat_message_immutable`), mais pas son fichier — l'expéditeur
--     le remplaçait sous le même nom, ou l'effaçait. Plus de remplacement ;
--     un fichier ne s'efface que s'il n'est rattaché à aucun message.
--  3. `review-media` et `comment-attachments` sont publics en lecture, et
--     leur policy de lecture laissait n'importe quel compte *lister* le
--     bucket : les dossiers portent l'identifiant de chaque client qui a
--     publié une photo. L'app ne liste jamais ces buckets (elle construit
--     l'URL publique, `ResolvedImage`) : lister est réservé à l'auteur.
--  4. `chat_messages` : l'expéditeur écrivait lui-même `sent_at`, `is_read`
--     et la carte produit jointe (nom, prix, photo, variante) — une boutique
--     pouvait montrer au client le produit d'une autre à un prix inventé.
--     La base les pose : la date est celle de l'envoi, la carte décrit un
--     produit de la boutique de la conversation, tel qu'il est en base.

-- ----------------------------------------------------- 1. les notes vocales
drop policy if exists order_messages_visible on storage.objects;

create policy order_messages_read on storage.objects
  for select using (
    bucket_id = 'order-messages'
    and exists (
      select 1 from public.orders o
       where o.id = (storage.foldername(objects.name))[1]
         and (o.client_id = auth.uid()
              or exists (select 1 from public.order_supplier_groups g
                          where g.order_id = o.id
                            and g.supplier_id = public.operating_supplier_id()
                            and public.supplier_can('orders'))
              or public.is_admin())
    )
  );

create policy order_messages_client_write on storage.objects
  for insert with check (
    bucket_id = 'order-messages'
    and exists (
      select 1 from public.orders o
       where o.id = (storage.foldername(objects.name))[1]
         and o.client_id = auth.uid()
    )
  );

-- --------------------------------------------- 2. les pièces jointes du chat
drop policy if exists chat_attachments_owner_manage on storage.objects;

drop policy if exists chat_attachments_owner_delete on storage.objects;
create policy chat_attachments_owner_delete on storage.objects
  for delete using (
    bucket_id = 'chat-attachments'
    and owner = auth.uid()
    and not exists (
      select 1 from public.chat_messages m where m.attachment_path = objects.name
    )
  );

-- ------------------------------------------------- 3. lister un bucket public
drop policy if exists review_media_public_read on storage.objects;
create policy review_media_author_list on storage.objects
  for select to authenticated using (
    bucket_id = 'review-media'
    and (storage.foldername(name))[1] = (auth.uid())::text
  );

drop policy if exists comment_attachments_public_read on storage.objects;
create policy comment_attachments_author_list on storage.objects
  for select to authenticated using (
    bucket_id = 'comment-attachments'
    and ((storage.foldername(name))[1] = (auth.uid())::text
         or (storage.foldername(name))[1] = (public.operating_supplier_id())::text)
  );

-- -------------------------------------------------- 4. ce que dit un message
create or replace function public.stamp_chat_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supplier_id uuid;
  v_product record;
  -- Deux scalaires plutôt qu'un `record` : sans variante, un `record` jamais
  -- affecté ne se lit pas (« not assigned yet »), et la carte serait refusée.
  v_variant_name text;
  v_variant_images text[];
begin
  if auth.uid() is null then
    return new;  -- semis
  end if;

  new.sent_at := now();
  new.is_read := false;

  if new.product_id is null then
    new.product_variant_id := null;
    new.product_name_snapshot := null;
    new.product_price_fcfa_snapshot := null;
    new.product_image_snapshot := null;
    new.product_variant_name_snapshot := null;
    return new;
  end if;

  select c.supplier_id into v_supplier_id
    from public.chat_conversations c where c.id = new.conversation_id;
  select p.id, p.name, p.supplier_id, p.has_variants, p.image_urls,
         (p.status = 'active' and p.is_supplier_verified and s.deleted_at is null) as public
    into v_product
    from public.products p
    join public.suppliers s on s.id = p.supplier_id
   where p.id = new.product_id;
  if v_product.id is null or v_product.supplier_id is distinct from v_supplier_id then
    raise exception 'Ce produit n''est pas vendu par la boutique de cette conversation.';
  end if;
  -- Le client ne montre que ce qui est en vente : sa carte recopiait le
  -- nom, le prix et la photo d'un brouillon (contre-vérification du
  -- 06/11/2026). La boutique, elle, peut parler de ses propres produits.
  if not v_product.public
     and v_supplier_id is distinct from public.operating_supplier_id() then
    raise exception 'Ce produit n''est pas en vente.';
  end if;

  if new.product_variant_id is not null then
    select v.name, v.image_urls into v_variant_name, v_variant_images
      from public.product_variants v
     where v.id = new.product_variant_id and v.product_id = new.product_id;
    if not found then
      raise exception 'Cette variante n''appartient pas à ce produit.';
    end if;
  end if;

  new.product_name_snapshot := v_product.name;
  new.product_variant_name_snapshot := v_variant_name;
  new.product_price_fcfa_snapshot :=
    public.effective_unit_price_fcfa(new.product_id, new.product_variant_id, 1);
  new.product_image_snapshot := coalesce(v_variant_images[1], v_product.image_urls[1]);
  return new;
end;
$$;

revoke all on function public.stamp_chat_message() from public, anon, authenticated;

-- Nommé pour passer avant `chat_messages_closed_guard` (ordre alphabétique) :
-- l'ordre n'importe pas ici, aucun des deux ne lit ce que l'autre écrit.
drop trigger if exists chat_messages_stamp on public.chat_messages;
create trigger chat_messages_stamp
  before insert on public.chat_messages
  for each row execute function public.stamp_chat_message();

-- Le nom affiché du client sur une conversation : celui du profil, jamais
-- celui de la requête, même quand le profil n'en a pas. Reprise de la
-- définition en vigueur, le repli seul changé.
create or replace function public.chat_conversation_defaults()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  new.closed_at := null;
  new.client_display_name_snapshot := coalesce(
    (select nullif(btrim(p.display_name), '') from public.profiles p where p.id = new.client_id),
    'Client'
  );
  new.supplier_name := coalesce(
    (select s.business_name from public.suppliers s where s.id = new.supplier_id),
    new.supplier_name
  );
  return new;
end;
$function$;
