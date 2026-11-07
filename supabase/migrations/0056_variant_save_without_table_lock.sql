-- Enregistrer des variantes ne doit pas geler le catalogue.
--
-- `replace_product_characteristics_and_variants` désactivait le déclencheur
-- `products_active_requires_variants` le temps de son travail. Un
-- `ALTER TABLE ... DISABLE TRIGGER` réclame un verrou **ACCESS EXCLUSIVE sur
-- toute la table `products`** : il attend la fin de chaque lecture en cours
-- et bloque toutes les suivantes. Autrement dit, chaque fois qu'un
-- fournisseur enregistrait ses variantes, toute consultation du catalogue
-- s'arrêtait — par n'importe qui, sur n'importe quel produit.
--
-- Dans la suite de tests, cela se voyait autrement : interblocages (40P01)
-- puis « canceling statement due to statement timeout » (57014), sur des
-- fichiers sans rapport, jamais les mêmes d'une exécution à l'autre.
--
-- Pourquoi ce verrou était là : le déclencheur est bien différé à la
-- validation (`DEFERRABLE INITIALLY DEFERRED`, `0021`), mais sa fonction
-- lisait `new.has_variants` — l'image de la ligne **telle qu'au moment de
-- l'instruction**. Or la RPC supprime toutes les variantes avant de les
-- réinsérer : cette suppression met en file d'attente une image
-- `has_variants = false`, et à la validation la fonction accusait un produit
-- actif sans variante, alors qu'il en avait de nouveau.
--
-- La correction tient en une idée : un contrôle différé à la validation doit
-- **relire l'état validé**, pas se fier à une image intermédiaire. Il devient
-- alors indifférent aux états transitoires, et plus rien ne justifie de le
-- désactiver.

create or replace function public.check_active_product_has_variants()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_status public.product_status;
  v_has_variants boolean;
begin
  -- Relecture au moment de la validation, et non `new.*` : c'est tout
  -- l'intérêt d'un contrôle différé.
  select status, has_variants into v_status, v_has_variants
    from public.products where id = new.id;

  -- Ligne supprimée entre-temps : plus rien à garantir.
  if not found then return new; end if;

  if v_status = 'active' and not v_has_variants then
    raise exception
      'Un produit actif doit avoir au moins une caractéristique/variante (%).', new.id;
  end if;
  return new;
end;
$$;

-- Reprend `0044_variant_video.sql` **sans** les deux `alter table`. Le reste
-- est identique, à la ligne près.
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
      (id, product_id, name, price_fcfa, stock_quantity, image_urls, video_path,
       is_default, display_order)
    values (
      v_variant ->> 'id',
      p_product_id,
      v_variant ->> 'name',
      (v_variant ->> 'price_fcfa')::integer,
      (v_variant ->> 'stock_quantity')::integer,
      array(select jsonb_array_elements_text(v_variant -> 'image_urls')),
      v_variant ->> 'video_path',
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
end;
$$;

revoke all on function public.replace_product_characteristics_and_variants(text, jsonb, jsonb) from public, anon;
grant execute on function public.replace_product_characteristics_and_variants(text, jsonb, jsonb) to authenticated;
