-- Les photos d'un produit ne doivent plus disparaître quand on lui compose
-- des variantes sans photo.
--
-- Ce que faisait `0018_product_variants.sql` : copier les photos de la
-- variante par défaut vers `products.image_urls` **seulement** si cette
-- variante en avait et si le produit n'en avait pas lui-même — son
-- commentaire le dit mot pour mot, « jamais en écrasant des photos que le
-- fournisseur a explicitement mises sur le produit lui-même ».
--
-- Ce que `0025_fix_image_sync_staleness.sql` a mis à la place, en corrigeant
-- (à raison) le cas où les photos du produit restaient figées sur une
-- ancienne version de la variante par défaut :
--
--     image_urls = coalesce(v_default_images, image_urls)
--
-- `product_variants.image_urls` est `not null default '{}'` : une variante
-- sans photo porte un tableau **vide**, jamais `null`. Le `coalesce` ne
-- protège donc rien du tout — il renvoie toujours `v_default_images`, vide
-- compris. Conséquence observée sur un vrai parcours fournisseur (voir le
-- focus variantes, `integration_test/focus_variantes_test.dart`) : composer
-- des variantes sans leur donner de photo vide la fiche produit de toutes
-- les siennes, d'un coup et sans le dire — bandeau photo vide côté client,
-- pastilles de couleur en cintres gris, vignette de remplacement dans la
-- liste du fournisseur.
--
-- La règle ci-dessous garde l'intention des deux migrations : la variante
-- par défaut reste la source de vérité **tant qu'elle a des photos** (donc
-- un changement de ses photos se propage bien, ce que 0025 voulait), et le
-- produit garde les siennes quand elle n'en a pas (ce que 0018 voulait).

create or replace function public.recompute_product_variant_aggregates()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product_id text := coalesce(new.product_id, old.product_id);
  v_count integer;
  v_min integer;
  v_max integer;
  v_stock integer;
  v_default_images text[];
begin
  select count(*), min(price_fcfa), max(price_fcfa), coalesce(sum(stock_quantity), 0)
    into v_count, v_min, v_max, v_stock
    from public.product_variants
    where product_id = v_product_id;

  if v_count = 0 then
    -- Dernière variante supprimée : price_fcfa/stock_quantity/image_urls ne
    -- sont PAS touchés ici (retour aux champs gérés manuellement par le
    -- fournisseur, jamais remis à 0/null/vide — cela corromprait de vraies
    -- données que le fournisseur n'a pas lui-même modifiées).
    update public.products
      set has_variants = false, max_price_fcfa = null, variant_count = 0
      where id = v_product_id;
  else
    select image_urls into v_default_images
      from public.product_variants
      where product_id = v_product_id and is_default
      limit 1;

    update public.products
      set has_variants = true, price_fcfa = v_min, max_price_fcfa = v_max,
          stock_quantity = v_stock, variant_count = v_count,
          image_urls = case
            when coalesce(cardinality(v_default_images), 0) > 0
            then v_default_images
            else image_urls
          end
      where id = v_product_id;
  end if;

  return coalesce(new, old);
end;
$$;
