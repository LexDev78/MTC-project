-- Vérifie 0148 (messages et fichiers), 0149 (jetons, crochet push, mot de
-- passe imposé) et 0150 (droits inutiles) contre une base où elles sont
-- appliquées, sans rien y laisser : tout se passe dans une transaction
-- annulée. Le courriel de vérification (0149, point 3) se vérifie dans
-- `verif_0124.sql` et `verif_0125.sql`.
--
--   docker exec -i supabase_db_mtc_verif psql -U postgres -d postgres -q \
--     < supabase/snippets/verif_0148_0150.sql
--
-- Dernière ligne attendue : « TOUTES LES VÉRIFICATIONS PASSENT ».
\set ON_ERROR_STOP 1
\o /dev/null
begin;
set local client_min_messages = warning;
-- L'API Storage lève ce verrou avant d'effacer ; on fait de même.
select set_config('storage.allow_delete_query', 'true', true);

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
create function verif.touche(p_sql text) returns bigint language plpgsql as $$
declare n bigint;
begin
  execute 'with q as (' || p_sql || ') select count(*) from q' into n;
  return n;
exception when insufficient_privilege then
  return 0;
end $$;
create function verif.objet(p_bucket text, p_nom text) returns boolean language sql security definer as $$
  select exists (select 1 from storage.objects where bucket_id = p_bucket and name = p_nom);
$$;
create function verif.jeton_de(p_token text) returns uuid language sql security definer as $$
  select user_id from public.device_tokens where fcm_token = p_token;
$$;
create function verif.message(p_id text) returns public.chat_messages language sql security definer as $$
  select * from public.chat_messages where id = p_id;
$$;
grant execute on all functions in schema verif to anon, authenticated;

\set awa '04060d99-e34d-520e-8b75-631ff4d3c10c'
\set moussa '3355adef-385d-5eee-a565-815c8cf8e4d3'
\set bogolan 'b7eb8585-4091-5b6f-83f7-5d70724e97a3'
\set electro 'dbff9b88-4829-5eed-b15a-78c33431553f'
\set conv '41889195-7cbf-5b45-8d95-de49a8b47cd0'

-- ---- 1. la note vocale d'une commande à deux boutiques -----------------------------------------
-- Le décor : une commande d'Awa chez Bogolan et chez Electro, et sa note
-- vocale, déposée par elle.
insert into public.orders (id, client_id, client_display_name_snapshot, status, total_fcfa, delivery_city)
values ('verif-cmd-148', :'awa', 'Awa Traoré', 'pending', 2000, 'Bamako');
insert into public.order_supplier_groups (id, order_id, supplier_id, supplier_name, delivery_mode,
                                          delivery_fee_fcfa, subtotal_fcfa, status) values
  ('verif-g-148a', 'verif-cmd-148', :'bogolan', 'Bogolan Bamako', 'self_delivery', 0, 1000, 'pending'),
  ('verif-g-148b', 'verif-cmd-148', :'electro', 'Electro Bamako', 'self_delivery', 0, 1000, 'pending');
set local role authenticated;
select verif.comme(:'awa');
insert into storage.objects (bucket_id, name, owner)
values ('order-messages', 'verif-cmd-148/note.m4a', auth.uid());
-- Electro ne la remplace pas, ne l'efface pas, et n'en dépose pas.
select verif.comme(:'electro');
do $$ begin
  if not exists (select 1 from storage.objects where bucket_id = 'order-messages' and name = 'verif-cmd-148/note.m4a') then
    raise exception 'ÉCHEC : la boutique de la commande n''écoute plus la note du client';
  end if;
  if verif.touche($q$update storage.objects set metadata = '{"x":1}' where bucket_id = 'order-messages'
                     and name = 'verif-cmd-148/note.m4a' returning 1$q$) > 0
     or verif.touche($q$delete from storage.objects where bucket_id = 'order-messages'
                     and name = 'verif-cmd-148/note.m4a' returning 1$q$) > 0 then
    raise exception 'ÉCHEC : une boutique remplace ou efface la note vocale du client';
  end if;
  if not verif.refuse($q$insert into storage.objects (bucket_id, name, owner)
                       values ('order-messages', 'verif-cmd-148/autre.m4a', auth.uid())$q$) then
    raise exception 'ÉCHEC : une boutique dépose une note dans la commande du client';
  end if;
end $$;

-- ---- 2. le fichier d'un message envoyé ---------------------------------------------------------
select verif.comme(:'awa');
insert into storage.objects (bucket_id, name, owner)
values ('chat-attachments', :'conv' || '/photo.jpg', auth.uid()),
       ('chat-attachments', :'conv' || '/brouillon.jpg', auth.uid());
insert into public.chat_messages (id, conversation_id, sender_id, text, attachment_type, attachment_path)
values ('verif-msg-148', :'conv', :'awa', '', 'image', :'conv' || '/photo.jpg');
do $$ begin
  if verif.touche(format($q$update storage.objects set metadata = '{"x":1}' where bucket_id = 'chat-attachments'
                     and name = %L returning 1$q$, '41889195-7cbf-5b45-8d95-de49a8b47cd0/photo.jpg')) > 0 then
    raise exception 'ÉCHEC : le fichier d''un message envoyé se remplace';
  end if;
  if verif.touche(format($q$delete from storage.objects where bucket_id = 'chat-attachments'
                     and name = %L returning 1$q$, '41889195-7cbf-5b45-8d95-de49a8b47cd0/photo.jpg')) > 0 then
    raise exception 'ÉCHEC : le fichier d''un message envoyé s''efface';
  end if;
  -- Un fichier jamais envoyé, lui, s'efface.
  if verif.touche(format($q$delete from storage.objects where bucket_id = 'chat-attachments'
                     and name = %L returning 1$q$, '41889195-7cbf-5b45-8d95-de49a8b47cd0/brouillon.jpg')) <> 1 then
    raise exception 'ÉCHEC : un fichier non envoyé ne s''efface plus';
  end if;
end $$;

-- ---- 3. lister un bucket public ------------------------------------------------------------------
insert into storage.objects (bucket_id, name, owner)
values ('review-media', :'awa' || '/avis.jpg', :'awa');
select verif.comme(:'moussa');
do $$ begin
  if exists (select 1 from storage.objects where bucket_id = 'review-media') then
    raise exception 'ÉCHEC : un autre compte liste les photos d''avis (et les identifiants des clients)';
  end if;
end $$;
select verif.comme(:'awa');
do $$ begin
  if not exists (select 1 from storage.objects where bucket_id = 'review-media' and name like '04060d99%') then
    raise exception 'ÉCHEC : l''auteure ne retrouve plus ses propres fichiers';
  end if;
end $$;

-- ---- 4. la carte produit d'un message --------------------------------------------------------------
select verif.comme(:'bogolan');
do $$
declare
  m public.chat_messages;
  v_produit text := 'b0fe527e-1f73-55e6-b24e-4d985576d473';
begin
  insert into public.chat_messages (id, conversation_id, sender_id, text, product_id,
                                    product_name_snapshot, product_price_fcfa_snapshot, sent_at, is_read)
  values ('verif-carte', '41889195-7cbf-5b45-8d95-de49a8b47cd0', auth.uid(), 'Regardez',
          v_produit, 'Tissu en or', 1, '2020-01-01', true);
  m := verif.message('verif-carte');
  if m.product_name_snapshot <> (select name from public.products where id = v_produit)
     or m.product_price_fcfa_snapshot <> public.effective_unit_price_fcfa(v_produit, null, 1) then
    raise exception 'ÉCHEC : la carte produit garde le nom ou le prix de l''expéditeur (%, %)',
      m.product_name_snapshot, m.product_price_fcfa_snapshot;
  end if;
  if m.sent_at < now() - interval '1 minute' or m.is_read then
    raise exception 'ÉCHEC : l''expéditeur date son message ou le marque lu';
  end if;
  -- Le produit d'une autre boutique.
  if not verif.refuse(format($q$insert into public.chat_messages (id, conversation_id, sender_id, text, product_id)
       values ('verif-carte-2', %L, %L, '', '7a383e7f-0bd1-5d70-9cf7-b17f561f89ef')$q$,
       '41889195-7cbf-5b45-8d95-de49a8b47cd0', auth.uid())) then
    raise exception 'ÉCHEC : une boutique montre le produit d''une autre';
  end if;
end $$;

-- ---- 5. 0149 : le jeton passe au compte connecté ---------------------------------------------------
select verif.comme(:'awa');
select public.register_device_token('verif-telephone-partage');
select verif.comme(:'moussa');
do $$ begin
  if not verif.refuse($q$insert into public.device_tokens (user_id, fcm_token) values (auth.uid(), 'verif-direct')$q$) then
    raise exception 'ÉCHEC : un jeton s''écrit encore directement';
  end if;
  perform public.register_device_token('verif-telephone-partage');
  if verif.jeton_de('verif-telephone-partage') <> auth.uid() then
    raise exception 'ÉCHEC : le téléphone reste au compte précédent';
  end if;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);
do $$ begin
  if not exists (select 1 from public.get_device_tokens_for_notification_user('3355adef-385d-5eee-a565-815c8cf8e4d3')
                  where fcm_token = 'verif-telephone-partage')
     or exists (select 1 from public.get_device_tokens_for_notification_user('04060d99-e34d-520e-8b75-631ff4d3c10c')
                 where fcm_token = 'verif-telephone-partage') then
    raise exception 'ÉCHEC : les notifications d''Awa partent encore sur le téléphone de Moussa';
  end if;
  update public.device_tokens set last_seen_at = now() - interval '61 days' where fcm_token = 'verif-telephone-partage';
  if exists (select 1 from public.get_device_tokens_for_notification_user('3355adef-385d-5eee-a565-815c8cf8e4d3')
              where fcm_token = 'verif-telephone-partage') then
    raise exception 'ÉCHEC : un jeton muet depuis deux mois reçoit encore';
  end if;
end $$;

-- ---- 6. 0149 : pas de secret public pour le crochet push -------------------------------------------
-- Une adresse dans le Vault, sans son secret : rien ne part.
do $$
declare
  v_avant bigint := (select count(*) from net.http_request_queue);
begin
  delete from vault.secrets where name in ('push_function_url', 'push_function_secret');
  perform vault.create_secret('https://exemple.supabase.co/functions/v1/send-push-notification', 'push_function_url');
  insert into public.notifications (id, user_id, type, title, body)
  values ('verif-push', '04060d99-e34d-520e-8b75-631ff4d3c10c', 'order_status_update', 'T', 'B');
  if (select count(*) from net.http_request_queue) <> v_avant then
    raise exception 'ÉCHEC : le crochet push part avec le secret de développement';
  end if;
  if exists (select 1 from net.http_request_queue where headers ->> 'Authorization' = 'Bearer local-dev-push-secret'
               and url like 'https://exemple%') then
    raise exception 'ÉCHEC : secret public envoyé à un projet hébergé';
  end if;
end $$;
-- Ce que la fonction pousse : relu en base, et seulement pour le service.
do $$ begin
  if not has_function_privilege('service_role', 'public.notification_for_push(text)', 'execute')
     or has_function_privilege('authenticated', 'public.notification_for_push(text)', 'execute')
     or has_function_privilege('anon', 'public.notification_for_push(text)', 'execute') then
    raise exception 'ÉCHEC : notification_for_push mal gardée';
  end if;
  if (select title from public.notification_for_push('verif-push')) <> 'T' then
    raise exception 'ÉCHEC : notification_for_push ne relit pas la notification';
  end if;
  update public.notifications set created_at = now() - interval '1 hour' where id = 'verif-push';
  if exists (select 1 from public.notification_for_push('verif-push')) then
    raise exception 'ÉCHEC : une vieille notification se rejoue';
  end if;
end $$;

-- ---- 7. 0149 : le changement de mot de passe imposé est réel -----------------------------------------
update public.profiles set must_change_password = true where id = :'moussa';
set local role authenticated;
select verif.comme(:'moussa');
select public.mark_password_changed();
reset role;
select set_config('request.jwt.claims', '{}', true);
do $$ begin
  if not (select must_change_password from public.profiles where id = '3355adef-385d-5eee-a565-815c8cf8e4d3') then
    raise exception 'ÉCHEC : le drapeau se lève sans changement de mot de passe';
  end if;
  -- Ce que fait GoTrue au changement : le condensat change.
  update auth.users set encrypted_password = extensions.crypt('NouveauMdp1', extensions.gen_salt('bf'))
   where id = '3355adef-385d-5eee-a565-815c8cf8e4d3';
  if (select must_change_password from public.profiles where id = '3355adef-385d-5eee-a565-815c8cf8e4d3') then
    raise exception 'ÉCHEC : le vrai changement ne lève pas le drapeau';
  end if;
  -- Réécrire le même condensat (GoTrue met la ligne à jour pour d'autres
  -- raisons) ne lève rien.
  update public.profiles set must_change_password = true where id = '3355adef-385d-5eee-a565-815c8cf8e4d3';
  update auth.users set encrypted_password = encrypted_password, last_sign_in_at = now()
   where id = '3355adef-385d-5eee-a565-815c8cf8e4d3';
  if not (select must_change_password from public.profiles where id = '3355adef-385d-5eee-a565-815c8cf8e4d3') then
    raise exception 'ÉCHEC : une mise à jour sans changement lève le drapeau';
  end if;
end $$;

-- ---- 8. 0150 : plus de TRUNCATE pour l'API -----------------------------------------------------------
do $$ begin
  if exists (select 1 from information_schema.role_table_grants
              where table_schema = 'public' and grantee in ('anon', 'authenticated')
                and privilege_type in ('TRUNCATE', 'TRIGGER', 'REFERENCES')) then
    raise exception 'ÉCHEC : anon ou authenticated gardent TRUNCATE, TRIGGER ou REFERENCES';
  end if;
  if not has_table_privilege('authenticated', 'public.products', 'select') then
    raise exception 'ÉCHEC : les droits utiles ont été retirés avec';
  end if;
end $$;

\o
select 'TOUTES LES VÉRIFICATIONS PASSENT' as resultat;
rollback;
