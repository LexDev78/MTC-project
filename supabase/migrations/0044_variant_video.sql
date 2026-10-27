-- Une courte vidéo par variante, en plus de ses photos.
--
-- Trois pièces :
--   1. la colonne `video_path` sur `product_variants` (chemin d'objet
--      Storage, jamais une URL résolue — même convention que `image_urls`,
--      voir `ResolvedImage`) ;
--   2. un bucket `product-videos` à part plutôt que de verser les vidéos
--      dans `product-images` : les limites de ce dernier (5 Mo, images
--      seules — `0033_fix_notification_spoofing_payout_amount_and_upload_limits.sql`)
--      sont faites pour des photos, et les relâcher pour tout le monde
--      ouvrirait l'upload de vidéos partout où une photo est acceptée ;
--   3. la RPC d'enregistrement des variantes, qui doit transporter la
--      nouvelle colonne — elle réécrit l'ensemble des variantes à chaque
--      sauvegarde, donc une colonne qu'elle ignore est une colonne vidée à
--      la première modification du produit.

alter table public.product_variants add column if not exists video_path text;

-- ----------------------------------------------------------------------------
-- Bucket des vidéos de variante : public en lecture (le catalogue l'est), en
-- écriture réservé au fournisseur propriétaire, dossier = son id — mêmes
-- règles que `product-images` (`0001_initial_schema.sql`).
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public) values
  ('product-videos', 'product-videos', true)
on conflict (id) do nothing;

-- 25 Mo : une vidéo « courte » (~30 s filmée au téléphone) tient largement
-- dedans, alors que le plafond de 5 Mo des photos la refuserait toujours.
update storage.buckets set
  file_size_limit = 25 * 1024 * 1024,
  allowed_mime_types = array['video/mp4', 'video/quicktime']
where id = 'product-videos';

create policy "product_videos_public_read" on storage.objects
  for select using (bucket_id = 'product-videos');
create policy "product_videos_owner_write" on storage.objects
  for insert with check (
    bucket_id = 'product-videos' and (storage.foldername(name))[1] = public.operating_supplier_id()::text
  );
create policy "product_videos_owner_update" on storage.objects
  for update using (
    bucket_id = 'product-videos' and (storage.foldername(name))[1] = public.operating_supplier_id()::text
  );
create policy "product_videos_owner_delete" on storage.objects
  for delete using (
    bucket_id = 'product-videos' and (storage.foldername(name))[1] = public.operating_supplier_id()::text
  );

-- ----------------------------------------------------------------------------
-- RPC : identique à `0024_replace_characteristics_variants_rpc.sql` (voir
-- son en-tête pour le pourquoi de la transaction unique et du trigger
-- désactivé), à la colonne `video_path` près.
-- ----------------------------------------------------------------------------
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

  alter table public.products enable trigger products_active_requires_variants;
end;
$$;

revoke all on function public.replace_product_characteristics_and_variants(text, jsonb, jsonb) from public, anon;
grant execute on function public.replace_product_characteristics_and_variants(text, jsonb, jsonb) to authenticated;
