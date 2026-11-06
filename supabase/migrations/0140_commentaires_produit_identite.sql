-- 0140 — Un commentaire produit dit qui l'a écrit, et ne dit rien de plus
-- (audit du 27/10/2026, faille 4, et la fiche de mise en production :
-- « identifiants visibles dans product_comments_with_likes »).
--
-- 1. L'identité. La policy `product_comments_insert_own` ne vérifiait que
--    `author_id`. `author_name`, `is_supplier` (le badge vendeur) et
--    `supplier_id` étaient libres, et `notify_new_comment` avertit — push
--    compris — le `supplier_id` choisi. Constaté dans l'audit : client1 poste
--    sous un produit de fournisseur1 un message signé « Service client MTC »,
--    badge vendeur, adressé à fournisseur8 : « Votre boutique sera fermée :
--    envoyez 5000 FCFA au +223… » ; la notification arrive chez fournisseur8.
--    Désormais un déclencheur pose tout cela depuis la base, sur le modèle de
--    `stamp_review_comment_author` (`0061`, `0134`) :
--      * `supplier_id` = la boutique du produit ;
--      * la boutique qui répond sur son propre produit écrit sous son nom,
--        avec le badge, et seulement si ce compte a la main sur les produits
--        (la boîte des commentaires est dans l'onglet Produits, et un
--        collaborateur sans cette case n'y entre pas) ;
--      * tout autre auteur écrit sous son nom affiché, sans badge ;
--      * on ne commente pas un produit qui n'est pas en vente ;
--      * une réponse se fait sous un commentaire du même produit — sinon
--        `notify_new_comment` avertissait l'auteur d'un commentaire pris
--        n'importe où.
--
-- 2. Les identifiants. La vue publique exposait `author_id` et
--    `liked_by_user_ids` (les comptes de tous ceux qui ont aimé), et les
--    deux tables se lisaient en entier par n'importe qui (`using (true)`).
--    La vue rend maintenant ce dont l'écran a besoin — le nombre de
--    mentions, et pour l'appelant « est-ce le mien » et « l'ai-je aimé » —
--    et devient le seul chemin de lecture.
--
-- 3. Les notes vocales. L'app les range dans `comment-attachments` en
--    `audio/mp4` (`addVoiceComment`), mais `0033` a limité ce bucket aux
--    images : toute note vocale sous un produit était refusée par Storage.
--    `audio/mp4` y est ajouté, comme pour `chat-attachments`.

-- ------------------------------------------------------------ 1. l'identité
-- Un compte client, au sens de la base : le rôle `client`, compte actif.
-- Les collaborateurs ont le rôle `supplier_tiers`
-- (`apply_account_provisioning`), le staff `supplier_principal`. Servira
-- aussi aux chemins réservés au client (`0146`).
create or replace function public.is_client()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
     where p.id = auth.uid() and p.role = 'client' and p.deleted_at is null
  );
$$;

revoke all on function public.is_client() from public, anon;
grant execute on function public.is_client() to authenticated;

create or replace function public.stamp_product_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
  v_operating uuid := public.operating_supplier_id();
  v_product record;
  v_parent_product text;
begin
  -- Hors session (semis des tests) : rien à décider pour quelqu'un.
  if v_caller is null then
    return new;
  end if;

  select p.supplier_id, p.status, p.is_supplier_verified,
         s.deleted_at as supplier_deleted_at, s.business_name
    into v_product
    from public.products p
    join public.suppliers s on s.id = p.supplier_id
   where p.id = new.product_id;
  if v_product.supplier_id is null then
    raise exception 'Produit introuvable : %', new.product_id;
  end if;

  new.supplier_id := v_product.supplier_id;
  new.created_at := now();

  if new.parent_id is not null then
    select product_id into v_parent_product
      from public.product_comments where id = new.parent_id;
    if v_parent_product is distinct from new.product_id then
      raise exception 'Une réponse se fait sous un commentaire de ce produit.';
    end if;
  end if;

  if v_operating is not distinct from v_product.supplier_id then
    if not public.supplier_can('products') then
      raise exception 'Votre compte n''a pas accès aux commentaires de cette boutique.';
    end if;
    new.author_id := v_product.supplier_id;
    new.author_name := v_product.business_name;
    new.is_supplier := true;
  else
    -- Le client pose ses questions ; un livreur, ou une autre boutique, n'a
    -- rien à faire sous ce produit (aucun rôle n'atteint celui d'un autre).
    if not (public.is_client() or public.is_staff()) then
      raise exception 'Seul un client commente un produit.';
    end if;
    -- Même définition que la vitrine (`products_select_public`).
    if not (v_product.status = 'active'
            and v_product.is_supplier_verified
            and v_product.supplier_deleted_at is null) then
      raise exception 'Ce produit n''est pas en vente : il ne se commente pas.';
    end if;
    new.author_id := v_caller;
    select coalesce(nullif(btrim(p.display_name), ''), 'Client')
      into new.author_name
      from public.profiles p where p.id = v_caller;
    new.author_name := coalesce(new.author_name, 'Client');
    new.is_supplier := false;
  end if;

  if coalesce(new.attachment_type, 'none') = 'none' then
    new.attachment_type := 'none';
    new.attachment_path := null;
    new.voice_duration_seconds := null;
  else
    -- Le fichier est dans le dossier de l'auteur — la boutique, quand elle
    -- répond —, un seul niveau, sans `..` : le premier jet acceptait un
    -- premier segment vide (« /x.jpg ») et « <moi>/../<un autre>/x.jpg »
    -- (contre-vérification du 06/11/2026).
    if new.attachment_path is null
       or new.attachment_path like '%..%'
       or new.attachment_path !~ ('^' || new.author_id::text || '/[A-Za-z0-9][A-Za-z0-9._-]*$') then
      raise exception 'Chemin de fichier invalide : %', new.attachment_path;
    end if;
    if new.attachment_type <> 'voice' then
      new.voice_duration_seconds := null;
    end if;
  end if;

  return new;
end;
$$;

revoke all on function public.stamp_product_comment() from public, anon, authenticated;

drop trigger if exists product_comments_stamp_author on public.product_comments;
create trigger product_comments_stamp_author
  before insert on public.product_comments
  for each row execute function public.stamp_product_comment();

-- Pas de modification ni de suppression par l'API (aucune policy ne les
-- ouvrait) ; on retire aussi le droit, pour que l'intention se lise.
revoke update, delete on public.product_comments from anon, authenticated;

-- -------------------------------------------------------- 2. les identifiants
drop view if exists public.product_comments_with_likes;

-- Propriétaire `postgres`, sans `security_invoker` : la vue lit les deux
-- tables au-delà de leurs policies (les mentions de tout le monde, pour les
-- compter) et ne rend que des colonnes sûres. Elle filtre elle-même ce
-- que l'appelant a le droit de voir : les produits en vente, ceux de sa
-- boutique, et tout pour le staff.
create view public.product_comments_with_likes
with (security_invoker = false) as
select c.id,
       c.product_id,
       c.supplier_id,
       c.author_name,
       c.created_at,
       c.text,
       c.is_supplier,
       c.parent_id,
       c.attachment_type,
       c.attachment_path,
       c.voice_duration_seconds,
       (select count(*)::int from public.comment_likes l where l.comment_id = c.id)
         as like_count,
       exists (select 1 from public.comment_likes l
                where l.comment_id = c.id and l.user_id = auth.uid())
         as liked_by_me,
       (c.author_id = auth.uid()
        or (c.is_supplier and c.author_id = public.operating_supplier_id()))
         as is_mine
  from public.product_comments c
  join public.products p on p.id = c.product_id
  join public.suppliers s on s.id = p.supplier_id
 where (p.status = 'active' and p.is_supplier_verified and s.deleted_at is null)
    or p.supplier_id = public.operating_supplier_id()
    or public.is_staff();

revoke all on public.product_comments_with_likes from public, anon, authenticated;
grant select on public.product_comments_with_likes to anon, authenticated;

-- Les tables ne se lisent plus directement.
drop policy if exists product_comments_select_public on public.product_comments;
revoke select on public.product_comments from anon, authenticated;

drop policy if exists comment_likes_select_public on public.comment_likes;
-- Chacun retrouve sa propre mention (le bouton « j'aime » la cherche pour
-- l'enlever) ; les autres ne se comptent que par la vue.
create policy comment_likes_select_own on public.comment_likes
  for select using (user_id = auth.uid());
revoke select on public.comment_likes from anon;

-- ----------------------------------------------------------- 3. notes vocales
update storage.buckets
   set allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'audio/mp4']
 where id = 'comment-attachments';
