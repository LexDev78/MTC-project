-- Vérifie ce que la contre-vérification du 06/11/2026 a fait corriger —
-- dans `0152` et, sur place, dans `0137`–`0150` — contre une base où tout
-- est appliqué, sans rien y laisser : une transaction annulée.
--
--   docker exec -i supabase_db_mtc_verif psql -U postgres -d postgres -q \
--     < supabase/snippets/verif_0152.sql
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
  set constraints all immediate;
  set constraints all deferred;
  return false;
exception when others then
  return true;
end $$;
create function verif.mails(p_to text) returns bigint language sql security definer as $$
  select count(*) from public.mail_log where lower(to_email) = lower(p_to);
$$;
create function verif.stock(p_variante text) returns int language sql security definer as $$
  select stock_quantity from public.product_variants where id = p_variante;
$$;
-- `order_contact_access` est réservée aux fonctions de la base ; on la lit
-- sous l'identité simulée (le jeton reste celui de l'appelant).
create function verif.adresse_visible(p_commande text) returns boolean language sql security definer as $$
  select address from public.order_contact_access(p_commande);
$$;
grant execute on all functions in schema verif to anon, authenticated;

\set awa '04060d99-e34d-520e-8b75-631ff4d3c10c'
\set moussa '3355adef-385d-5eee-a565-815c8cf8e4d3'
\set bogolan 'b7eb8585-4091-5b6f-83f7-5d70724e97a3'
\set sikasso 'b6b1daf0-1c8e-583f-939f-687991d429ca'
\set kayes 'bc82e68c-b1d9-538a-a8ed-8393a5ba739f'
\set electro 'dbff9b88-4829-5eed-b15a-78c33431553f'
\set livreur1 'f1c4e8a2-0000-5000-9000-000000000001'
\set livreur2 'f1c4e8a2-0000-5000-9000-000000000002'
\set boubou '62599202-a3f0-5adc-ae1c-fe2a691adf92'
select id as boubou_v from public.product_variants where product_id = :'boubou' and is_default \gset
select set_config('verif.boubou_v', :'boubou_v', true);

-- Deux collaborateurs de Bogolan : « commandes » seule, et aucune case.
insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data, raw_user_meta_data) values
  ('cccccccc-0000-4000-8000-000000000152', '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'verif-collab-152@mtc.local',
   jsonb_build_object('collaborator_of', :'bogolan', 'permissions', jsonb_build_array('orders')),
   '{"username_or_phone": "verif-collab-152", "display_name": "Vendeur C", "phone_number": "+22370000152"}'),
  ('cccccccc-0000-4000-8000-000000000153', '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'verif-collab-153@mtc.local',
   jsonb_build_object('collaborator_of', :'bogolan', 'permissions', jsonb_build_array()),
   '{"username_or_phone": "verif-collab-153", "display_name": "Vendeur 0", "phone_number": "+22370000153"}');

-- ---- 1. noms réservés : invisibles, diacritiques, sosies, mots coupés ----------------------------
do $$
declare
  v text;
begin
  foreach v in array array[U&'Service client M\200BTC', U&'\0405ervice client MTC', U&'M\0336TC',
                           '𝐌𝐓𝐂 Officiel', 'ᴍᴛᴄ officiel', 'M TC Officiel', 'MT-C Shop', 'rnTC'] loop
    if not public.is_reserved_public_name(v) then
      raise exception 'ÉCHEC : « % » passe pour un nom libre', v;
    end if;
  end loop;
  foreach v in array array['Karim T. Coulibaly', 'Mamadou Tcheka', 'Mohamed Tall', 'Fournier'] loop
    if public.is_reserved_public_name(v) then
      raise exception 'ÉCHEC : « % » est refusé à tort', v;
    end if;
  end loop;
  if not verif.refuse(format($q$update public.profiles set display_name = %L where id = %L$q$,
       U&'Service client M\200BTC', '04060d99-e34d-520e-8b75-631ff4d3c10c')) then
    raise exception 'ÉCHEC : un client se renomme « Service client M<ZWSP>TC »';
  end if;
end $$;

-- ---- 2. pièce jointe d'un commentaire : le dossier de l'auteur, un niveau --------------------------
set local role authenticated;
select verif.comme(:'awa');
do $$
declare
  v text;
begin
  foreach v in array array['/04060d99-e34d-520e-8b75-631ff4d3c10c/x.jpg',
                           '04060d99-e34d-520e-8b75-631ff4d3c10c/../3355adef-385d-5eee-a565-815c8cf8e4d3/x.jpg',
                           '3355adef-385d-5eee-a565-815c8cf8e4d3/x.jpg'] loop
    if not verif.refuse(format($q$insert into public.product_comments (id, product_id, supplier_id, author_id,
         author_name, text, attachment_type, attachment_path)
         values ('verif-pj-' || md5(%L), %L, %L, auth.uid(), 'x', '', 'image', %L)$q$,
         v, '62599202-a3f0-5adc-ae1c-fe2a691adf92', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', v)) then
      raise exception 'ÉCHEC : pièce jointe acceptée : %', v;
    end if;
  end loop;
  insert into public.product_comments (id, product_id, supplier_id, author_id, author_name, text,
                                       attachment_type, attachment_path)
  values ('verif-pj-ok', '62599202-a3f0-5adc-ae1c-fe2a691adf92', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3',
          auth.uid(), 'x', '', 'image', '04060d99-e34d-520e-8b75-631ff4d3c10c/photo.jpg');
end $$;

-- ---- 3. les commentaires sous un avis ne disent plus qui les a écrits -------------------------------
reset role;
set local role anon;
set local request.jwt.claims to '{"role":"anon"}';
do $$ begin
  if not verif.refuse('select author_id from public.review_comments limit 1') then
    raise exception 'ÉCHEC : un visiteur lit author_id des commentaires d''avis';
  end if;
end $$;
reset role;

-- ---- 4. conversation et carte produit -------------------------------------------------------------
set local role authenticated;
select verif.comme(:'awa');
do $$ begin
  if not verif.refuse(format($q$insert into public.chat_conversations (id, client_id, supplier_id,
       client_display_name_snapshot, supplier_name) values ('verif-conv-152', auth.uid(), %L, 'x', 'y')$q$,
       'b6b1daf0-1c8e-583f-939f-687991d429ca')) then
    raise exception 'ÉCHEC : un client ouvre une conversation avec une boutique pas encore vérifiée';
  end if;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);
insert into public.products (id, supplier_id, supplier_name, supplier_type, name, description, category,
                             price_fcfa, stock_quantity, city, weight_kg, status, is_supplier_verified)
select 'verif-brouillon', :'bogolan', 'Bogolan Bamako', 'tiers', 'Pas encore en vente', 'x', category,
       15000, 1, 'Bamako', 1, 'draft', true
  from public.products limit 1;
set local role authenticated;
select verif.comme(:'awa');
do $$ begin
  if not verif.refuse($q$insert into public.chat_messages (id, conversation_id, sender_id, text, product_id)
       values ('verif-carte-brouillon', '41889195-7cbf-5b45-8d95-de49a8b47cd0', auth.uid(), '', 'verif-brouillon')$q$) then
    raise exception 'ÉCHEC : la carte d''un client recopie un produit qui n''est pas en vente';
  end if;
end $$;
reset role;

-- ---- 5. les pièces d'un livreur : son dossier, un niveau -----------------------------------------
select set_config('request.jwt.claims', '{}', true);
update public.couriers set documents_submitted_at = null, status = 'pending' where id = :'livreur2';
set local role authenticated;
select verif.comme(:'livreur2');
do $$ begin
  if not verif.refuse($q$insert into public.courier_documents (id, courier_id, type, file_path)
       values ('verif-pl', auth.uid(), 'driving_licence',
               'f1c4e8a2-0000-5000-9000-000000000002/../f1c4e8a2-0000-5000-9000-000000000001/permis.jpg')$q$) then
    raise exception 'ÉCHEC : un livreur range une pièce hors de son dossier';
  end if;
end $$;
reset role;

-- ---- 6. le code de l'adresse e-mail : les limites ne s'effacent plus ------------------------------
set local role authenticated;
select verif.comme(:'awa');
select public.request_contact_email_code('verif-victime@exemple.ml');
select public.set_my_contact_email(null);
do $$ begin
  if not verif.refuse($q$select public.request_contact_email_code('verif-victime@exemple.ml')$q$) then
    raise exception 'ÉCHEC : vider son adresse remet à zéro l''attente entre deux codes';
  end if;
end $$;
reset role;
-- Cinq codes partis vers une adresse dans la journée : le sixième, de qui
-- que ce soit, ne part pas (et la réponse reste la même).
select set_config('request.jwt.claims', '{}', true);
insert into public.mail_log (request_id, purpose, provider, to_email, created_at)
select -1000 - g, 'contact_email_code', 'mailpit', 'verif-cible@exemple.ml', now() - interval '1 hour'
  from generate_series(1, 5) g;
set local role authenticated;
select verif.comme(:'moussa');
select public.request_contact_email_code('verif-cible@exemple.ml');
reset role;
do $$ begin
  if verif.mails('verif-cible@exemple.ml') <> 5 then
    raise exception 'ÉCHEC : un sixième code part vers la même adresse dans la journée';
  end if;
end $$;

-- ---- 7. noter un livreur, aimer un commentaire : selon le rôle et la case ---------------------------
insert into public.orders (id, client_id, client_display_name_snapshot, status, total_fcfa, delivery_city)
values ('verif-cmd-152', :'awa', 'Awa Traoré', 'delivered', 5000, 'Bamako');
insert into public.order_supplier_groups (id, order_id, supplier_id, supplier_name, delivery_mode,
                                          delivery_fee_fcfa, subtotal_fcfa, status)
values ('verif-g-152', 'verif-cmd-152', :'bogolan', 'Bogolan Bamako', 'mtc_delivery', 1000, 4000, 'delivered');
insert into public.deliveries (id, order_id, supplier_group_id, status, courier_id, accepted_at, picked_up_at, delivered_at)
values ('verif-d-152', 'verif-cmd-152', 'verif-g-152', 'delivered', :'livreur1', now(), now(), now());
set local role authenticated;
select verif.comme('cccccccc-0000-4000-8000-000000000153');
do $$ begin
  if not verif.refuse($q$select public.rate_courier('verif-d-152', 1, 'nul')$q$) then
    raise exception 'ÉCHEC : un collaborateur sans aucune case note le livreur';
  end if;
  if not verif.refuse($q$insert into public.comment_likes (comment_id, user_id)
       values ('verif-pj-ok', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3')$q$) then
    raise exception 'ÉCHEC : un collaborateur sans les produits aime au nom de la boutique';
  end if;
end $$;
select verif.comme('cccccccc-0000-4000-8000-000000000152');
select public.rate_courier('verif-d-152', 4, 'Bien');
select verif.comme(:'livreur1');
do $$ begin
  if not verif.refuse($q$insert into public.comment_likes (comment_id, user_id) values ('verif-pj-ok', auth.uid())$q$) then
    raise exception 'ÉCHEC : un livreur aime un commentaire produit';
  end if;
end $$;
reset role;

-- ---- 8. la vérification suit la boutique, même par le staff ---------------------------------------
set local role authenticated;
select verif.comme('2358888a-b13d-56f8-858b-a0c63831b512');
update public.products set supplier_id = :'sikasso' where id = 'verif-brouillon';
do $$ begin
  if (select is_supplier_verified from public.products where id = 'verif-brouillon') then
    raise exception 'ÉCHEC : un produit passé à une boutique en attente reste vérifié';
  end if;
  if not verif.refuse($q$select public.set_products_supplier_verification('b6b1daf0-1c8e-583f-939f-687991d429ca', true)$q$) then
    raise exception 'ÉCHEC : le staff rend vérifiés les produits d''une boutique en attente';
  end if;
end $$;
reset role;

-- ---- 9. la ville d'une boutique vérifiée ; le livreur encaisse ce qui n'est pas payé -----------------
set local role authenticated;
select verif.comme(:'bogolan');
do $$ begin
  if not verif.refuse($q$update public.suppliers set city = 'Kayes' where id = auth.uid()$q$) then
    raise exception 'ÉCHEC : une boutique vérifiée change la ville d''où partent ses courses';
  end if;
end $$;
select verif.comme(:'kayes');
update public.suppliers set city = 'Kayes' where id = :'kayes';
reset role;
select set_config('request.jwt.claims', '{}', true);
insert into public.orders (id, client_id, client_display_name_snapshot, status, total_fcfa, delivery_city,
                           payment_method, payment_status)
values ('verif-cmd-now', :'awa', 'Awa Traoré', 'in_transit', 5000, 'Bamako', 'now', 'pending_on_delivery');
insert into public.order_supplier_groups (id, order_id, supplier_id, supplier_name, delivery_mode,
                                          delivery_fee_fcfa, subtotal_fcfa, status)
values ('verif-g-now', 'verif-cmd-now', :'electro', 'Electro Bamako', 'mtc_delivery', 1000, 4000, 'in_transit');
insert into public.deliveries (id, order_id, supplier_group_id, status, courier_id, accepted_at)
values ('verif-d-now', 'verif-cmd-now', 'verif-g-now', 'accepted', :'livreur1', now());
-- Et une offre expirée faite à livreur2, sur une autre commande d'Awa.
insert into public.orders (id, client_id, client_display_name_snapshot, status, total_fcfa, delivery_city)
values ('verif-cmd-exp', :'awa', 'Awa Traoré', 'confirmed', 5000, 'Bamako');
insert into public.order_supplier_groups (id, order_id, supplier_id, supplier_name, delivery_mode,
                                          delivery_fee_fcfa, subtotal_fcfa, status)
values ('verif-g-exp', 'verif-cmd-exp', :'electro', 'Electro Bamako', 'mtc_delivery', 1000, 4000, 'confirmed');
insert into public.order_contacts (order_id, client_phone, address_label, address_details, latitude, longitude)
values ('verif-cmd-exp', '+22370000001', 'Maison', 'Rue 1', 12.6, -8.0);
insert into public.deliveries (id, order_id, supplier_group_id, status, offered_to_courier_id, offered_at, offer_expires_at)
values ('verif-d-exp', 'verif-cmd-exp', 'verif-g-exp', 'offered', :'livreur2', now() - interval '10 minutes',
        now() - interval '5 minutes');
update public.couriers set status = 'approved' where id = :'livreur2';
set local role authenticated;
select verif.comme(:'livreur1');
do $$ begin
  if not (select (public.courier_order(d) ->> 'collect_on_delivery')::boolean
            from public.deliveries d where d.id = 'verif-d-now') then
    raise exception 'ÉCHEC : une commande « payer maintenant » impayée ne s''encaisse pas à la remise';
  end if;
end $$;
select verif.comme(:'livreur2');
do $$ begin
  if verif.adresse_visible('verif-cmd-exp')
     or (select public.courier_order(d) from public.deliveries d where d.id = 'verif-d-exp') is not null
     or (select public.pickup_point(d) from public.deliveries d where d.id = 'verif-d-exp') is not null then
    raise exception 'ÉCHEC : une offre expirée montre encore l''adresse du client ou le point de retrait';
  end if;
end $$;
reset role;

-- ---- 10. une commande annulée rend son stock — même annulée par un vendeur « commandes » -------------
set local role authenticated;
select verif.comme(:'awa');
select verif.stock(current_setting('verif.boubou_v')) as avant \gset
select set_config('verif.avant', :'avant', true);
select public.place_order('Awa', '+22370000001',
  jsonb_build_array(jsonb_build_object('supplier_id', :'bogolan', 'delivery_mode', 'self_delivery',
    'items', jsonb_build_array(jsonb_build_object('product_id', :'boubou', 'variant_id', :'boubou_v', 'quantity', 2)))),
  'Maison', 'Bamako', 'Rue 1', 12.6, -8.0) as cmd_a \gset
select public.place_order('Awa', '+22370000001',
  jsonb_build_array(jsonb_build_object('supplier_id', :'bogolan', 'delivery_mode', 'self_delivery',
    'items', jsonb_build_array(jsonb_build_object('product_id', :'boubou', 'variant_id', :'boubou_v', 'quantity', 1)))),
  'Maison', 'Bamako', 'Rue 1', 12.6, -8.0) as cmd_b \gset
select id as grp_a from public.order_supplier_groups where order_id = :'cmd_a' \gset
select id as grp_b from public.order_supplier_groups where order_id = :'cmd_b' \gset
select public.update_order_group_status(:'cmd_a', :'grp_a', 'cancelled', 'Changé d''avis');
select verif.comme('cccccccc-0000-4000-8000-000000000152');
select public.update_order_group_status(:'cmd_b', :'grp_b', 'cancelled', 'Rupture');
do $$ begin
  if verif.stock(current_setting('verif.boubou_v')) <> current_setting('verif.avant')::int then
    raise exception 'ÉCHEC : les commandes annulées n''ont pas rendu leur stock (% au lieu de %)',
      verif.stock(current_setting('verif.boubou_v')), current_setting('verif.avant');
  end if;
end $$;
reset role;

-- ---- 11. comptes supprimés : collaborateur, livreur -------------------------------------------------
set local role authenticated;
select verif.comme('cccccccc-0000-4000-8000-000000000152');
select public.deactivate_account();
do $$ begin
  if public.operating_supplier_id() is not null or public.supplier_can('orders') then
    raise exception 'ÉCHEC : un collaborateur qui a supprimé son compte opère encore la boutique';
  end if;
end $$;
select verif.comme(:'livreur2');
select public.deactivate_account();
reset role;
do $$ begin
  if (select is_online or status <> 'suspended' from public.couriers
       where id = 'f1c4e8a2-0000-5000-9000-000000000002') then
    raise exception 'ÉCHEC : un livreur supprimé reste en ligne et approuvé';
  end if;
end $$;

-- ---- 12. le crochet push, le dossier d'une boutique supprimée, MAINTAIN ---------------------------------
select set_config('request.jwt.claims', '{}', true);
do $$
declare
  v_avant bigint := (select count(*) from net.http_request_queue);
begin
  delete from vault.secrets where name in ('push_function_url', 'push_function_secret');
  perform vault.create_secret('un-vrai-secret-de-plus-de-trente-deux-car', 'push_function_secret');
  insert into public.notifications (id, user_id, type, title, body)
  values ('verif-push-152', '04060d99-e34d-520e-8b75-631ff4d3c10c', 'order_status_update', 'T', 'B');
  if (select count(*) from net.http_request_queue) <> v_avant then
    raise exception 'ÉCHEC : le vrai secret part en clair vers l''adresse locale de repli';
  end if;
  update public.suppliers set deleted_at = now() where id = 'b8e6fcc1-ef1c-5248-8ffa-5de27e9beebb';
  if exists (select 1 from public.product_trusted_source('b8e6fcc1-ef1c-5248-8ffa-5de27e9beebb')) then
    raise exception 'ÉCHEC : product_trusted_source montre une boutique supprimée';
  end if;
  if has_table_privilege('authenticated', 'public.orders', 'MAINTAIN')
     or has_table_privilege('anon', 'public.profiles', 'MAINTAIN') then
    raise exception 'ÉCHEC : l''API peut encore verrouiller une table entière (MAINTAIN)';
  end if;
end $$;

\o
select 'TOUTES LES VÉRIFICATIONS PASSENT' as resultat;
rollback;
