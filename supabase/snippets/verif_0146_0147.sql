-- Vérifie 0146 (chacun dans son rôle) et 0147 (une commande dit ce que la
-- base sait) contre une base où elles sont appliquées, sans rien y laisser :
-- tout se passe dans une transaction annulée.
--
--   docker exec -i supabase_db_mtc_verif psql -U postgres -d postgres -q \
--     < supabase/snippets/verif_0146_0147.sql
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
create function verif.commande(p_items jsonb, p_mode text default 'self_delivery') returns text
language sql as $$
  select public.place_order(
    'Service client MTC', '+22370000009',
    jsonb_build_array(jsonb_build_object(
      'supplier_id', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'supplier_name', 'X',
      'delivery_mode', p_mode, 'items', p_items)),
    'Domicile', 'Bamako', 'Badalabougou', 12.63, -8.0);
$$;
create function verif.ligne(p_cmd text) returns public.orders language sql security definer as $$
  select * from public.orders where id = p_cmd;
$$;
create function verif.groupe(p_cmd text) returns public.order_supplier_groups language sql security definer as $$
  select * from public.order_supplier_groups where order_id = p_cmd;
$$;
grant execute on all functions in schema verif to anon, authenticated;

\set bogolan 'b7eb8585-4091-5b6f-83f7-5d70724e97a3'
\set awa '04060d99-e34d-520e-8b75-631ff4d3c10c'
\set moussa '3355adef-385d-5eee-a565-815c8cf8e4d3'
\set livreur1 'f1c4e8a2-0000-5000-9000-000000000001'
\set boubou 'b0fe527e-1f73-55e6-b24e-4d985576d473'
-- Les identifiants de variantes sont tirés au semis : on le lit.
select id as boubou_var from public.product_variants where product_id = :'boubou' order by id limit 1 \gset
select set_config('verif.ligne', jsonb_build_array(jsonb_build_object(
  'product_id', :'boubou', 'variant_id', :'boubou_var', 'quantity', 1))::text, true);
select set_config('verif.sans_variante', jsonb_build_array(jsonb_build_object(
  'product_id', :'boubou', 'quantity', 1))::text, true);

-- ---- 1. un livreur, une boutique ne font pas les gestes du client ------------------------------
set local role authenticated;
do $$
declare
  v_qui uuid;
begin
  foreach v_qui in array array['f1c4e8a2-0000-5000-9000-000000000001'::uuid,
                               'b8e6fcc1-ef1c-5248-8ffa-5de27e9beebb'::uuid] loop
    perform verif.comme(v_qui);
    if not verif.refuse($q$select verif.commande(current_setting('verif.ligne')::jsonb)$q$) then
      raise exception 'ÉCHEC : % passe commande', v_qui;
    end if;
    if not verif.refuse(format($q$insert into public.cart_items (id, user_id, product_id, quantity)
                         values ('verif-panier', %L, 'b0fe527e-1f73-55e6-b24e-4d985576d473', 1)$q$, v_qui))
       or not verif.refuse(format($q$insert into public.favorites (user_id, product_id)
                         values (%L, 'b0fe527e-1f73-55e6-b24e-4d985576d473')$q$, v_qui))
       or not verif.refuse(format($q$insert into public.chat_conversations (id, client_id, supplier_id, client_display_name_snapshot, supplier_name)
                         values ('verif-conv', %L, 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'X', 'Y')$q$, v_qui)) then
      raise exception 'ÉCHEC : % remplit un panier, des favoris ou ouvre une conversation client', v_qui;
    end if;
  end loop;
end $$;

-- ---- 2. le client commande : son nom, sa variante ------------------------------------------------
select verif.comme(:'awa');
do $$
declare
  v_cmd text;
begin
  -- Une ligne sans variante, sur un produit qui en a, prend la variante par
  -- défaut : enregistrée sur la ligne, à son prix — plus le prix de la moins
  -- chère sans dire laquelle préparer.
  v_cmd := verif.commande(current_setting('verif.sans_variante')::jsonb);
  if (select i.variant_id from public.order_items i
        join public.order_supplier_groups g on g.id = i.group_id
       where g.order_id = v_cmd)
     is distinct from (select v.id from public.product_variants v
                        where v.product_id = 'b0fe527e-1f73-55e6-b24e-4d985576d473' and v.is_default
                        order by v.display_order, v.id limit 1) then
    raise exception 'ÉCHEC : une ligne sans variante ne prend pas la variante par défaut';
  end if;
  v_cmd := verif.commande(current_setting('verif.ligne')::jsonb);
  if (verif.ligne(v_cmd)).client_display_name_snapshot <> 'Awa Traoré' then
    raise exception 'ÉCHEC : la commande porte le nom « % »', (verif.ligne(v_cmd)).client_display_name_snapshot;
  end if;
  perform set_config('verif.cmd', v_cmd, true);
end $$;

-- ---- 3. la boutique annule : c'est elle qui annule -------------------------------------------------
select verif.comme(:'bogolan');
select public.update_order_group_status(current_setting('verif.cmd'),
         (verif.groupe(current_setting('verif.cmd'))).id, 'cancelled', 'Rupture', 'client');
do $$ begin
  if (verif.groupe(current_setting('verif.cmd'))).cancelled_by <> 'supplier' then
    raise exception 'ÉCHEC : la boutique signe l''annulation « % »',
      (verif.groupe(current_setting('verif.cmd'))).cancelled_by;
  end if;
end $$;
reset role;

-- ---- 4. la course MTC : la ville de la boutique, et l'annulation la ferme ------------------------
-- La boutique écrit « Kayes » sur son boubou (≈ 500 km de Bamako, où elle est) ;
-- le prix de la course pour un client de Bamako ne bouge pas.
select set_config('request.jwt.claims', '{}', true);
update public.products set city = 'Kayes', allows_mtc_delivery = true where id = :'boubou';
update public.suppliers set address_latitude = 12.64, address_longitude = -8.0,
       full_address = 'Quartier du Fleuve' where id = :'bogolan';
set local role authenticated;
select verif.comme(:'awa');
select verif.commande(current_setting('verif.ligne')::jsonb, 'mtc_delivery') as cmd_mtc \gset
select set_config('verif.cmd_mtc', :'cmd_mtc', true);
reset role;
do $$ begin
  if (verif.groupe(current_setting('verif.cmd_mtc'))).delivery_fee_fcfa
     <> public.compute_mtc_delivery_fee_fcfa('Bamako', 12.63, -8.0,
          (select weight_kg from public.products where id = 'b0fe527e-1f73-55e6-b24e-4d985576d473'),
          array[(select category from public.products where id = 'b0fe527e-1f73-55e6-b24e-4d985576d473')]) then
    raise exception 'ÉCHEC : la course est payée depuis la ville écrite sur le produit (% FCFA)',
      (verif.groupe(current_setting('verif.cmd_mtc'))).delivery_fee_fcfa;
  end if;
end $$;
-- Le devis montre la même ville.
set local role authenticated;
select verif.comme(:'awa');
do $$ begin
  if public.fetch_pricing_inputs(array['b0fe527e-1f73-55e6-b24e-4d985576d473'])
       -> 'b0fe527e-1f73-55e6-b24e-4d985576d473' ->> 'city' <> 'Bamako' then
    raise exception 'ÉCHEC : le devis part d''une autre ville que la boutique';
  end if;
end $$;
reset role;

-- Une course acceptée par livreur1.
insert into public.deliveries (id, order_id, supplier_group_id, status, courier_id, accepted_at,
                               courier_latitude, courier_longitude, courier_position_at)
select 'verif-course', :'cmd_mtc', (verif.groupe(:'cmd_mtc')).id, 'accepted', :'livreur1', now(),
       12.7, -8.01, now()
 where not exists (select 1 from public.deliveries where order_id = :'cmd_mtc');
update public.deliveries set status = 'accepted', courier_id = :'livreur1', accepted_at = now(),
       courier_latitude = 12.7, courier_longitude = -8.01, courier_position_at = now()
 where order_id = :'cmd_mtc';
select id as course from public.deliveries where order_id = :'cmd_mtc' \gset
select set_config('verif.course', :'course', true);

set local role authenticated;
select verif.comme(:'livreur1');
do $$
declare
  v jsonb;
begin
  -- Ce que l'écran du livreur lit, par la course.
  select public.courier_order(d) into v from public.deliveries d where d.id = current_setting('verif.course');
  if v ->> 'client_display_name_snapshot' <> 'Awa Traoré' or v -> 'client_contact' ->> 'phone' is null then
    raise exception 'ÉCHEC : le livreur ne lit plus sa course (%)', v;
  end if;
  if v ? 'supplier_message_text' or v ? 'total_fcfa' then
    raise exception 'ÉCHEC : le livreur lit plus que son écran';
  end if;
  -- La ligne de la commande, elle, ne se lit plus.
  if exists (select 1 from public.orders where id = current_setting('verif.cmd_mtc')) then
    raise exception 'ÉCHEC : le livreur lit la ligne entière de la commande';
  end if;
end $$;

-- pickup_point ne croit plus la ligne qu'on lui passe : Moussa fabrique une
-- course « acceptée par lui » sur le groupe d'Awa.
select verif.comme(:'moussa');
do $$ begin
  if public.pickup_point(jsonb_populate_record(null::public.deliveries, jsonb_build_object(
       'id', 'inventee', 'supplier_group_id', (verif.groupe(current_setting('verif.cmd_mtc'))).id,
       'status', 'accepted', 'courier_id', auth.uid()))) is not null then
    raise exception 'ÉCHEC : pickup_point rend l''adresse privée d''une boutique sur une course inventée';
  end if;
  if public.pickup_point(jsonb_populate_record(null::public.deliveries, jsonb_build_object(
       'id', current_setting('verif.course'), 'supplier_group_id', (verif.groupe(current_setting('verif.cmd_mtc'))).id,
       'status', 'accepted', 'courier_id', auth.uid()))) is not null then
    raise exception 'ÉCHEC : pickup_point croit le livreur écrit dans la ligne';
  end if;
end $$;
select verif.comme(:'livreur1');
do $$ begin
  if (select public.pickup_point(d) from public.deliveries d where d.id = current_setting('verif.course')) is null then
    raise exception 'ÉCHEC : le livreur de la course ne voit plus où retirer le colis';
  end if;
end $$;

-- La boutique annule : la course se ferme, le livreur est averti et ne voit
-- plus rien du client ; le client ne voit plus le livreur.
select verif.comme(:'bogolan');
select public.update_order_group_status(:'cmd_mtc', (verif.groupe(:'cmd_mtc')).id, 'confirmed');
select public.update_order_group_status(:'cmd_mtc', (verif.groupe(:'cmd_mtc')).id, 'cancelled', 'Rupture');
reset role;
do $$
declare
  d public.deliveries;
begin
  select * into d from public.deliveries where id = current_setting('verif.course');
  if d.status <> 'cancelled' or d.courier_latitude is not null then
    raise exception 'ÉCHEC : la course reste ouverte après l''annulation (%)', d.status;
  end if;
  if not exists (select 1 from public.notifications
                  where user_id = 'f1c4e8a2-0000-5000-9000-000000000001' and title = 'Course annulée') then
    raise exception 'ÉCHEC : le livreur n''est pas averti de l''annulation';
  end if;
end $$;
set local role authenticated;
select verif.comme(:'livreur1');
do $$ begin
  if (select public.courier_order(d) -> 'client_contact' ->> 'phone'
        from public.deliveries d where d.id = current_setting('verif.course')) is not null then
    raise exception 'ÉCHEC : le livreur garde le numéro du client d''une course annulée';
  end if;
end $$;
reset role;

-- Une fois le colis chez le livreur, la boutique n'annule plus seule.
select set_config('request.jwt.claims', '{}', true);
update public.order_supplier_groups set status = 'in_transit' where id = (verif.groupe(:'cmd_mtc')).id;
update public.deliveries set status = 'picked_up', picked_up_at = now() where id = :'course';
set local role authenticated;
select verif.comme(:'bogolan');
do $$ begin
  if not verif.refuse(format($q$select public.update_order_group_status(%L, %L, 'cancelled', 'x')$q$,
       current_setting('verif.cmd_mtc'), (verif.groupe(current_setting('verif.cmd_mtc'))).id)) then
    raise exception 'ÉCHEC : la boutique annule un colis déjà chez le livreur';
  end if;
end $$;
reset role;

-- ---- 5. une boutique supprimée ne fonctionne plus par son équipe ---------------------------------
insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data, raw_user_meta_data) values
  ('cccccccc-0000-4000-8000-000000000146', '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'verif-collab-146@mtc.local',
   jsonb_build_object('collaborator_of', 'b8e6fcc1-ef1c-5248-8ffa-5de27e9beebb',
                      'permissions', jsonb_build_array('messages', 'orders')),
   jsonb_build_object('username_or_phone', 'verif-collab-146', 'display_name', 'Vendeur', 'phone_number', '+22370000146'));
set local role authenticated;
select verif.comme('b8e6fcc1-ef1c-5248-8ffa-5de27e9beebb');
select public.deactivate_account();
select verif.comme('cccccccc-0000-4000-8000-000000000146');
do $$ begin
  if public.operating_supplier_id() is not null or public.supplier_can('messages') then
    raise exception 'ÉCHEC : le collaborateur opère encore une boutique supprimée';
  end if;
end $$;
reset role;

\o
select 'TOUTES LES VÉRIFICATIONS PASSENT' as resultat;
rollback;
