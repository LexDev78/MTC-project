-- Vérifie 0145 (une image de produit est un fichier de la boutique) contre
-- une base où elle est appliquée, sans rien y laisser : tout se passe dans
-- une transaction annulée.
--
--   docker exec -i supabase_db_mtc_verif psql -U postgres -d postgres -q \
--     < supabase/snippets/verif_0145.sql
--
-- Dernière ligne attendue : « TOUTES LES VÉRIFICATIONS PASSENT ».
\set ON_ERROR_STOP 1
\o /dev/null
begin;
set local client_min_messages = warning;

create schema verif;
grant usage on schema verif to anon, authenticated;
create function verif.comme(p_id uuid) returns void language sql security definer as $$
  select set_config('request.jwt.claims', jsonb_build_object('sub', p_id, 'role', 'authenticated',
    'aal', 'aal1', 'app_metadata', (select raw_app_meta_data from auth.users where id = p_id))::text, true);
$$;
create function verif.refuse(p_sql text) returns boolean language plpgsql as $$
begin
  execute p_sql;
  return false;
exception when others then
  return true;
end $$;
grant execute on all functions in schema verif to anon, authenticated;

\set bogolan 'b7eb8585-4091-5b6f-83f7-5d70724e97a3'
select id as prod from public.products where supplier_id = :'bogolan' and has_variants order by id limit 1 \gset
select set_config('verif.prod', :'prod', true);

set local role authenticated;
select verif.comme(:'bogolan');
do $$
declare
  v_mauvaises text[] := array[
    'http://169.254.169.254/latest/meta-data/',
    'http://127.0.0.1:8080/embed',
    'https://exemple.ml/photo.jpg',
    'b8e6fcc1-ef1c-5248-8ffa-5de27e9beebb/photo.jpg',
    'b7eb8585-4091-5b6f-83f7-5d70724e97a3/../b8e6fcc1-ef1c-5248-8ffa-5de27e9beebb/photo.jpg',
    'b7eb8585-4091-5b6f-83f7-5d70724e97a3/sous/dossier.jpg',
    'assets/../../etc/passwd'];
  v text;
begin
  foreach v in array v_mauvaises loop
    if not verif.refuse(format(
         'update public.products set image_urls = array[%L] where id = %L', v, current_setting('verif.prod'))) then
      raise exception 'ÉCHEC : photo de produit acceptée : %', v;
    end if;
    if not verif.refuse(format(
         'update public.product_variants set image_urls = array[%L] where product_id = %L', v, current_setting('verif.prod'))) then
      raise exception 'ÉCHEC : photo de variante acceptée : %', v;
    end if;
  end loop;
  if not verif.refuse(format(
       'update public.product_variants set video_path = %L where product_id = %L',
       'http://10.0.0.1/video.mp4', current_setting('verif.prod'))) then
    raise exception 'ÉCHEC : vidéo de variante acceptée sous forme d''URL';
  end if;
  if not verif.refuse(format(
       'update public.products set image_urls = %L where id = %L',
       array_fill('b7eb8585-4091-5b6f-83f7-5d70724e97a3/a.jpg'::text, array[11]), current_setting('verif.prod'))) then
    raise exception 'ÉCHEC : onze photos acceptées';
  end if;

  -- Le chemin de l'RPC des variantes, qui écrit sous le propriétaire.
  if not verif.refuse(format($q$select public.replace_product_characteristics_and_variants(%L, '[]'::jsonb,
       jsonb_build_array(jsonb_build_object('id', 'verif-v', 'name', 'Unique', 'price_fcfa', 1000,
         'stock_quantity', 1, 'is_default', true, 'display_order', 0, 'options', '[]'::jsonb,
         'image_urls', jsonb_build_array('http://169.254.169.254/'))))$q$, current_setting('verif.prod'))) then
    raise exception 'ÉCHEC : l''RPC des variantes accepte une URL';
  end if;

  -- Ce que l'app écrit, lui, passe.
  update public.products
     set image_urls = array['b7eb8585-4091-5b6f-83f7-5d70724e97a3/8c1f0d3e-0d6a-4d34-9a51-2f3f5c1b0a11.jpg',
                            'assets/images/products/textiles/fabric.jpg']
   where id = current_setting('verif.prod');
  update public.product_variants
     set image_urls = array['b7eb8585-4091-5b6f-83f7-5d70724e97a3/photo-1.webp'],
         video_path = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3/video.mp4'
   where product_id = current_setting('verif.prod');
end $$;
reset role;

\o
select 'TOUTES LES VÉRIFICATIONS PASSENT' as resultat;
rollback;
