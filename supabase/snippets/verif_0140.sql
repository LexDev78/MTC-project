-- Vérifie 0140 (identité des commentaires produit, vue sans identifiants)
-- contre une base où elle est appliquée, sans rien y laisser : tout se passe
-- dans une transaction annulée.
--
--   docker exec -i supabase_db_mtc_verif psql -U postgres -d postgres -q \
--     < supabase/snippets/verif_0140.sql
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
create function verif.notifs(p_user uuid) returns bigint language sql security definer as $$
  select count(*) from public.notifications where user_id = p_user and type = 'new_comment';
$$;
create function verif.ligne(p_id text) returns public.product_comments language sql security definer as $$
  select * from public.product_comments where id = p_id;
$$;
grant execute on all functions in schema verif to anon, authenticated;

\set bogolan 'b7eb8585-4091-5b6f-83f7-5d70724e97a3'
\set mopti 'b8e6fcc1-ef1c-5248-8ffa-5de27e9beebb'
\set awa '04060d99-e34d-520e-8b75-631ff4d3c10c'
\set moussa '3355adef-385d-5eee-a565-815c8cf8e4d3'

-- Un produit en vente de Bogolan, un autre de Bogolan, un produit non public
-- (Artisanat Sikasso, dossier en attente).
select id as prod from public.products where supplier_id = :'bogolan' and status = 'active' and is_supplier_verified order by id limit 1 \gset
select id as prod2 from public.products where supplier_id = :'bogolan' and status = 'active' and is_supplier_verified order by id offset 1 limit 1 \gset
select id as cache from public.products where supplier_id = 'b6b1daf0-1c8e-583f-939f-687991d429ca' limit 1 \gset
select set_config('verif.prod', :'prod', true), set_config('verif.prod2', :'prod2', true),
       set_config('verif.cache', :'cache', true);

-- Deux collaborateurs de Bogolan : l'un sans les produits, l'autre avec.
insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data, raw_user_meta_data) values
  ('cccccccc-0000-4000-8000-000000000140', '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'verif-collab-140@mtc.local',
   jsonb_build_object('collaborator_of', :'bogolan', 'permissions', jsonb_build_array('messages')),
   jsonb_build_object('username_or_phone', 'verif-collab-140', 'display_name', 'Vendeur A', 'phone_number', '+22370000140')),
  ('cccccccc-0000-4000-8000-000000000141', '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'verif-collab-141@mtc.local',
   jsonb_build_object('collaborator_of', :'bogolan', 'permissions', jsonb_build_array('products')),
   jsonb_build_object('username_or_phone', 'verif-collab-141', 'display_name', 'Vendeur B', 'phone_number', '+22370000141'));

select verif.notifs(:'mopti') as mopti_avant \gset
select verif.notifs(:'bogolan') as bogolan_avant \gset
select set_config('verif.mopti_avant', :'mopti_avant', true), set_config('verif.bogolan_avant', :'bogolan_avant', true);

-- ---- 1. l'attaque de l'audit -----------------------------------------------------------------
set local role authenticated;
select verif.comme(:'awa');
insert into public.product_comments (id, product_id, supplier_id, author_id, author_name, is_supplier, text)
values ('verif-arnaque', :'prod', :'mopti', :'awa', 'Service client MTC', true,
        'Votre boutique sera fermée : envoyez 5000 FCFA au +22370000000');
do $$
declare
  c public.product_comments := verif.ligne('verif-arnaque');
begin
  if c.supplier_id <> 'b7eb8585-4091-5b6f-83f7-5d70724e97a3' then
    raise exception 'ÉCHEC : le commentaire est adressé à une autre boutique (%)', c.supplier_id;
  end if;
  if c.is_supplier then
    raise exception 'ÉCHEC : un client porte le badge vendeur';
  end if;
  if c.author_name <> 'Awa Traoré' then
    raise exception 'ÉCHEC : le commentaire est signé « % »', c.author_name;
  end if;
  if verif.notifs('b8e6fcc1-ef1c-5248-8ffa-5de27e9beebb') <> current_setting('verif.mopti_avant')::bigint then
    raise exception 'ÉCHEC : la boutique choisie par l''auteur est avertie';
  end if;
  if verif.notifs('b7eb8585-4091-5b6f-83f7-5d70724e97a3') <> current_setting('verif.bogolan_avant')::bigint + 1 then
    raise exception 'ÉCHEC : la boutique du produit n''est pas avertie';
  end if;

  -- Une réponse rattachée au commentaire d'un autre produit.
  begin
    insert into public.product_comments (id, product_id, supplier_id, author_id, author_name, text, parent_id)
    values ('verif-detour', current_setting('verif.prod2'), 'b7eb8585-4091-5b6f-83f7-5d70724e97a3',
            auth.uid(), 'x', 'Coucou', 'verif-arnaque');
    raise exception 'ÉCHEC : une réponse se rattache au commentaire d''un autre produit';
  exception when raise_exception then if sqlerrm like 'ÉCHEC%' then raise; end if;
  end;

  -- Un produit qui n'est pas en vente.
  begin
    insert into public.product_comments (id, product_id, supplier_id, author_id, author_name, text)
    values ('verif-cache', current_setting('verif.cache'), 'b6b1daf0-1c8e-583f-939f-687991d429ca',
            auth.uid(), 'x', 'Bonjour');
    raise exception 'ÉCHEC : on commente un produit qui n''est pas en vente';
  exception when raise_exception then if sqlerrm like 'ÉCHEC%' then raise; end if;
  end;

  -- La table ne se lit plus directement.
  begin
    perform 1 from public.product_comments limit 1;
    raise exception 'ÉCHEC : la table des commentaires se lit directement';
  exception when insufficient_privilege then null;
  end;
end $$;

-- ---- 2. la boutique répond, sous son nom ---------------------------------------------------
select verif.comme(:'bogolan');
insert into public.product_comments (id, product_id, supplier_id, author_id, author_name, is_supplier, text, parent_id)
values ('verif-reponse', :'prod', :'bogolan', :'bogolan', 'Ibrahima', false, 'Bonjour, c''est une arnaque.', 'verif-arnaque');
select verif.comme('cccccccc-0000-4000-8000-000000000141');
insert into public.product_comments (id, product_id, supplier_id, author_id, author_name, text)
values ('verif-vendeur-b', :'prod', :'bogolan', 'cccccccc-0000-4000-8000-000000000141', 'Vendeur B', 'Disponible.');
do $$
declare
  r public.product_comments := verif.ligne('verif-reponse');
  b public.product_comments := verif.ligne('verif-vendeur-b');
begin
  if not r.is_supplier or r.author_name <> 'Bogolan Bamako' or r.author_id <> 'b7eb8585-4091-5b6f-83f7-5d70724e97a3' then
    raise exception 'ÉCHEC : la réponse de la boutique n''est pas signée de la boutique (%, %)', r.author_name, r.is_supplier;
  end if;
  if not b.is_supplier or b.author_name <> 'Bogolan Bamako' then
    raise exception 'ÉCHEC : le vendeur qui a les produits ne parle pas au nom de la boutique';
  end if;
end $$;
select verif.comme('cccccccc-0000-4000-8000-000000000140');
do $$ begin
  begin
    insert into public.product_comments (id, product_id, supplier_id, author_id, author_name, text)
    values ('verif-vendeur-a', current_setting('verif.prod'), 'b7eb8585-4091-5b6f-83f7-5d70724e97a3',
            'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'Bogolan Bamako', 'Je réponds pour la boutique.');
    raise exception 'ÉCHEC : un vendeur sans les produits répond au nom de la boutique';
  exception when raise_exception then if sqlerrm like 'ÉCHEC%' then raise; end if;
  end;
end $$;

-- ---- 3. la vue : ce dont l'écran a besoin, sans identifiants ---------------------------------
select verif.comme(:'moussa');
insert into public.comment_likes (comment_id, user_id) values ('verif-arnaque', :'moussa');
select verif.comme(:'awa');
insert into public.comment_likes (comment_id, user_id) values ('verif-arnaque', :'awa');
do $$
declare
  v record;
begin
  select * into v from public.product_comments_with_likes where id = 'verif-arnaque';
  if v.like_count <> 2 or not v.liked_by_me or not v.is_mine then
    raise exception 'ÉCHEC : la vue de l''auteure est fausse (% mentions, aimé %, sien %)',
      v.like_count, v.liked_by_me, v.is_mine;
  end if;
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'product_comments_with_likes'
                and column_name in ('author_id', 'liked_by_user_ids')) then
    raise exception 'ÉCHEC : la vue expose encore des identifiants';
  end if;
  -- Awa ne lit pas la mention de Moussa.
  if exists (select 1 from public.comment_likes where user_id = '3355adef-385d-5eee-a565-815c8cf8e4d3') then
    raise exception 'ÉCHEC : on lit qui a aimé quoi';
  end if;
  -- Et retire la sienne, comme le fait le bouton.
  delete from public.comment_likes where comment_id = 'verif-arnaque' and user_id = auth.uid();
  if (select like_count from public.product_comments_with_likes where id = 'verif-arnaque') <> 1 then
    raise exception 'ÉCHEC : retirer sa mention ne se compte pas';
  end if;
end $$;
select verif.comme(:'moussa');
do $$ begin
  if (select is_mine from public.product_comments_with_likes where id = 'verif-arnaque') then
    raise exception 'ÉCHEC : le commentaire d''Awa passe pour celui de Moussa';
  end if;
end $$;
reset role;

set local role anon;
set local request.jwt.claims to '{"role":"anon"}';
do $$ begin
  if not exists (select 1 from public.product_comments_with_likes where id = 'verif-arnaque') then
    raise exception 'ÉCHEC : un visiteur ne voit plus les commentaires';
  end if;
  begin
    perform 1 from public.comment_likes limit 1;
    raise exception 'ÉCHEC : un visiteur lit les mentions « j''aime »';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- ---- 4. les notes vocales ont leur place -------------------------------------------------------
do $$ begin
  if not (select 'audio/mp4' = any (allowed_mime_types) from storage.buckets where id = 'comment-attachments') then
    raise exception 'ÉCHEC : comment-attachments refuse toujours les notes vocales';
  end if;
end $$;

\o
select 'TOUTES LES VÉRIFICATIONS PASSENT' as resultat;
rollback;
