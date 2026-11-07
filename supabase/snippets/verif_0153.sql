-- Vérifie `0153` — ce qu'un client retient sans payer, l'annulation des
-- commandes que personne ne confirme, le rythme des messages et des
-- commentaires — contre une base où tout est appliqué, sans rien y laisser :
-- une transaction annulée.
--
--   docker exec -i supabase_db_mtc_verif psql -U postgres -d postgres -q \
--     < supabase/snippets/verif_0153.sql
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
-- Le message d'erreur de `p_sql`, ou null s'il passe.
create function verif.erreur(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return null;
exception when others then
  return sqlerrm;
end $$;
create function verif.stock(p_variante text) returns int language sql security definer as $$
  select stock_quantity from public.product_variants where id = p_variante;
$$;
create function verif.regle(p_key text, p_value jsonb) returns void language sql security definer as $$
  insert into public.app_settings (key, value) values (p_key, p_value)
  on conflict (key) do update set value = excluded.value;
$$;
create function verif.sans_regles() returns void language sql security definer as $$
  delete from public.app_settings where key <> 'staff_mfa_required';
$$;
create function verif.groupe(p_commande text) returns text language sql security definer as $$
  select id from public.order_supplier_groups where order_id = p_commande;
$$;
-- Une commande d'un seul article, livrée par la boutique quand elle le
-- propose, sous l'identité simulée.
create function verif.commande(p_variante text, p_quantite int) returns text language sql as $$
  select public.place_order('x', '+22370000001',
    jsonb_build_array(jsonb_build_object(
      'supplier_id', p.supplier_id,
      'delivery_mode', case when p.allows_self_delivery then 'self_delivery' else 'mtc_delivery' end,
      'items', jsonb_build_array(jsonb_build_object(
        'product_id', p.id, 'variant_id', v.id, 'quantity', p_quantite)))),
    'Maison', 'Bamako', 'Rue 1', 12.6, -8.0)
    from public.product_variants v
    join public.products p on p.id = v.product_id
   where v.id = p_variante;
$$;
grant execute on all functions in schema verif to anon, authenticated;

\set awa '04060d99-e34d-520e-8b75-631ff4d3c10c'
\set moussa '3355adef-385d-5eee-a565-815c8cf8e4d3'
\set bogolan 'b7eb8585-4091-5b6f-83f7-5d70724e97a3'
\set mtc '3331cbb4-0a65-5f94-9812-fe4270e50fe2'
\set boubou '62599202-a3f0-5adc-ae1c-fe2a691adf92'
\set riz 'd9d25e13-71ac-51c4-93f7-ed042a996500'
\set conv_awa '41889195-7cbf-5b45-8d95-de49a8b47cd0'
\set conv_moussa '2fbdae8c-afc9-5053-b47a-6e46ab1a9361'
\set avis_moussa 'c3d4d48f-f9a9-59b5-8798-4a9964995afa'
select id as boubou_v from public.product_variants where product_id = :'boubou' and is_default \gset
select id as riz_v from public.product_variants where product_id = :'riz' and is_default \gset
select set_config('verif.boubou_v', :'boubou_v', true), set_config('verif.riz_v', :'riz_v', true),
       set_config('verif.bogolan', :'bogolan', true), set_config('verif.mtc', :'mtc', true),
       set_config('verif.conv_awa', :'conv_awa', true), set_config('verif.conv_moussa', :'conv_moussa', true),
       set_config('verif.boubou', :'boubou', true), set_config('verif.avis', :'avis_moussa', true);

-- Des clientes neuves, sans rien en cours ; et du stock, pour que le
-- plafond — pas la rupture — soit ce qui refuse.
insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data, raw_user_meta_data)
select ('cccccccc-0000-4000-8000-00000000153' || n)::uuid, '00000000-0000-0000-0000-000000000000',
       'authenticated', 'authenticated', 'verif-cliente-153' || n || '@mtc.local', '{}'::jsonb,
       jsonb_build_object('username_or_phone', 'verif-cliente-153' || n, 'display_name', 'Cliente ' || n,
                          'phone_number', '+2237000153' || n)
  from generate_series(1, 7) n;
update public.product_variants set stock_quantity = 100 where id in (:'boubou_v', :'riz_v');
select verif.sans_regles();

-- ---- 1. dix exemplaires d'un même article, tant que ce n'est pas payé -------------------------------
select verif.regle('unpaid_value_fcfa_max', '100000000');
set local role authenticated;
select verif.comme('cccccccc-0000-4000-8000-000000001531');
do $$
declare
  v text;
begin
  v := verif.erreur(format('select verif.commande(%L, 11)', current_setting('verif.boubou_v')));
  if v is null or v not like '« Boubou en bogolan brodé » : 10 exemplaires au plus par client%' then
    raise exception 'ÉCHEC : 11 boubous non payés passent (%)', v;
  end if;
  perform verif.commande(current_setting('verif.boubou_v'), 10);
  v := verif.erreur(format('select verif.commande(%L, 1)', current_setting('verif.boubou_v')));
  if v is null or v not like '%(vous en avez déjà 10 en cours).' then
    raise exception 'ÉCHEC : un 11e boubou passe par une seconde commande (%)', v;
  end if;
  -- Un autre article reste libre.
  perform verif.commande(current_setting('verif.riz_v'), 3);
end $$;
reset role;
-- Payée, la commande ne retient plus rien.
update public.orders o set payment_status = 'paid'
 where o.client_id = 'cccccccc-0000-4000-8000-000000001531'
   and exists (select 1 from public.order_supplier_groups g
                 join public.order_items i on i.group_id = g.id
                where g.order_id = o.id and i.variant_id = :'boubou_v');
set local role authenticated;
select verif.comme('cccccccc-0000-4000-8000-000000001531');
do $$ begin
  if verif.erreur(format('select verif.commande(%L, 10)', current_setting('verif.boubou_v'))) is not null then
    raise exception 'ÉCHEC : une commande payée retient encore ses 10 boubous';
  end if;
end $$;
reset role;

-- ---- 2. trois commandes en cours chez une même boutique ---------------------------------------------
set local role authenticated;
select verif.comme('cccccccc-0000-4000-8000-000000001532');
do $$
declare
  v text;
  v_premiere text;
begin
  v_premiere := verif.commande(current_setting('verif.boubou_v'), 1);
  perform verif.commande(current_setting('verif.boubou_v'), 1);
  perform verif.commande(current_setting('verif.boubou_v'), 1);
  v := verif.erreur(format('select verif.commande(%L, 1)', current_setting('verif.boubou_v')));
  if v is null or v not like 'Vous avez déjà 3 commandes en cours chez Bogolan Bamako%' then
    raise exception 'ÉCHEC : une 4e commande en cours chez la même boutique passe (%)', v;
  end if;
  -- Une autre boutique reste ouverte ; une annulation en libère une.
  perform verif.commande(current_setting('verif.riz_v'), 1);
  perform public.update_order_group_status(v_premiere, verif.groupe(v_premiere), 'cancelled', 'Changé d''avis');
  if verif.erreur(format('select verif.commande(%L, 1)', current_setting('verif.boubou_v'))) is not null then
    raise exception 'ÉCHEC : une commande annulée compte encore parmi celles en cours';
  end if;
end $$;
reset role;

-- ---- 3. 200 000 FCFA en cours, et l'article seul ----------------------------------------------------
select verif.sans_regles();
set local role authenticated;
select verif.comme('cccccccc-0000-4000-8000-000000001533');
do $$
declare
  v text;
begin
  -- 4 × 45 000 = 180 000 : sous le plafond.
  perform verif.commande(current_setting('verif.boubou_v'), 4);
  -- Un article seul passe tant que le reste tient : 225 000 en cours.
  perform verif.commande(current_setting('verif.boubou_v'), 1);
  -- Plus rien ensuite, pas même seul, et ailleurs non plus.
  v := verif.erreur(format('select verif.commande(%L, 1)', current_setting('verif.riz_v')));
  if v is null or v <> 'Vos commandes non payées ne peuvent pas dépasser 200 000 FCFA d''articles en tout : '
                      'vous en avez déjà 225 000 FCFA en cours, celle-ci en ajoute 12 500 FCFA.' then
    raise exception 'ÉCHEC : le plafond en valeur ne tient pas (%)', v;
  end if;
end $$;
reset role;
-- Un article plus cher que le plafond, seul : il passe ; à deux, non.
select verif.regle('unpaid_value_fcfa_max', '40000');
set local role authenticated;
select verif.comme('cccccccc-0000-4000-8000-000000001534');
do $$
declare
  v text;
begin
  v := verif.erreur(format('select verif.commande(%L, 2)', current_setting('verif.boubou_v')));
  if v is null or v not like '%celle-ci en compte 90 000 FCFA — un article seul passe, quel que soit son prix.' then
    raise exception 'ÉCHEC : deux articles au-dessus du plafond passent (%)', v;
  end if;
  if verif.erreur(format('select verif.commande(%L, 1)', current_setting('verif.boubou_v'))) is not null then
    raise exception 'ÉCHEC : un article seul plus cher que le plafond est refusé';
  end if;
  v := verif.erreur(format('select verif.commande(%L, 1)', current_setting('verif.riz_v')));
  if v is null or v not like '%vous en avez déjà 45 000 FCFA en cours%' then
    raise exception 'ÉCHEC : l''article seul ouvre la porte à la suite (%)', v;
  end if;
end $$;
reset role;

-- ---- 4. dix commandes par heure, annulées comprises -------------------------------------------------
select verif.sans_regles();
select verif.regle('orders_per_hour_max', '2');
set local role authenticated;
select verif.comme('cccccccc-0000-4000-8000-000000001535');
do $$
declare
  v text;
  v_premiere text;
begin
  v_premiere := verif.commande(current_setting('verif.riz_v'), 1);
  perform public.update_order_group_status(v_premiere, verif.groupe(v_premiere), 'cancelled', 'Erreur');
  perform verif.commande(current_setting('verif.riz_v'), 1);
  v := verif.erreur(format('select verif.commande(%L, 1)', current_setting('verif.riz_v')));
  if v is null or v not like 'Vous avez passé beaucoup de commandes en une heure%' then
    raise exception 'ÉCHEC : commander et annuler en boucle n''est pas freiné (%)', v;
  end if;
end $$;
reset role;
-- Un réglage illisible ou nul ne lève pas le plafond : il reprend le défaut.
do $$ begin
  perform verif.regle('orders_per_hour_max', '"beaucoup"');
  if public.app_setting_int('orders_per_hour_max', 10) <> 10 then
    raise exception 'ÉCHEC : un réglage texte est lu comme un nombre';
  end if;
  perform verif.regle('orders_per_hour_max', '0');
  if public.app_setting_int('orders_per_hour_max', 10) <> 10 then
    raise exception 'ÉCHEC : un réglage à 0 bloque toutes les commandes';
  end if;
  perform verif.regle('orders_per_hour_max', '2.7');
  if public.app_setting_int('orders_per_hour_max', 10) <> 2 then
    raise exception 'ÉCHEC : un réglage décimal est mal lu';
  end if;
  perform verif.sans_regles();
end $$;

-- ---- 5. la commande que la boutique ne confirme pas s'annule seule --------------------------------
set local role authenticated;
select verif.comme('cccccccc-0000-4000-8000-000000001536');
select verif.commande(:'boubou_v', 2) as cmd_x \gset
select verif.commande(:'boubou_v', 1) as cmd_y \gset
select verif.commande(:'riz_v', 1) as cmd_z \gset
select verif.commande(:'riz_v', 1) as cmd_w \gset
select verif.comme(:'bogolan');
select public.update_order_group_status(:'cmd_y', verif.groupe(:'cmd_y'), 'confirmed');
reset role;
select set_config('request.jwt.claims', '{}', true);
update public.orders set payment_status = 'paid' where id = :'cmd_z';
update public.orders set placed_at = now() - interval '25 hours' where id in (:'cmd_x', :'cmd_y', :'cmd_z');
update public.orders set placed_at = now() - interval '23 hours' where id = :'cmd_w';
select set_config('verif.cmd_x', :'cmd_x', true), set_config('verif.cmd_y', :'cmd_y', true),
       set_config('verif.cmd_z', :'cmd_z', true), set_config('verif.cmd_w', :'cmd_w', true),
       set_config('verif.avant', verif.stock(:'boubou_v')::text, true);
do $$
declare
  v_groupe record;
  v_annulees integer;
begin
  if public.cancel_unconfirmed_orders() <> 1 then
    raise exception 'ÉCHEC : l''annulation automatique ne prend pas exactement la commande en attente depuis 25 h';
  end if;
  select g.status, g.cancelled_by, g.cancellation_reason, o.status as order_status into v_groupe
    from public.order_supplier_groups g join public.orders o on o.id = g.order_id
   where g.order_id = current_setting('verif.cmd_x');
  if v_groupe.status <> 'cancelled' or v_groupe.cancelled_by <> 'mtc'
     or v_groupe.cancellation_reason <> 'la boutique ne l''a pas confirmée sous 24 h'
     or v_groupe.order_status <> 'cancelled' then
    raise exception 'ÉCHEC : commande expirée mal annulée (%)', v_groupe;
  end if;
  if verif.stock(current_setting('verif.boubou_v')) <> current_setting('verif.avant')::int + 2 then
    raise exception 'ÉCHEC : l''annulation automatique n''a pas rendu le stock';
  end if;
  if (select status from public.order_supplier_groups where order_id = current_setting('verif.cmd_y')) <> 'confirmed'
     or (select status from public.order_supplier_groups where order_id = current_setting('verif.cmd_z')) <> 'pending'
     or (select status from public.order_supplier_groups where order_id = current_setting('verif.cmd_w')) <> 'pending' then
    raise exception 'ÉCHEC : une commande confirmée, payée ou récente a été annulée';
  end if;
  if not exists (select 1 from public.notifications
                  where user_id = 'cccccccc-0000-4000-8000-000000001536'
                    and reference_id = current_setting('verif.cmd_x')
                    and body = 'Votre commande a été annulée : la boutique ne l''a pas confirmée sous 24 h.')
     or not exists (select 1 from public.notifications
                     where user_id = current_setting('verif.bogolan')::uuid
                       and reference_id = current_setting('verif.cmd_x')
                       and title = 'Commande annulée'
                       and body like 'La commande de Cliente 6 est annulée faute de confirmation sous 24 h%') then
    raise exception 'ÉCHEC : le client ou la boutique n''est pas prévenu de l''annulation automatique';
  end if;
  -- Le délai se règle.
  perform verif.regle('unconfirmed_order_expiry_hours', '22');
  v_annulees := public.cancel_unconfirmed_orders();
  if v_annulees <> 1
     or (select status from public.order_supplier_groups where order_id = current_setting('verif.cmd_w')) <> 'cancelled' then
    raise exception 'ÉCHEC : le délai réglé à 22 h n''annule pas la commande de 23 h (% annulées, statut %)',
      v_annulees, (select status from public.order_supplier_groups where order_id = current_setting('verif.cmd_w'));
  end if;
  perform verif.sans_regles();
  if (select count(*) from cron.job
       where active and ((jobname = 'mtc-commandes-non-confirmees' and schedule = '*/15 * * * *'
                          and command = 'select public.cancel_unconfirmed_orders()')
                      or (jobname = 'mtc-purge-activite' and command = 'select public.prune_activity_events()')
                      or (jobname = 'mtc-purge-rythme' and command like 'delete from public.post_rate_events%'))) <> 3 then
    raise exception 'ÉCHEC : les tâches planifiées manquent';
  end if;
  if exists (select 1 from cron.job where jobname like 'mtc-%' and username <> 'postgres') then
    raise exception 'ÉCHEC : une tâche planifiée tourne sous un autre rôle que postgres';
  end if;
end $$;

-- ---- 6. vingt messages par minute, une notification par conversation ------------------------------
set local role authenticated;
select verif.comme(:'awa');
do $$
declare
  v text;
begin
  v := verif.erreur(format($q$insert into public.chat_messages (id, conversation_id, sender_id, text)
       select 'verif-msg-' || n, %L, auth.uid(), 'Message ' || n from generate_series(1, 21) n$q$,
       current_setting('verif.conv_awa')));
  if v is null or v <> 'Vous envoyez trop de messages à la suite : patientez une minute.' then
    raise exception 'ÉCHEC : 21 messages en une requête passent (%)', v;
  end if;
  if exists (select 1 from public.chat_messages where id like 'verif-msg-%') then
    raise exception 'ÉCHEC : la requête refusée a laissé des messages';
  end if;
  insert into public.chat_messages (id, conversation_id, sender_id, text)
  select 'verif-msg-' || n, current_setting('verif.conv_awa'), auth.uid(), 'Message ' || n
    from generate_series(1, 20) n;
  if verif.erreur(format($q$insert into public.chat_messages (id, conversation_id, sender_id, text)
       values ('verif-msg-21', %L, auth.uid(), 'Encore')$q$, current_setting('verif.conv_awa'))) is null then
    raise exception 'ÉCHEC : un 21e message dans la minute passe';
  end if;
end $$;
reset role;
do $$ begin
  if (select count(*) from public.notifications
       where user_id = current_setting('verif.bogolan')::uuid and type = 'new_message'
         and reference_id = current_setting('verif.conv_awa') and created_at = now()) <> 1
     or (select title from public.notifications
          where user_id = current_setting('verif.bogolan')::uuid and type = 'new_message'
            and reference_id = current_setting('verif.conv_awa') and created_at = now()) <> 'Nouveaux messages' then
    raise exception 'ÉCHEC : vingt messages font plus d''une notification à la boutique';
  end if;
end $$;

-- Passé 10 minutes, ou lue, la notification laisse place à une nouvelle.
set local role authenticated;
select verif.comme(:'moussa');
insert into public.chat_messages (id, conversation_id, sender_id, text)
values ('verif-mou-1', :'conv_moussa', auth.uid(), 'Bonjour');
insert into public.chat_messages (id, conversation_id, sender_id, text)
values ('verif-mou-2', :'conv_moussa', auth.uid(), 'Vous êtes là ?');
reset role;
update public.notifications set created_at = now() - interval '11 minutes'
 where user_id = :'mtc' and reference_id = :'conv_moussa' and created_at = now();
set local role authenticated;
select verif.comme(:'moussa');
insert into public.chat_messages (id, conversation_id, sender_id, text)
values ('verif-mou-3', :'conv_moussa', auth.uid(), 'Toujours là ?');
reset role;
update public.notifications set is_read = true
 where user_id = :'mtc' and reference_id = :'conv_moussa' and created_at = now();
set local role authenticated;
select verif.comme(:'moussa');
insert into public.chat_messages (id, conversation_id, sender_id, text)
values ('verif-mou-4', :'conv_moussa', auth.uid(), 'Merci');
reset role;
do $$ begin
  if (select count(*) from public.notifications
       where user_id = current_setting('verif.mtc')::uuid and type = 'new_message'
         and reference_id = current_setting('verif.conv_moussa')
         and created_at >= now() - interval '12 minutes') <> 3 then
    raise exception 'ÉCHEC : le regroupement ne s''arrête ni après 10 minutes, ni à la lecture';
  end if;
  if (select body from public.notifications
       where user_id = current_setting('verif.mtc')::uuid and type = 'new_message'
         and reference_id = current_setting('verif.conv_moussa')
         and created_at = now() - interval '11 minutes') <> 'Vous êtes là ?' then
    raise exception 'ÉCHEC : la notification regroupée ne montre pas le dernier message';
  end if;
end $$;

-- 300 par heure (réglé ici à 25) : vingt envois d'il y a une demi-heure
-- comptent ; ceux d'il y a deux heures, non.
select verif.regle('messages_per_hour_max', '25');
select set_config('request.jwt.claims', '{}', true);
insert into public.post_rate_events (author_id, kind, at)
select :'moussa', 'chat_messages', now() - interval '30 minutes' from generate_series(1, 20);
insert into public.post_rate_events (author_id, kind, at)
select :'moussa', 'chat_messages', now() - interval '2 hours' from generate_series(1, 50);
set local role authenticated;
select verif.comme(:'moussa');
do $$
declare
  v text;
begin
  -- 20 + 4 dans l'heure : un de plus passe, le suivant non.
  insert into public.chat_messages (id, conversation_id, sender_id, text)
  values ('verif-mou-5', current_setting('verif.conv_moussa'), auth.uid(), 'Le 25e');
  v := verif.erreur(format($q$insert into public.chat_messages (id, conversation_id, sender_id, text)
       values ('verif-mou-6', %L, auth.uid(), 'Le 26e')$q$, current_setting('verif.conv_moussa')));
  if v is null or v <> 'Vous avez envoyé 25 messages en une heure : patientez avant d''en envoyer d''autres.' then
    raise exception 'ÉCHEC : le plafond par heure ne tient pas (%)', v;
  end if;
end $$;
reset role;
select verif.sans_regles();

-- ---- 7. dix commentaires par minute, une notification par produit ---------------------------------
set local role authenticated;
select verif.comme(:'awa');
do $$
declare
  v text;
begin
  v := verif.erreur(format($q$insert into public.product_comments (id, product_id, supplier_id, author_id,
       author_name, text, created_at)
       select 'verif-com-' || n, %L, %L, auth.uid(), 'x', 'Question ' || n, '2020-01-01'
         from generate_series(1, 11) n$q$, current_setting('verif.boubou'), current_setting('verif.bogolan')));
  if v is null or v <> 'Vous envoyez trop de commentaires à la suite : patientez une minute.' then
    raise exception 'ÉCHEC : 11 commentaires en une requête passent (%)', v;
  end if;
  insert into public.product_comments (id, product_id, supplier_id, author_id, author_name, text, created_at)
  select 'verif-com-' || n, current_setting('verif.boubou'), current_setting('verif.bogolan')::uuid,
         auth.uid(), 'x', 'Question ' || n, '2020-01-01'
    from generate_series(1, 10) n;
end $$;
reset role;
do $$ begin
  if exists (select 1 from public.product_comments where id like 'verif-com-%' and created_at <> now()) then
    raise exception 'ÉCHEC : un commentaire garde la date de la requête';
  end if;
  if (select count(*) from public.notifications
       where user_id = current_setting('verif.bogolan')::uuid and type = 'new_comment'
         and reference_id = current_setting('verif.boubou') and created_at = now()) <> 1
     or (select title from public.notifications
          where user_id = current_setting('verif.bogolan')::uuid and type = 'new_comment'
            and reference_id = current_setting('verif.boubou') and created_at = now()) <> 'Nouveaux commentaires' then
    raise exception 'ÉCHEC : dix commentaires font plus d''une notification à la boutique';
  end if;
end $$;

-- ---- 8. sous un avis : la date de la base, et le même plafond -------------------------------------
set local role authenticated;
select verif.comme(:'awa');
do $$ begin
  insert into public.review_comments (id, review_id, author_id, body, created_at)
  values ('verif-rc-0', current_setting('verif.avis'), auth.uid(), 'Merci pour l''avis', '2020-01-01');
  insert into public.review_comments (id, review_id, author_id, body)
  select 'verif-rc-' || n, current_setting('verif.avis'), auth.uid(), 'Merci ' || n
    from generate_series(1, 9) n;
  if verif.erreur(format($q$insert into public.review_comments (id, review_id, author_id, body)
       values ('verif-rc-10', %L, auth.uid(), 'Un de trop')$q$, current_setting('verif.avis'))) is null then
    raise exception 'ÉCHEC : un 11e commentaire d''avis dans la minute passe';
  end if;
  -- Effacer ses commentaires ne remet pas le compteur à zéro.
  delete from public.review_comments where id like 'verif-rc-%';
  if exists (select 1 from public.review_comments where id like 'verif-rc-%') then
    raise exception 'ÉCHEC : l''auteur n''a pas pu effacer ses commentaires d''avis (le test ne prouve rien)';
  end if;
  if verif.erreur(format($q$insert into public.review_comments (id, review_id, author_id, body)
       values ('verif-rc-11', %L, auth.uid(), 'Après effacement')$q$, current_setting('verif.avis'))) is null then
    raise exception 'ÉCHEC : effacer ses commentaires d''avis remet le compteur à zéro';
  end if;
end $$;
reset role;
-- La date posée par la base, relue sur un commentaire de Moussa : ceux
-- d'Awa viennent d'être effacés.
set local role authenticated;
select verif.comme(:'moussa');
insert into public.review_comments (id, review_id, author_id, body, created_at)
values ('verif-rc-date-2', :'avis_moussa', auth.uid(), 'Merci', '2020-01-01');
reset role;
do $$ begin
  if (select created_at from public.review_comments where id = 'verif-rc-date-2') <> now() then
    raise exception 'ÉCHEC : un commentaire d''avis garde la date de la requête';
  end if;
end $$;

-- ---- 9. une commande annulée rend son code promo — même annulée par un collaborateur sans « remises »
insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data, raw_user_meta_data) values
  ('cccccccc-0000-4000-8000-0000001530c1', '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'verif-collab-1530c1@mtc.local',
   jsonb_build_object('collaborator_of', :'bogolan', 'permissions', jsonb_build_array('orders')),
   '{"username_or_phone": "verif-collab-1530c1", "display_name": "Vendeur C", "phone_number": "+22370001530"}');
set local role authenticated;
select verif.comme(:'bogolan');
insert into public.promo_codes (id, supplier_id, code, percent, max_uses_per_client)
values ('verif-promo-153', :'bogolan', 'VERIF153', 10, 1);
select verif.comme('cccccccc-0000-4000-8000-000000001537');
select public.place_order('x', '+22370000001',
  jsonb_build_array(jsonb_build_object('supplier_id', :'bogolan', 'delivery_mode', 'self_delivery',
    'items', jsonb_build_array(jsonb_build_object('product_id', :'boubou', 'variant_id', :'boubou_v', 'quantity', 1)))),
  'Maison', 'Bamako', 'Rue 1', 12.6, -8.0, p_promo_code => 'VERIF153') as cmd_promo \gset
reset role;
select set_config('verif.cmd_promo', :'cmd_promo', true);
do $$ begin
  if (select uses_count from public.promo_codes where id = 'verif-promo-153') <> 1
     or not exists (select 1 from public.promo_code_redemptions where order_id = current_setting('verif.cmd_promo')) then
    raise exception 'ÉCHEC : le code promo n''a pas été consommé (le test ne prouve rien)';
  end if;
end $$;
set local role authenticated;
select verif.comme('cccccccc-0000-4000-8000-0000001530c1');
select public.update_order_group_status(:'cmd_promo', verif.groupe(:'cmd_promo'), 'cancelled', 'Rupture');
reset role;
do $$ begin
  if (select uses_count from public.promo_codes where id = 'verif-promo-153') <> 0
     or exists (select 1 from public.promo_code_redemptions where order_id = current_setting('verif.cmd_promo')) then
    raise exception 'ÉCHEC : la commande annulée garde son code promo comme utilisé';
  end if;
end $$;
set local role authenticated;
select verif.comme('cccccccc-0000-4000-8000-000000001537');
do $$ begin
  if verif.erreur(format($q$select public.place_order('x', '+22370000001',
       jsonb_build_array(jsonb_build_object('supplier_id', %L, 'delivery_mode', 'self_delivery',
         'items', jsonb_build_array(jsonb_build_object('product_id', %L, 'variant_id', %L, 'quantity', 1)))),
       'Maison', 'Bamako', 'Rue 1', 12.6, -8.0, p_promo_code => 'VERIF153')$q$,
       current_setting('verif.bogolan'), current_setting('verif.boubou'), current_setting('verif.boubou_v'))) is not null then
    raise exception 'ÉCHEC : le code « une fois par client » ne se réutilise pas après l''annulation';
  end if;
end $$;
reset role;

-- ---- 10. un expéditeur usurpé n'est ni compté ni renseigné ------------------------------------------
-- La boutique a atteint sa limite ; Awa écrit en son nom : la politique la
-- refuse, et le frein ne doit ni compter pour la boutique ni dire où elle en est.
insert into public.post_rate_events (author_id, kind)
select :'bogolan', 'chat_messages' from generate_series(1, 20);
set local role authenticated;
select verif.comme(:'awa');
do $$
declare
  v text;
begin
  v := verif.erreur(format($q$insert into public.chat_messages (id, conversation_id, sender_id, text)
       values ('verif-usurpe', %L, %L, 'Je suis la boutique')$q$,
       current_setting('verif.conv_awa'), current_setting('verif.bogolan')));
  if v is null then
    raise exception 'ÉCHEC : un client écrit au nom de la boutique';
  end if;
  if v like '%trop de messages%' or v like '%en une heure%' then
    raise exception 'ÉCHEC : le frein compte l''expéditeur usurpé et le dit (%)', v;
  end if;
end $$;
reset role;

-- ---- 11. un délai démesuré ne casse pas la tâche -----------------------------------------------------
do $$ begin
  perform verif.regle('unconfirmed_order_expiry_hours', '2147483647');
  perform public.cancel_unconfirmed_orders();
  perform verif.sans_regles();
end $$;

-- ---- 12. rien de tout cela ne s'appelle par l'API ---------------------------------------------------
do $$ begin
  if has_function_privilege('authenticated', 'public.cancel_unconfirmed_orders()', 'execute')
     or has_function_privilege('authenticated', 'public.check_unpaid_holdings(uuid, jsonb)', 'execute')
     or has_function_privilege('anon', 'public.app_setting_int(text, integer)', 'execute')
     or has_function_privilege('authenticated', 'public.app_setting_int(text, integer)', 'execute')
     or has_function_privilege('authenticated', 'public.throttle_posts()', 'execute')
     or has_function_privilege('authenticated', 'public.release_promo_of_cancelled_group()', 'execute')
     or has_table_privilege('authenticated', 'public.post_rate_events', 'select')
     or has_table_privilege('authenticated', 'public.post_rate_events', 'delete')
     or has_table_privilege('anon', 'public.post_rate_events', 'select') then
    raise exception 'ÉCHEC : une fonction interne de 0153 s''appelle par l''API';
  end if;
end $$;

\o
select 'TOUTES LES VÉRIFICATIONS PASSENT' as resultat;
rollback;
