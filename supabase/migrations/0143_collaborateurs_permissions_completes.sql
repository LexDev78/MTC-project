-- 0143 — Un collaborateur ne lit et n'écrit que ce que ses cases lui
-- ouvrent (audit du 27/10/2026, faille 6, élargie à tout ce qu'un relevé
-- complet des policies a montré le 05/11/2026).
--
-- L'audit citait cinq policies : un collaborateur créé avec la seule case
-- « messages » lisait toutes les commandes de la boutique (montants,
-- lignes), et modifiait les options de caractéristiques (`price_delta_fcfa`
-- compris) et de variantes. Le relevé de toutes les policies qui
-- s'appuient sur `operating_supplier_id()` sans `supplier_can()` en a
-- trouvé d'autres, du même défaut :
--
--   * les notifications de la boutique : tout collaborateur, même sans
--     aucune case, lisait celles du patron — montants des versements,
--     motifs de refus du dossier, texte des messages des clients — et
--     pouvait les réécrire ou les détourner vers lui
--     (`update notifications set user_id = auth.uid()`), la table entière
--     étant modifiable ;
--   * les courses (`deliveries`), les avis complets (`reviews`, avec le
--     client), les lignes de codes promo utilisés, l'historique de stock
--     (modifiable et effaçable, même par le patron), les propositions de
--     types de caractéristiques, les pièces jointes des conversations, et
--     les fichiers des commentaires déposés au nom de la boutique.
--
-- Chaque chemin prend la case qui correspond à l'onglet de l'app
-- (`route_guards.dart`) : commandes, produits (la boîte des commentaires
-- y est), remises, messages, avis. L'argent et le dossier restent au seul
-- patron. Le client, le livreur et le staff ne sont pas concernés : leurs
-- branches de chaque policy sont reprises telles quelles.

-- ------------------------------------------------------------- commandes
drop policy if exists orders_select_visible on public.orders;
create policy orders_select_visible on public.orders
  for select using (
    client_id = auth.uid()
    or (public.order_has_group_for_supplier(id, public.operating_supplier_id())
        and public.supplier_can('orders'))
    or public.is_admin()
  );

drop policy if exists order_supplier_groups_select_visible on public.order_supplier_groups;
create policy order_supplier_groups_select_visible on public.order_supplier_groups
  for select using (
    (supplier_id = public.operating_supplier_id() and public.supplier_can('orders'))
    or public.order_belongs_to_me(order_id)
    or public.is_admin()
  );

drop policy if exists order_items_select_visible on public.order_items;
create policy order_items_select_visible on public.order_items
  for select using (
    exists (
      select 1 from public.order_supplier_groups g
       where g.id = order_items.group_id
         and ((g.supplier_id = public.operating_supplier_id() and public.supplier_can('orders'))
              or public.order_belongs_to_me(g.order_id)
              or public.is_admin())
    )
  );

drop policy if exists deliveries_select_participants on public.deliveries;
create policy deliveries_select_participants on public.deliveries
  for select using (
    public.is_staff()
    or courier_id = auth.uid()
    or offered_to_courier_id = auth.uid()
    or exists (select 1 from public.orders o
                where o.id = deliveries.order_id and o.client_id = auth.uid())
    or (public.supplier_can('orders')
        and exists (select 1 from public.order_supplier_groups g
                     where g.id = deliveries.supplier_group_id
                       and g.supplier_id = public.operating_supplier_id()))
  );

-- --------------------------------------------------------------- produits
drop policy if exists product_characteristic_options_write_own on public.product_characteristic_options;
create policy product_characteristic_options_write_own on public.product_characteristic_options
  for all using (
    public.supplier_can('products')
    and exists (select 1 from public.product_characteristics c
                  join public.products p on p.id = c.product_id
                 where c.id = product_characteristic_options.characteristic_id
                   and p.supplier_id = public.operating_supplier_id())
  ) with check (
    public.supplier_can('products')
    and exists (select 1 from public.product_characteristics c
                  join public.products p on p.id = c.product_id
                 where c.id = product_characteristic_options.characteristic_id
                   and p.supplier_id = public.operating_supplier_id())
  );

drop policy if exists product_variant_options_write_own on public.product_variant_options;
create policy product_variant_options_write_own on public.product_variant_options
  for all using (
    public.supplier_can('products')
    and exists (select 1 from public.product_variants v
                  join public.products p on p.id = v.product_id
                 where v.id = product_variant_options.variant_id
                   and p.supplier_id = public.operating_supplier_id())
  ) with check (
    public.supplier_can('products')
    and exists (select 1 from public.product_variants v
                  join public.products p on p.id = v.product_id
                 where v.id = product_variant_options.variant_id
                   and p.supplier_id = public.operating_supplier_id())
  );

-- L'historique de stock se lit et s'ajoute ; il ne se réécrit pas — ni par
-- un collaborateur (le déclencheur ne gardait que l'INSERT), ni par le
-- patron : une correction est un nouveau mouvement, pas l'effacement de
-- l'ancien.
drop policy if exists stock_movements_all_own_product on public.stock_movements;
create policy stock_movements_select_own_product on public.stock_movements
  for select using (
    public.supplier_can('products')
    and exists (select 1 from public.products p
                 where p.id = stock_movements.product_id
                   and p.supplier_id = public.operating_supplier_id())
  );
create policy stock_movements_insert_own_product on public.stock_movements
  for insert with check (
    public.supplier_can('products')
    and exists (select 1 from public.products p
                 where p.id = stock_movements.product_id
                   and p.supplier_id = public.operating_supplier_id())
  );
revoke update, delete on public.stock_movements from anon, authenticated;

drop policy if exists characteristic_types_insert_supplier on public.product_characteristic_types;
create policy characteristic_types_insert_supplier on public.product_characteristic_types
  for insert with check (
    status = 'pending'
    and proposed_by_supplier_id = public.operating_supplier_id()
    and public.supplier_can('products')
  );

-- Déposer un fichier de commentaire au nom de la boutique : la case
-- produits, comme écrire le commentaire lui-même (`0140`).
drop policy if exists comment_attachments_author_write on storage.objects;
create policy comment_attachments_author_write on storage.objects
  for insert with check (
    bucket_id = 'comment-attachments'
    and ((storage.foldername(name))[1] = (auth.uid())::text
         or ((storage.foldername(name))[1] = (public.operating_supplier_id())::text
             and public.supplier_can('products')))
  );

-- ---------------------------------------------------------- remises, avis
drop policy if exists promo_code_redemption_items_visible on public.promo_code_redemption_items;
create policy promo_code_redemption_items_visible on public.promo_code_redemption_items
  for select using (
    exists (
      select 1 from public.promo_code_redemptions r
       where r.id = promo_code_redemption_items.redemption_id
         and (r.client_id = auth.uid()
              or (public.supplier_can('promotions')
                  and exists (select 1 from public.promo_codes c
                               where c.id = r.promo_code_id
                                 and c.supplier_id = public.operating_supplier_id())))
    )
  );

drop policy if exists reviews_select_parties on public.reviews;
create policy reviews_select_parties on public.reviews
  for select using (
    client_id = auth.uid()
    or (supplier_id = public.operating_supplier_id() and public.supplier_can('reviews'))
    or public.is_staff()
  );

-- Le badge vendeur sous un avis : la case « avis », comme la réponse
-- officielle (`reviews_update_own_supplier`). Sans elle, un collaborateur
-- commente en son nom, sans badge. Reprise de la définition en vigueur
-- (`0134`), seule la décision du badge changée.
create or replace function public.stamp_review_comment_author()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_supplier_id uuid;
begin
  -- L'auteur est l'appelant, quoi qu'en dise la requête.
  new.author_id := auth.uid();
  if new.author_id is null then
    raise exception 'Vous devez être connecté pour commenter un avis.';
  end if;

  select p.display_name into new.author_display_name_snapshot
    from public.profiles p where p.id = new.author_id;

  select r.supplier_id into v_supplier_id
    from public.reviews r where r.id = new.review_id;
  if v_supplier_id is null then
    raise exception 'Avis introuvable : %', new.review_id;
  end if;
  -- La boutique notée répond avec son badge, si ce compte a la case
  -- « avis » ; un client (ou le staff) commente en son nom ; personne
  -- d'autre — un livreur ou une autre boutique n'a pas à parler sous cet
  -- avis (`is_client`, `0140`).
  if v_supplier_id is not distinct from public.operating_supplier_id() then
    if not public.supplier_can('reviews') then
      raise exception 'Votre compte n''a pas accès aux avis de cette boutique.';
    end if;
    new.author_is_supplier := true;
  elsif public.is_client() or public.is_staff() then
    new.author_is_supplier := false;
  else
    raise exception 'Seul un client, ou la boutique notée, commente un avis.';
  end if;

  perform public.validate_media_paths(new.image_paths, new.author_id, 4);
  if new.video_path is not null then
    perform public.validate_media_paths(
      array[new.video_path], new.author_id, 1
    );
  end if;

  if tg_op = 'UPDATE' then
    new.created_at := old.created_at;
    new.updated_at := now();
  end if;
  return new;
end;
$function$;

-- --------------------------------------------------------------- messages
drop policy if exists chat_attachments_read on storage.objects;
create policy chat_attachments_read on storage.objects
  for select using (
    bucket_id = 'chat-attachments'
    and exists (
      select 1 from public.chat_conversations c
       where c.id = (storage.foldername(objects.name))[1]
         and (c.client_id = auth.uid()
              or (c.supplier_id = public.operating_supplier_id()
                  and public.supplier_can('messages')))
    )
  );

-- ---------------------------------------------------------- notifications
-- Ce qu'un collaborateur voit des notifications de la boutique, par type :
-- la case de l'onglet où la notification mène. Les versements et le
-- dossier restent au patron (et au staff, qui opère la boutique
-- officielle).
create or replace function public.can_see_shop_notification(p_type public.notification_type)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_supplier_owner()
      or public.is_staff()
      or case p_type
           when 'new_order' then public.supplier_can('orders')
           when 'order_status_update' then public.supplier_can('orders')
           when 'delivery_status' then public.supplier_can('orders')
           when 'new_message' then public.supplier_can('messages')
           when 'new_review' then public.supplier_can('reviews')
           when 'new_comment' then public.supplier_can('products')
           when 'low_stock' then public.supplier_can('products')
           when 'characteristic_type_decision' then public.supplier_can('products')
           else false
         end;
$$;

revoke all on function public.can_see_shop_notification(public.notification_type) from public, anon;
grant execute on function public.can_see_shop_notification(public.notification_type) to authenticated;

drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own on public.notifications
  for select using (
    user_id = auth.uid()
    or (user_id = public.operating_supplier_id()
        and public.can_see_shop_notification(type))
  );

-- Marquer comme lu, et rien d'autre : ni le texte, ni le destinataire.
drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own on public.notifications
  for update using (
    user_id = auth.uid()
    or (user_id = public.operating_supplier_id()
        and public.can_see_shop_notification(type))
  ) with check (
    user_id = auth.uid()
    or (user_id = public.operating_supplier_id()
        and public.can_see_shop_notification(type))
  );
revoke update on public.notifications from anon, authenticated;
grant update (is_read) on public.notifications to authenticated;
