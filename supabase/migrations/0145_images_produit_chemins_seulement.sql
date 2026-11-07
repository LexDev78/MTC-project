-- 0145 — Une image de produit est un fichier de la boutique, jamais une
-- adresse (audit du 27/10/2026, faille 8, côté base).
--
-- `products.image_urls` acceptait n'importe quelle chaîne, donc n'importe
-- quelle URL `http(s)`. `index-product-embeddings` la transmet au service
-- d'empreintes (`_shared/image_urls.ts` laissait passer une URL telle
-- quelle) ; avec le modèle auto-hébergé, `ml/serve/app.py` la télécharge :
-- une boutique faisait appeler au serveur l'adresse de son choix, réseau
-- interne compris.
--
-- Or l'app n'écrit jamais d'URL dans ces colonnes, malgré leur nom : elle y
-- range le chemin de l'objet Storage (`<boutique>/<uuid>.<ext>`,
-- `uploadPickedImage`) ou celui d'une photo embarquée du jeu de
-- démonstration (`assets/images/...`), et l'URL se construit à l'affichage
-- (`ResolvedImage`). La base n'accepte plus que ces deux formes — chemin
-- d'objet rangé dans le dossier de la boutique du produit, sans `..` —, et
-- dix photos au plus. Même règle pour les variantes et leur vidéo
-- (`replace_product_characteristics_and_variants` les écrit avec ce que
-- l'app envoie : la vérification ne dépend donc pas de qui écrit, seulement
-- de la présence d'une session).
--
-- L'autre moitié est dans le code : `_shared/image_urls.ts` et
-- `ml/common.py` ne font plus suivre d'URL, et `ml/serve` ne télécharge
-- plus que depuis le bucket public `product-images` de l'hôte configuré.

create or replace function public.validate_product_media_paths(
  p_images text[],
  p_video text,
  p_supplier_id uuid
)
returns void
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_path text;
  v_own_file constant text := '^' || p_supplier_id::text || '/[A-Za-z0-9][A-Za-z0-9._-]*$';
begin
  if coalesce(cardinality(p_images), 0) > 10 then
    raise exception 'Pas plus de 10 photos par produit.';
  end if;
  foreach v_path in array coalesce(p_images, '{}')
  loop
    if v_path is null
       or v_path like '%..%'
       or not (v_path ~ v_own_file or v_path ~ '^assets/images/[A-Za-z0-9/_.-]+$') then
      raise exception 'Photo invalide : % (un fichier envoyé depuis l''app est attendu).', v_path;
    end if;
  end loop;
  if p_video is not null
     and (p_video like '%..%' or p_video !~ v_own_file) then
    raise exception 'Vidéo invalide : % (un fichier envoyé depuis l''app est attendu).', p_video;
  end if;
end;
$$;

revoke all on function public.validate_product_media_paths(text[], text, uuid) from public, anon, authenticated;

create or replace function public.guard_product_media_paths()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supplier_id uuid;
begin
  -- Hors session (semis, scripts d'exploitation) : pas de contrôle.
  if auth.uid() is null then
    return new;
  end if;
  if tg_table_name = 'products' then
    perform public.validate_product_media_paths(new.image_urls, null, new.supplier_id);
  else
    select supplier_id into v_supplier_id from public.products where id = new.product_id;
    perform public.validate_product_media_paths(new.image_urls, new.video_path, v_supplier_id);
  end if;
  return new;
end;
$$;

revoke all on function public.guard_product_media_paths() from public, anon, authenticated;

drop trigger if exists products_guard_media_paths on public.products;
create trigger products_guard_media_paths
  before insert or update of image_urls on public.products
  for each row execute function public.guard_product_media_paths();

drop trigger if exists product_variants_guard_media_paths on public.product_variants;
create trigger product_variants_guard_media_paths
  before insert or update of image_urls, video_path on public.product_variants
  for each row execute function public.guard_product_media_paths();

-- Ce qui est déjà en base, pour mémoire : signalé, pas effacé.
do $$
declare
  v_n integer;
begin
  select count(*) into v_n
    from public.products p, unnest(p.image_urls) u
   where u ~ '^[a-zA-Z][a-zA-Z0-9+.-]*://';
  if v_n > 0 then
    raise notice '% photo(s) de produit sont des URL : à remplacer par un fichier envoyé depuis l''app.', v_n;
  end if;
end $$;
