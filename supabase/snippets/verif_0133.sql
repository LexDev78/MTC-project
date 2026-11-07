-- Vérifie la migration 0133 (l'adresse exacte d'une boutique n'est plus
-- publique) contre la base locale, sans rien y laisser : tout se passe dans
-- une transaction annulée.
--
--   docker exec -i supabase_db_MTC_project psql -U postgres -d postgres -q \
--     < supabase/snippets/verif_0133.sql
--
-- Dernière ligne attendue : « TOUTES LES VÉRIFICATIONS PASSENT ».
\set ON_ERROR_STOP 1
\o /dev/null
begin;
set local client_min_messages = warning;

create schema verif;
grant usage on schema verif to anon, authenticated;

create function verif.refuse(p_cas text, p_sql text, p_motif text)
returns void language plpgsql as $$
declare
  v_message text;
begin
  begin
    execute p_sql;
  exception when others then
    v_message := sqlerrm;
  end;
  if v_message is null then
    raise exception 'ÉCHEC % : accepté alors qu''il devait être refusé', p_cas;
  end if;
  if v_message not like p_motif then
    raise exception 'ÉCHEC % : refusé, mais pour une autre raison : %', p_cas, v_message;
  end if;
end $$;

create function verif.inscrire(p_id uuid, p_user jsonb)
returns void language sql as $$
  insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token, email_change, email_change_token_new)
  values ('00000000-0000-0000-0000-000000000000', p_id, 'authenticated', 'authenticated',
    (p_user ->> 'username_or_phone') || '@mtc.local', '', now(), now(), now(),
    '{"provider":"email","providers":["email"]}', p_user, '', '', '', '');
$$;

create function verif.jeton(p_id uuid) returns text language sql as $$
  select jsonb_build_object('sub', p_id, 'role', 'authenticated',
    'app_metadata', (select raw_app_meta_data from auth.users where id = p_id))::text;
$$;

-- Une course de Bogolan Bamako, dans l'état voulu, pour le livreur voulu.
create function verif.course(p_statut text, p_livreur uuid, p_propose boolean default false)
returns text language plpgsql as $$
declare
  v_commande text := gen_random_uuid()::text;
  v_groupe text := gen_random_uuid()::text;
  v_course text;
begin
  insert into public.orders (id, client_id, client_display_name_snapshot, status, total_fcfa, delivery_city)
  values (v_commande, '04060d99-e34d-520e-8b75-631ff4d3c10c', 'Awa', 'in_transit', 25000, 'Bamako');
  insert into public.order_supplier_groups (id, order_id, supplier_id, supplier_name, delivery_mode,
                                            delivery_fee_fcfa, subtotal_fcfa, status)
  values (v_groupe, v_commande, 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'Bogolan Bamako',
          'mtc_delivery', 1500, 25000, 'in_transit');
  insert into public.deliveries (order_id, supplier_group_id, status, courier_id, offered_to_courier_id)
  values (v_commande, v_groupe, p_statut::public.delivery_status,
          case when p_propose then null else p_livreur end,
          case when p_propose then p_livreur end)
  returning id into v_course;
  return v_course;
end $$;

-- `pickup_point` tel que PostgREST l'appelle : sur la ligne que l'appelant
-- voit — rien si la RLS la lui cache.
create function verif.retrait(p_course text) returns jsonb language sql as $$
  select public.pickup_point(d) from public.deliveries d where d.id = p_course;
$$;
grant execute on all functions in schema verif to anon, authenticated;

\set bogolan 'b7eb8585-4091-5b6f-83f7-5d70724e97a3'
\set livreur1 'f1c4e8a2-0000-5000-9000-000000000001'
\set livreur2 'f1c4e8a2-0000-5000-9000-000000000002'

-- Une adresse connue, pour la reconnaître partout où elle ne doit pas être.
update public.suppliers
   set full_address = 'Rue de la vérification, porte 7', address_latitude = 12.6555, address_longitude = -8.0111
 where id = :'bogolan';

select verif.course('offered', :'livreur2', true) as propose \gset
select verif.course('accepted', :'livreur1') as acceptee \gset
select verif.course('delivered', :'livreur1') as livree \gset
select set_config('verif.propose', :'propose', true), set_config('verif.acceptee', :'acceptee', true),
       set_config('verif.livree', :'livree', true);

-- Une vendeuse sans droit de vitrine, une autre avec.
select verif.inscrire('d0000000-0000-4000-8000-000000000001', '{"username_or_phone":"v-caisse","display_name":"Caisse","phone_number":"+22370000061"}');
update auth.users set raw_app_meta_data = raw_app_meta_data || '{"collaborator_of":"b7eb8585-4091-5b6f-83f7-5d70724e97a3","permissions":["orders"]}'
 where id = 'd0000000-0000-4000-8000-000000000001';
select verif.inscrire('d0000000-0000-4000-8000-000000000002', '{"username_or_phone":"v-vitrine","display_name":"Vitrine","phone_number":"+22370000062"}');
update auth.users set raw_app_meta_data = raw_app_meta_data || '{"collaborator_of":"b7eb8585-4091-5b6f-83f7-5d70724e97a3","permissions":["storefront"]}'
 where id = 'd0000000-0000-4000-8000-000000000002';

select verif.jeton(:'bogolan') as patron \gset
select verif.jeton('d0000000-0000-4000-8000-000000000001') as caisse \gset
select verif.jeton('d0000000-0000-4000-8000-000000000002') as vitrine \gset
select verif.jeton(:'livreur1') as l1 \gset
select verif.jeton(:'livreur2') as l2 \gset
select verif.jeton('04060d99-e34d-520e-8b75-631ff4d3c10c') as client \gset
select verif.jeton('2358888a-b13d-56f8-858b-a0c63831b512') as admin1 \gset
select set_config('verif.patron', :'patron', true), set_config('verif.caisse', :'caisse', true),
       set_config('verif.vitrine', :'vitrine', true), set_config('verif.l1', :'l1', true),
       set_config('verif.l2', :'l2', true), set_config('verif.client', :'client', true),
       set_config('verif.admin1', :'admin1', true);

-- ---- 1. le public ne lit plus l'adresse --------------------------------------------------
set local role anon;
set local request.jwt.claims to '{"role":"anon"}';
do $$ begin
  perform verif.refuse('anon lit full_address', 'select full_address from public.suppliers', 'permission denied for table suppliers');
  perform verif.refuse('anon lit la position', 'select address_latitude, address_longitude from public.suppliers', 'permission denied for table suppliers');
  perform verif.refuse('anon lit select *', 'select * from public.suppliers', 'permission denied for table suppliers');
  perform verif.refuse('anon passe par le compteur de la table', 'select public.listed_product_count(s) from public.suppliers s', 'permission denied for table suppliers');
  -- La fiche publique, elle, se lit — et n'a pas de colonne d'adresse.
  if (select count(*) from public.supplier_storefronts) = 0
     or exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'supplier_storefronts'
                 and column_name in ('full_address', 'address_latitude', 'address_longitude')) then
    raise exception 'ÉCHEC : la vue publique est vide, ou porte l''adresse';
  end if;
  if (select public.listed_product_count(s) from public.supplier_storefronts s where s.id = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3') is null
     or (select business_name from public.suppliers where id = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3') <> 'Bogolan Bamako' then
    raise exception 'ÉCHEC : le compteur ou les colonnes publiques ne se lisent plus';
  end if;
  -- La politique des produits consulte `suppliers` : elle marche toujours.
  if (select count(*) from public.products) = 0 then
    raise exception 'ÉCHEC : le catalogue public a disparu';
  end if;
  perform verif.refuse('anon appelle la fonction de la boutique', 'select public.fetch_my_shop_location()', '%permission denied%');
  perform verif.refuse('anon appelle pickup_point', $q$select public.pickup_point(d) from public.deliveries d$q$, '%permission denied%');
end $$;

-- ---- 2. la boutique lit la sienne ----------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', current_setting('verif.patron'), true);
do $$ begin
  perform verif.refuse('le patron lit la table en direct', 'select full_address from public.suppliers', 'permission denied for table suppliers');
  if public.fetch_my_shop_location() ->> 'full_address' <> 'Rue de la vérification, porte 7'
     or (public.fetch_my_shop_location() ->> 'latitude')::numeric <> 12.6555 then
    raise exception 'ÉCHEC : le patron ne lit pas son adresse (%)', public.fetch_my_shop_location();
  end if;
  -- Et l'écrit toujours (`updateLocation`).
  update public.suppliers set full_address = 'Nouvelle adresse' where id = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3';
  if public.fetch_my_shop_location() ->> 'full_address' <> 'Nouvelle adresse' then
    raise exception 'ÉCHEC : le patron ne peut plus enregistrer son adresse';
  end if;
end $$;
select set_config('request.jwt.claims', current_setting('verif.vitrine'), true);
do $$ begin
  if public.fetch_my_shop_location() ->> 'full_address' <> 'Nouvelle adresse' then
    raise exception 'ÉCHEC : la vendeuse chargée de la vitrine ne lit pas l''adresse';
  end if;
end $$;
select set_config('request.jwt.claims', current_setting('verif.caisse'), true);
do $$ begin
  if public.fetch_my_shop_location() is not null then
    raise exception 'ÉCHEC : une vendeuse sans droit de vitrine lit l''adresse';
  end if;
end $$;
select set_config('request.jwt.claims', current_setting('verif.client'), true);
do $$ begin
  if public.fetch_my_shop_location() is not null then
    raise exception 'ÉCHEC : un client lit une adresse de boutique';
  end if;
  -- Le client voit sa course (`deliveries_select_participants`), pas
  -- l'adresse de la boutique.
  if verif.retrait(current_setting('verif.acceptee')) is not null then
    raise exception 'ÉCHEC : le client lit le point de retrait';
  end if;
end $$;

-- ---- 3. le livreur, pendant la course seulement ----------------------------------------------
select set_config('request.jwt.claims', current_setting('verif.l2'), true);
do $$ begin
  if verif.retrait(current_setting('verif.propose')) ->> 'full_address' <> 'Nouvelle adresse' then
    raise exception 'ÉCHEC : le livreur à qui la course est proposée ne voit pas où la prendre';
  end if;
  if verif.retrait(current_setting('verif.acceptee')) is not null then
    raise exception 'ÉCHEC : un livreur lit le retrait de la course d''un autre';
  end if;
end $$;
select set_config('request.jwt.claims', current_setting('verif.l1'), true);
do $$ begin
  if (verif.retrait(current_setting('verif.acceptee')) ->> 'latitude')::numeric <> 12.6555 then
    raise exception 'ÉCHEC : le livreur de la course ne voit pas le point de retrait';
  end if;
  if verif.retrait(current_setting('verif.livree')) is not null then
    raise exception 'ÉCHEC : l''adresse reste lisible une fois la course livrée';
  end if;
end $$;
select set_config('request.jwt.claims', current_setting('verif.admin1'), true);
do $$ begin
  if verif.retrait(current_setting('verif.livree')) ->> 'full_address' <> 'Nouvelle adresse' then
    raise exception 'ÉCHEC : le staff ne voit pas le point de retrait';
  end if;
end $$;
reset role;

-- ---- 4. le serveur, lui, lit toujours ce qu'il lui faut ----------------------------------------
-- La garde du point de retrait (`0050`) : une boutique sans adresse ne
-- confie pas de colis à MTC, une boutique avec, si.
do $$
declare
  v_groupe text;
begin
  select g.id into v_groupe from public.order_supplier_groups g
   where g.supplier_id = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3' and g.status = 'in_transit'
   limit 1;
  update public.order_supplier_groups set status = 'preparing' where id = v_groupe;
  delete from public.deliveries where supplier_group_id = v_groupe;
  update public.order_supplier_groups set status = 'in_transit' where id = v_groupe;
  if not exists (select 1 from public.deliveries where supplier_group_id = v_groupe) then
    raise exception 'ÉCHEC : la course n''est plus créée quand le colis part';
  end if;
end $$;

\o
select 'TOUTES LES VÉRIFICATIONS PASSENT' as resultat;
rollback;
