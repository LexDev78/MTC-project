-- Bug réel : `recompute_product_variant_aggregates` (0018) ne copiait les
-- photos de la variante par défaut vers `products.image_urls` que la
-- PREMIÈRE fois (condition "seulement si vide") — pensé à l'époque pour ne
-- jamais écraser des photos que le fournisseur aurait mises directement sur
-- le produit. Cette voie n'existe plus du tout : le formulaire produit n'a
-- plus de sélecteur de photo au niveau produit
-- (`supplier_product_form_screen.dart`), les photos viennent uniquement des
-- variantes. Résultat concret : dès qu'un produit a eu ne serait-ce qu'une
-- fois des `image_urls` non vides, il reste bloqué sur CES photos-là pour
-- toujours — changer la variante par défaut, ou juste changer ses photos,
-- ne se reflète plus jamais sur la carte produit côté client.
--
-- Fix : même traitement que `price_fcfa`/`stock_quantity` juste au-dessus —
-- un miroir inconditionnel de la variante par défaut tant que le produit a
-- des variantes, pas un simple fallback ponctuel.
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
          image_urls = coalesce(v_default_images, image_urls)
      where id = v_product_id;
  end if;

  return coalesce(new, old);
end;
$$;
