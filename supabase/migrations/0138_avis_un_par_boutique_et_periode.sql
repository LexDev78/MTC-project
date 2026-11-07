-- 0138 — Un client, une boutique, un avis par période de 30 jours (audit du
-- 27/10/2026, faille 3, moitié « avis »).
--
-- `submit_review` acceptait un avis par commande. Un compte complice qui
-- commande trois fois le même article bon marché publiait trois 5★ : la
-- note de la boutique passait de 4,60 à 4,61 pour le prix de trois
-- commissions. La remise confirmée par le client (`0139`) ferme le chemin où
-- la boutique se déclarait livrée seule ; reste le complice, qui confirme.
-- Contre lui, la seule défense qui ne pénalise pas les vrais clients est de
-- limiter son poids : un avis par boutique et par période, quel que soit le
-- nombre de commandes.
--
-- 30 jours : un client fidèle qui commande chaque semaine note sa boutique
-- une fois par mois, ce qui suffit à une note qui reflète l'expérience ; un
-- complice, lui, ne pèse plus qu'un avis par mois et par compte.
--
-- Ce que l'audit proposait aussi — « exclure les avis d'un client qui n'a
-- jamais payé » — n'est pas fait ici, à dessein : `payment_status` ne
-- passe à `paid` que pour un paiement en ligne constaté par le staff
-- (`mark_order_paid`, `0106`). Un paiement à la livraison reste
-- `pending_on_delivery` pour toujours, livré ou non. Appliquée telle quelle,
-- la règle retirerait de la note presque tous les vrais avis. La preuve de
-- transaction retenue est la remise confirmée par quelqu'un d'autre que la
-- boutique (le scan du livreur, ou le client lui-même, `0139`).
--
-- Reprise de la définition en vigueur (`0119`), deux ajouts seulement : le
-- verrou par client et boutique, et le contrôle de la période.

create or replace function public.submit_review(p_order_id text, p_supplier_group_id text, p_stars integer, p_comment text, p_image_paths text[] DEFAULT '{}'::text[], p_video_path text DEFAULT NULL::text, p_title text DEFAULT NULL::text)
 returns text
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_client uuid := auth.uid();
  v_supplier_id uuid;
  v_group_status public.order_status;
  v_review_id text := gen_random_uuid()::text;
  v_average double precision;
  v_count integer;
  -- Vide ou blanc = pas de titre.
  v_title text := nullif(btrim(coalesce(p_title, '')), '');
  v_last_review timestamptz;
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
  if char_length(v_title) > 100 then
    raise exception 'Le titre ne doit pas dépasser 100 caractères.';
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

  -- Deux envois simultanés pour deux commandes de la même boutique ne
  -- doivent pas passer tous les deux le contrôle de période : on les met
  -- en file, par client et par boutique.
  perform pg_advisory_xact_lock(
    hashtextextended('submit_review:' || v_client::text || ':' || v_supplier_id::text, 0)
  );

  if exists (
    select 1 from public.reviews
     where order_id = p_order_id and supplier_group_id = p_supplier_group_id
  ) then
    raise exception 'Vous avez déjà noté cette commande.';
  end if;

  select max(created_at) into v_last_review
    from public.reviews
   where client_id = v_client and supplier_id = v_supplier_id;
  if v_last_review is not null and v_last_review > now() - interval '30 days' then
    raise exception
      'Vous avez déjà noté cette boutique le %. Vous pourrez la noter à nouveau à partir du %.',
      to_char(v_last_review, 'DD/MM/YYYY'),
      to_char(v_last_review + interval '30 days', 'DD/MM/YYYY');
  end if;

  insert into public.reviews (
    id, order_id, supplier_group_id, client_id, supplier_id,
    stars, title, comment, image_paths, video_path
  ) values (
    v_review_id, p_order_id, p_supplier_group_id, v_client, v_supplier_id,
    p_stars, v_title, btrim(p_comment), coalesce(p_image_paths, '{}'),
    p_video_path
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

  -- Le titre, quand il y en a un, résume mieux que le début du texte.
  insert into public.notifications (id, user_id, type, title, body, reference_id)
  values (
    gen_random_uuid()::text, v_supplier_id, 'new_review', 'Nouvel avis',
    p_stars || '★ — ' || coalesce(v_title, btrim(p_comment)), v_review_id
  );

  return v_review_id;
end;
$function$;

-- Le contrôle de période lit les avis d'un client sur une boutique.
create index if not exists reviews_client_supplier_created_idx
  on public.reviews (client_id, supplier_id, created_at desc);
