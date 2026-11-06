-- 0152 — Ce que la contre-vérification du 06/11/2026 a trouvé dans les
-- fonctions plus anciennes que `0136`.
--
-- Trois attaquants ont essayé de contourner les corrections `0136`–`0151`
-- sur une base neuve. Ce qu'ils ont trouvé dans le code de ces migrations-là
-- y est corrigé directement (elles n'ont jamais été déployées). Ce fichier
-- reprend, depuis leur définition en vigueur, les fonctions et policies plus
-- anciennes qu'ils ont fait tomber :
--
--  1. `set_my_contact_email(null)` effaçait la ligne qui porte les limites
--     d'envoi du code : vider son adresse et redemander un code, en boucle,
--     envoyait autant de courriels de MTC qu'on voulait à une même adresse.
--  2. `rate_courier` laissait un collaborateur sans aucune case noter le
--     livreur — et réécrire la note du patron.
--  3. `order_contact_access` montrait encore l'adresse et le GPS du client au
--     livreur dont l'offre avait expiré.
--  4. Un collaborateur sans la case « produits », ou un livreur, aimait les
--     commentaires au nom de la boutique, ou pour lui-même.
--  5. `review_comments` se lisait en entier par n'importe qui, `author_id`
--     compris : l'identifiant de chaque client qui commente un avis. L'app ne
--     lit cette table que par `fetch_supplier_reviews` /
--     `fetch_product_reviews`, qui ne le rendent pas.
--  6. Un client ouvrait une conversation avec une boutique pas encore
--     vérifiée — que la vitrine ne lui montre pas.
--  7. Un livreur rangeait dans son dossier des chemins de pièces avec `..`.
--  8. `set_products_supplier_verification(boutique, true)` rendait publics
--     les produits d'une boutique en attente, sans trace au dossier.
--  9. La ville d'une boutique, d'où part le prix d'une course MTC (`0147`),
--     se réécrivait d'un UPDATE : une boutique de Mopti se disait de Bamako
--     et payait 1 026 FCFA au lieu de 2 505 une course de 630 km. Une
--     boutique vérifiée garde la ville que MTC a vue ; la changer passe par
--     MTC.
-- 10. Une commande annulée ne rendait jamais son stock : un client
--     réservait tout le stock d'une boutique par une commande en attente,
--     l'annulait, et le produit restait épuisé pour tout le monde.
--
-- `set_my_contact_email`, `rate_courier` et `order_contact_access` sont
-- reprises de leur définition en vigueur, ces passages seuls changés.

CREATE OR REPLACE FUNCTION public.set_my_contact_email(p_email text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then
    raise exception 'Connectez-vous pour modifier votre adresse e-mail.';
  end if;
  if nullif(btrim(coalesce(p_email, '')), '') is not null then
    raise exception 'Une nouvelle adresse se valide par le code qu''on vous envoie.';
  end if;

  update public.profiles
     set contact_email = null,
         contact_email_verified_at = null
   where id = auth.uid();
  -- Un code demandé pour une autre adresse n'a plus de raison d'attendre :
  -- il expire. La ligne, elle, reste — elle porte les limites d'envoi, que
  -- l'effacer remettait à zéro : vider son adresse puis redemander un code,
  -- vingt fois de suite, envoyait vingt courriels de MTC à la même
  -- adresse (contre-vérification du 06/11/2026).
  update public.contact_email_verifications
     set expires_at = least(expires_at, now())
   where user_id = auth.uid();
  return null;
end;
$function$;

CREATE OR REPLACE FUNCTION public.rate_courier(p_delivery_id text, p_stars integer, p_comment text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_caller uuid := auth.uid();
  v_courier_id uuid;
  v_status public.delivery_status;
  v_client_id uuid;
  v_group_supplier_id uuid;
  v_role public.courier_rater_role;
  v_comment text := nullif(trim(coalesce(p_comment, '')), '');
begin
  if v_caller is null then
    raise exception 'Vous devez être connecté pour noter une livraison.';
  end if;
  if p_stars is null or p_stars < 1 or p_stars > 5 then
    raise exception 'Une note va de 1 à 5 étoiles.';
  end if;

  select d.courier_id, d.status, o.client_id, g.supplier_id
    into v_courier_id, v_status, v_client_id, v_group_supplier_id
    from public.deliveries d
    join public.orders o on o.id = d.order_id
    join public.order_supplier_groups g on g.id = d.supplier_group_id
   where d.id = p_delivery_id;

  if v_courier_id is null then
    raise exception 'Course introuvable ou sans livreur attribué.';
  end if;
  if v_status <> 'delivered' then
    raise exception 'Une course se note une fois livrée.';
  end if;

  if v_caller = v_client_id then
    v_role := 'client';
  -- La boutique note le livreur de ses commandes : avec la case
  -- « commandes », comme pour les voir (`0143`). Sans elle, un collaborateur
  -- sans aucune case notait — et réécrivait la note du patron.
  elsif v_group_supplier_id = public.operating_supplier_id()
        and public.supplier_can('orders') then
    v_role := 'supplier';
  else
    raise exception 'Seuls le client et le fournisseur de cette course peuvent la noter.';
  end if;

  -- Corriger sa note est permis ; en ajouter une seconde ne l'est pas.
  -- `updated_at` garde la trace du changement plutôt que de le taire.
  insert into public.courier_ratings
    (delivery_id, courier_id, rater_id, rater_role, stars, comment)
  values
    (p_delivery_id, v_courier_id, v_caller, v_role, p_stars, v_comment)
  on conflict (delivery_id, rater_role) do update
    set stars = excluded.stars,
        comment = excluded.comment,
        rater_id = excluded.rater_id,
        updated_at = now();
end;
$function$;

CREATE OR REPLACE FUNCTION public.order_contact_access(p_order_id text)
 RETURNS TABLE(phone boolean, address boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_client uuid;
  v_shop uuid;
  v_groupes_ouverts integer;
  v_livre_lui_meme boolean;
begin
  phone := false;
  address := false;
  if v_uid is null or p_order_id is null then
    return next;
    return;
  end if;

  select o.client_id into v_client from public.orders o where o.id = p_order_id;
  if v_client is null then
    return next;
    return;
  end if;

  -- Le client : tout, toujours.
  if v_client = v_uid then
    phone := true;
    address := true;
    return next;
    return;
  end if;

  -- La boutique : l'adresse tant que sa part n'est ni livrée ni annulée ; le
  -- numéro en plus quand c'est elle qui livre. Un collaborateur sans la
  -- permission `orders` n'a rien à en voir.
  v_shop := public.operating_supplier_id();
  if v_shop is not null and public.supplier_can('orders') then
    select count(*), coalesce(bool_or(g.delivery_mode = 'self_delivery'), false)
      into v_groupes_ouverts, v_livre_lui_meme
      from public.order_supplier_groups g
     where g.order_id = p_order_id
       and g.supplier_id = v_shop
       and g.status not in ('delivered', 'cancelled');
    if v_groupes_ouverts > 0 then
      address := true;
      phone := v_livre_lui_meme;
    end if;
  end if;

  -- Le livreur : numéro et adresse une fois la course acceptée, jusqu'à la
  -- remise ; l'adresse seule pendant qu'on la lui propose, pour qu'il juge
  -- le trajet. Le numéro attend qu'il ait dit oui.
  if exists (
    select 1 from public.deliveries d
     where d.order_id = p_order_id
       and d.courier_id = v_uid
       and d.status in ('accepted', 'picked_up')
  ) then
    phone := true;
    address := true;
  elsif exists (
    select 1 from public.deliveries d
     where d.order_id = p_order_id
       and d.offered_to_courier_id = v_uid
       and d.status = 'offered'
       -- Une offre expirée n'en est plus une (contre-vérification du
       -- 06/11/2026) : tant que la relance ne l'avait pas reprise, le
       -- livreur gardait l'adresse et le GPS du client.
       and (d.offer_expires_at is null or d.offer_expires_at > now())
  ) then
    address := true;
  end if;

  return next;
end;
$function$;

-- ------------------------------------------------- 4. les mentions « j'aime »
drop policy if exists comment_likes_toggle_own on public.comment_likes;
create policy comment_likes_toggle_own on public.comment_likes
  for all using (
    (user_id = auth.uid() and (public.is_client() or public.is_staff()))
    or (user_id = public.operating_supplier_id() and public.supplier_can('products'))
  ) with check (
    (user_id = auth.uid() and (public.is_client() or public.is_staff()))
    or (user_id = public.operating_supplier_id() and public.supplier_can('products'))
  );

-- ------------------------------------------- 5. les commentaires sous les avis
-- Chacun relit le sien (l'app efface son commentaire par son identifiant),
-- le staff modère ; les autres les lisent par les fonctions des avis, qui ne
-- rendent pas `author_id`.
drop policy if exists review_comments_select_public on public.review_comments;
create policy review_comments_select_own_or_staff on public.review_comments
  for select using (author_id = auth.uid() or public.is_staff());
revoke select on public.review_comments from anon;

-- ------------------------------------------- 6. ouvrir une conversation
-- Avec une boutique en vente (vérifiée, ou la boutique officielle), ou avec
-- une boutique chez qui le client a déjà commandé.
create or replace function public.can_open_conversation_with_shop(p_supplier_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.suppliers s
     where s.id = p_supplier_id
       and s.deleted_at is null
       and (s.verification_status = 'verified' or s.supplier_type = 'principal')
  ) or exists (
    select 1 from public.order_supplier_groups g
      join public.orders o on o.id = g.order_id
     where g.supplier_id = p_supplier_id and o.client_id = auth.uid()
  );
$$;

revoke all on function public.can_open_conversation_with_shop(uuid) from public, anon;
grant execute on function public.can_open_conversation_with_shop(uuid) to authenticated;

drop policy if exists chat_conversations_insert_client on public.chat_conversations;
create policy chat_conversations_insert_client on public.chat_conversations
  for insert with check (
    client_id = auth.uid()
    and public.is_client()
    and public.can_open_conversation_with_shop(supplier_id)
  );

-- ----------------------------------------------- 7. les pièces d'un livreur
create or replace function public.guard_courier_document_path()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.file_path like 'seed://%' and auth.uid() is null then
    return new;
  end if;
  if new.file_path like '%..%'
     or new.file_path !~ ('^' || new.courier_id::text || '/[A-Za-z0-9][A-Za-z0-9._-]*$') then
    raise exception
      'Une pièce doit être rangée dans le dossier de son livreur (% attendu).', new.courier_id;
  end if;
  return new;
end;
$$;

revoke all on function public.guard_courier_document_path() from public, anon, authenticated;

drop trigger if exists courier_documents_path_owner on public.courier_documents;
create trigger courier_documents_path_owner
  before insert or update of file_path, courier_id on public.courier_documents
  for each row execute function public.guard_courier_document_path();

-- ------------------------------------- 8. la vérification des produits suit la boutique
create or replace function public.set_products_supplier_verification(p_supplier_id uuid, p_verified boolean)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if not public.is_staff() then
    raise exception 'Non autorisé.';
  end if;
  -- Le drapeau des produits recopie l'état de la boutique : il ne devient
  -- vrai que pour une boutique vérifiée (ou la boutique officielle). La
  -- décision elle-même passe par le dossier (`review_supplier_kyc`), qui
  -- laisse une trace.
  if p_verified and not exists (
    select 1 from public.suppliers s
     where s.id = p_supplier_id
       and s.deleted_at is null
       and (s.verification_status = 'verified' or s.supplier_type = 'principal')
  ) then
    raise exception 'Cette boutique n''est pas vérifiée : ses produits ne peuvent pas l''être.';
  end if;

  update public.products
    set is_supplier_verified = p_verified
    where supplier_id = p_supplier_id;
end;
$function$;

-- ---------------------------------------------- 9. la ville d'une boutique vérifiée
-- Reprise de `guard_supplier_badges` (`0103`), la ville ajoutée.
create or replace function public.guard_supplier_badges()
returns trigger
language plpgsql
set search_path to 'public'
as $function$
begin
  -- Seule la requête directe est visée : `review_supplier_kyc`,
  -- `submit_review` et le semis des tests s'exécutent sous le propriétaire.
  if current_user not in ('anon', 'authenticated') then
    return new;
  end if;

  if new.verification_status is distinct from old.verification_status then
    raise exception
      'Le statut de vérification est décidé par MTC, pas par la boutique.';
  end if;
  if new.rating_average is distinct from old.rating_average
     or new.rating_count is distinct from old.rating_count then
    raise exception 'La note d''une boutique se calcule à partir des avis.';
  end if;
  -- La forme juridique commande les pièces exigées au dossier : la changer
  -- après coup ferait accepter un dossier de particulier pour une société.
  if new.legal_type is distinct from old.legal_type
     or new.supplier_type is distinct from old.supplier_type then
    raise exception 'La forme juridique se change par le dossier, pas ici.';
  end if;
  -- La ville d'une boutique vérifiée est celle que MTC a vue au dossier, et
  -- c'est d'elle que part le prix d'une course MTC (`0147`) : la changer
  -- passe par MTC (`0152`).
  if new.city is distinct from old.city and old.verification_status = 'verified' then
    raise exception
      'La ville d''une boutique vérifiée se change par MTC : elle fixe le prix des courses.';
  end if;
  return new;
end;
$function$;

-- -------------------------------------------- 10. une commande annulée rend son stock
-- Les gardes de permission des produits jugent l'appelant : un client, ou un
-- collaborateur qui n'a que les commandes, n'écrit pas le stock. La remise
-- en stock d'une annulation se fait pour eux, par la base : ce réglage le
-- dit aux gardes le temps de l'écriture, puis reprend sa valeur.
create or replace function public.guard_supplier_permission()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_permission text := tg_argv[0];
  v_supplier_id uuid;
  v_row jsonb := to_jsonb(coalesce(new, old));
  v_product_id text;
begin
  -- La remise en stock d'une commande annulée (`restock_cancelled_group`).
  if current_setting('app.trusted_stock_write', true) = 'on' then
    return coalesce(new, old);
  end if;

  -- Hors d'un contexte fournisseur, rien à garder : c'est un client, un
  -- livreur, ou un déclencheur interne.
  if public.operating_supplier_id() is null then
    return coalesce(new, old);
  end if;

  if tg_argv[1] = 'supplier_id' then
    v_supplier_id := (v_row ->> 'supplier_id')::uuid;
  else
    -- Variantes, caractéristiques, mouvements de stock : le fournisseur se
    -- lit sur le produit qui les porte.
    v_product_id := v_row ->> 'product_id';
    select p.supplier_id into v_supplier_id
      from public.products p where p.id = v_product_id;
  end if;

  if v_supplier_id is distinct from public.operating_supplier_id() then
    return coalesce(new, old);
  end if;

  if not public.supplier_can(v_permission) then
    raise exception
      'Votre compte n''a pas accès à cette partie de la boutique (%).',
      v_permission;
  end if;

  return coalesce(new, old);
end;
$function$;

create or replace function public.restock_cancelled_group()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item record;
  v_stock text := current_setting('app.trusted_stock_write', true);
  v_produit text := current_setting('app.trusted_product_write', true);
begin
  -- Un colis déjà retiré par le livreur n'est pas revenu en rayon : c'est
  -- le staff, seul à pouvoir annuler à ce stade (`0146`), qui le remet.
  if exists (
    select 1 from public.deliveries d
     where d.supplier_group_id = new.id and d.picked_up_at is not null
  ) then
    return null;
  end if;

  perform set_config('app.trusted_stock_write', 'on', true);
  perform set_config('app.trusted_product_write', 'on', true);
  for v_item in
    select i.product_id, i.variant_id, i.quantity
      from public.order_items i
     where i.group_id = new.id
  loop
    if v_item.variant_id is not null then
      update public.product_variants
         set stock_quantity = stock_quantity + v_item.quantity
       where id = v_item.variant_id;
    else
      update public.products
         set stock_quantity = stock_quantity + v_item.quantity
       where id = v_item.product_id;
    end if;
    insert into public.stock_movements (id, product_id, variant_id, quantity_delta, reason, note)
    values (gen_random_uuid()::text, v_item.product_id, v_item.variant_id, v_item.quantity,
            'returned', 'Commande annulée');
  end loop;
  perform set_config('app.trusted_stock_write', coalesce(v_stock, ''), true);
  perform set_config('app.trusted_product_write', coalesce(v_produit, ''), true);
  return null;
end;
$$;

revoke all on function public.restock_cancelled_group() from public, anon, authenticated;

drop trigger if exists order_supplier_groups_restock_cancelled on public.order_supplier_groups;
create trigger order_supplier_groups_restock_cancelled
  after update of status on public.order_supplier_groups
  for each row
  when (new.status = 'cancelled' and old.status is distinct from 'cancelled')
  execute function public.restock_cancelled_group();
