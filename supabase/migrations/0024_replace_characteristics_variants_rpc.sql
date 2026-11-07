-- Bug réel : côté fournisseur, ajouter une caractéristique à un produit
-- *existant* (déjà actif, déjà pourvu d'au moins une variante) échouait
-- systématiquement avec l'erreur Postgres de `products_active_requires_variants`
-- (0021) — "Un produit actif doit avoir au moins une caractéristique/variante".
--
-- Cause : `SupabaseProductDatasource.replaceCharacteristicsAndVariants` fait
-- 6 appels PostgREST séquentiels (delete variants, delete characteristics,
-- insert characteristics, insert options, insert variants, insert variant
-- options) — chacun sa propre transaction. Le premier, `delete from
-- product_variants`, fait immédiatement retomber `has_variants` à false via
-- le trigger d'agrégation (0018) et commit seul : `products_active_requires_variants`
-- se déclenche à CE commit-là, bien avant que les nouvelles variantes ne
-- soient insérées quelques appels plus tard.
--
-- Fix : la même opération en un seul aller-retour, via RPC — une seule
-- transaction, donc un seul commit. Même précaution que
-- `test_reset_and_seed` (0020) pour la raison qui y est documentée :
-- déférer ne change pas ce qu'un événement voit, seulement quand il
-- s'exécute — le DELETE ci-dessous ferait quand même passer une image
-- has_variants=false en file d'attente. Trigger désactivé le temps de
-- l'opération plutôt que de complexifier en upsert-diff.
create or replace function public.replace_product_characteristics_and_variants(
  p_product_id text,
  p_characteristics jsonb,
  p_variants jsonb
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supplier_id uuid;
  v_characteristic jsonb;
  v_option jsonb;
  v_variant jsonb;
  v_ref jsonb;
begin
  -- Disable *before* the ownership check below reads from `products`, not
  -- after: Postgres refuses `ALTER TABLE ... DISABLE TRIGGER` on a relation
  -- already touched by an earlier query within the same function call
  -- ("cannot ALTER TABLE ... because it is being used by active queries in
  -- this session") — `test_reset_and_seed` (0020) never hits this because
  -- its own `disable trigger` is the very first statement in its body, with
  -- nothing reading `products` beforehand.
  alter table public.products disable trigger products_active_requires_variants;

  select supplier_id into v_supplier_id from public.products where id = p_product_id;
  if v_supplier_id is null then
    raise exception 'Produit introuvable : %', p_product_id;
  end if;
  if v_supplier_id is distinct from public.operating_supplier_id() then
    raise exception 'Non autorisé à modifier les caractéristiques de ce produit.';
  end if;

  delete from public.product_variants where product_id = p_product_id;
  delete from public.product_characteristics where product_id = p_product_id;

  for v_characteristic in select * from jsonb_array_elements(p_characteristics)
  loop
    insert into public.product_characteristics (id, product_id, type_id, display_order)
    values (
      v_characteristic ->> 'id',
      p_product_id,
      v_characteristic ->> 'type_id',
      (v_characteristic ->> 'display_order')::integer
    );

    for v_option in select * from jsonb_array_elements(v_characteristic -> 'options')
    loop
      insert into public.product_characteristic_options
        (id, characteristic_id, value, price_delta_fcfa, display_order)
      values (
        v_option ->> 'id',
        v_characteristic ->> 'id',
        v_option ->> 'value',
        (v_option ->> 'price_delta_fcfa')::integer,
        (v_option ->> 'display_order')::integer
      );
    end loop;
  end loop;

  for v_variant in select * from jsonb_array_elements(p_variants)
  loop
    insert into public.product_variants
      (id, product_id, name, price_fcfa, stock_quantity, image_urls, is_default, display_order)
    values (
      v_variant ->> 'id',
      p_product_id,
      v_variant ->> 'name',
      (v_variant ->> 'price_fcfa')::integer,
      (v_variant ->> 'stock_quantity')::integer,
      array(select jsonb_array_elements_text(v_variant -> 'image_urls')),
      (v_variant ->> 'is_default')::boolean,
      (v_variant ->> 'display_order')::integer
    );

    for v_ref in select * from jsonb_array_elements(v_variant -> 'option_refs')
    loop
      insert into public.product_variant_options (variant_id, characteristic_id, option_id)
      values (
        v_variant ->> 'id',
        v_ref ->> 'characteristic_id',
        v_ref ->> 'option_id'
      );
    end loop;
  end loop;

  alter table public.products enable trigger products_active_requires_variants;
end;
$$;

revoke all on function public.replace_product_characteristics_and_variants(text, jsonb, jsonb) from public, anon;
grant execute on function public.replace_product_characteristics_and_variants(text, jsonb, jsonb) to authenticated;
