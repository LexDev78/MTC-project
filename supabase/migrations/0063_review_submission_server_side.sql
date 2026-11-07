-- Un avis ne se dépose plus depuis l'app, et un client ne peut plus écrire
-- dans la fiche d'un fournisseur.
--
-- Déposer un avis faisait quatre écritures **depuis la session du client** :
-- l'avis, la moyenne du fournisseur, la recopie de cette moyenne sur ses
-- produits, et la notification. Pour que les trois dernières passent, la RLS
-- ouvrait `suppliers` et `products` en écriture à « quiconque a laissé un
-- avis sur ce fournisseur » (`has_reviewed_supplier`).
--
-- Pour `products`, `0031` avait refermé la brèche avec un garde-fou de
-- colonnes : un relecteur ne peut toucher que la note. **`suppliers` n'a
-- jamais reçu l'équivalent.** Son seul trigger protège
-- `verification_status`. Tout le reste restait ouvert à n'importe quel
-- client ayant laissé un avis, une fois :
--
--   * `public_phone_numbers` — détourner les appels des clients ;
--   * `business_name`, `description`, `banner_url` — renommer la boutique ;
--   * `full_address`, `address_latitude/longitude` — déplacer le point de
--     retrait, donc envoyer les livreurs ailleurs ;
--   * `is_open`, `deleted_at` — fermer ou supprimer la boutique ;
--   * `rating_average`, `rating_count` — fixer la note à ce qu'on veut, dans
--     un sens comme dans l'autre.
--
-- La correction ne consiste pas à ajouter un second garde-fou de colonnes,
-- mais à supprimer la raison de cette ouverture : les trois écritures
-- dérivées passent dans une RPC `security definer`, et le client n'écrit
-- plus que son avis.
--
-- Au passage, la moyenne cesse d'être calculée par lecture-modification-
-- écriture côté client. Ce calcul perdait un avis dès que deux clients
-- notaient en même temps (tous deux lisaient le même `rating_count`), et
-- rien ne garantissait que la valeur écrite dérive du contenu réel de
-- `reviews`. Elle est désormais **recalculée depuis la table**.

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
  v_average numeric;
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

  -- Mêmes conditions que la policy qu'elle remplace : sa propre commande,
  -- et livrée. Vérifiées ici parce que c'est désormais ce chemin qui écrit.
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

  -- Le nom affiché et les chemins de médias sont posés et vérifiés par
  -- `reviews_stamp_author` (`0061`), y compris ici.
  insert into public.reviews (
    id, order_id, supplier_group_id, client_id, supplier_id,
    stars, comment, image_paths, video_path
  ) values (
    v_review_id, p_order_id, p_supplier_group_id, v_client, v_supplier_id,
    p_stars, btrim(p_comment), coalesce(p_image_paths, '{}'), p_video_path
  );

  -- Recalcul depuis la table, et non incrément : deux avis simultanés
  -- donnaient le même `rating_count` à deux calculs concurrents, et le
  -- second écrasait le premier.
  select round(avg(stars)::numeric, 2), count(*)
    into v_average, v_count
    from public.reviews where supplier_id = v_supplier_id;

  update public.suppliers
     set rating_average = v_average, rating_count = v_count
   where id = v_supplier_id;

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

-- Plus aucune raison d'ouvrir ces deux tables à un relecteur.
drop policy if exists "products_update_rating_reviewer" on public.products;

drop policy if exists "suppliers_update_own" on public.suppliers;

create policy "suppliers_update_own" on public.suppliers
  for update using (
    (id = public.operating_supplier_id() and deleted_at is null)
    or public.is_staff()
  ) with check (
    (id = public.operating_supplier_id() and deleted_at is null)
    or public.is_staff()
  );

-- Et plus aucune raison pour quiconque d'écrire une note à la main : elle
-- est dérivée de `reviews`. Le `grant insert` reste (une fiche naît à 0),
-- seule la mise à jour part.
revoke update (rating_average, rating_count) on public.suppliers from authenticated;
revoke update (rating_average, rating_count) on public.products from authenticated;
