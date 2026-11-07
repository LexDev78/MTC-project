-- Vérifie 0143 (permissions des collaborateurs) contre une base où elle est
-- appliquée, sans rien y laisser : tout se passe dans une transaction
-- annulée.
--
--   docker exec -i supabase_db_mtc_verif psql -U postgres -d postgres -q \
--     < supabase/snippets/verif_0143.sql
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
create function verif.lignes(p_sql text) returns bigint language plpgsql as $$
declare n bigint;
begin
  execute 'select count(*) from (' || p_sql || ') q' into n;
  return n;
end $$;
-- Le nombre de lignes qu'une écriture a réellement touchées (une policy qui
-- refuse un UPDATE ou un DELETE n'échoue pas : elle ne touche rien).
create function verif.touche(p_sql text) returns bigint language plpgsql as $$
declare n bigint;
begin
  execute 'with q as (' || p_sql || ') select count(*) from q' into n;
  return n;
exception when insufficient_privilege then
  return 0;
end $$;
grant execute on all functions in schema verif to anon, authenticated;

\set bogolan 'b7eb8585-4091-5b6f-83f7-5d70724e97a3'
\set awa '04060d99-e34d-520e-8b75-631ff4d3c10c'

-- Deux collaborateurs de Bogolan : « messages » seul (le cas de l'audit) et
-- « commandes » seul.
insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data, raw_user_meta_data) values
  ('cccccccc-0000-4000-8000-000000000143', '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'verif-collab-143@mtc.local',
   jsonb_build_object('collaborator_of', :'bogolan', 'permissions', jsonb_build_array('messages')),
   jsonb_build_object('username_or_phone', 'verif-collab-143', 'display_name', 'Vendeur M', 'phone_number', '+22370000143')),
  ('cccccccc-0000-4000-8000-000000000144', '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'verif-collab-144@mtc.local',
   jsonb_build_object('collaborator_of', :'bogolan', 'permissions', jsonb_build_array('orders')),
   jsonb_build_object('username_or_phone', 'verif-collab-144', 'display_name', 'Vendeur C', 'phone_number', '+22370000144'));

-- Des notifications de la boutique, de chaque sorte.
insert into public.notifications (id, user_id, type, title, body) values
  ('verif-n-order', :'bogolan', 'new_order', 'Nouvelle commande', '45 000 FCFA'),
  ('verif-n-payout', :'bogolan', 'payout_decision', 'Retrait', '250 000 FCFA'),
  ('verif-n-kyc', :'bogolan', 'kyc_decision', 'Dossier', 'Refusé : pièce illisible'),
  ('verif-n-msg', :'bogolan', 'new_message', 'Message', 'Mon code portail est 4521');

-- ---- 1. « messages » seul : rien des commandes, des produits, de l'argent -----------------------
set local role authenticated;
select verif.comme('cccccccc-0000-4000-8000-000000000143');
do $$ begin
  if verif.lignes('select 1 from public.orders') > 0
     or verif.lignes('select 1 from public.order_supplier_groups') > 0
     or verif.lignes('select 1 from public.order_items') > 0
     or verif.lignes('select 1 from public.deliveries') > 0 then
    raise exception 'ÉCHEC : un collaborateur « messages » lit les commandes de la boutique';
  end if;
  if verif.lignes('select 1 from public.reviews') > 0 then
    raise exception 'ÉCHEC : un collaborateur « messages » lit les avis complets';
  end if;
  if verif.lignes('select 1 from public.stock_movements') > 0 then
    raise exception 'ÉCHEC : un collaborateur « messages » lit l''historique de stock';
  end if;
  -- Les options : ni écrire, ni effacer.
  if verif.touche($q$update public.product_characteristic_options set price_delta_fcfa = -40000
                     where characteristic_id in (select c.id from public.product_characteristics c
                       join public.products p on p.id = c.product_id
                      where p.supplier_id = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3') returning 1$q$) > 0 then
    raise exception 'ÉCHEC : un collaborateur « messages » change le prix d''une option';
  end if;
  if verif.touche($q$delete from public.product_variant_options
                     where variant_id in (select v.id from public.product_variants v
                       join public.products p on p.id = v.product_id
                      where p.supplier_id = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3') returning 1$q$) > 0 then
    raise exception 'ÉCHEC : un collaborateur « messages » efface des options de variantes';
  end if;
  -- Les notifications : les messages, pas le reste.
  if verif.lignes($q$select 1 from public.notifications where id = 'verif-n-msg'$q$) <> 1 then
    raise exception 'ÉCHEC : le collaborateur « messages » ne voit plus les messages';
  end if;
  if verif.lignes($q$select 1 from public.notifications where id in ('verif-n-order', 'verif-n-payout', 'verif-n-kyc')$q$) > 0 then
    raise exception 'ÉCHEC : un collaborateur lit des notifications hors de ses cases';
  end if;
  -- Ni réécrire, ni détourner, même celles qu'il voit.
  if not verif.refuse($q$update public.notifications set body = 'Appelez le +223…' where id = 'verif-n-msg'$q$) then
    raise exception 'ÉCHEC : le texte d''une notification se réécrit';
  end if;
  if not verif.refuse($q$update public.notifications set user_id = auth.uid() where id = 'verif-n-msg'$q$) then
    raise exception 'ÉCHEC : une notification se détourne';
  end if;
  update public.notifications set is_read = true where id = 'verif-n-msg';
end $$;

-- ---- 2. « commandes » : les commandes, pas l'argent ----------------------------------------------
select verif.comme('cccccccc-0000-4000-8000-000000000144');
do $$ begin
  if verif.lignes($q$select 1 from public.order_supplier_groups
                     where supplier_id = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3'$q$) = 0
     or verif.lignes('select 1 from public.order_items') = 0 then
    raise exception 'ÉCHEC : le collaborateur « commandes » ne voit plus les commandes';
  end if;
  if verif.lignes($q$select 1 from public.notifications where id = 'verif-n-order'$q$) <> 1 then
    raise exception 'ÉCHEC : le collaborateur « commandes » ne voit plus les nouvelles commandes';
  end if;
  if verif.lignes($q$select 1 from public.notifications where id in ('verif-n-payout', 'verif-n-kyc', 'verif-n-msg')$q$) > 0 then
    raise exception 'ÉCHEC : le collaborateur « commandes » lit l''argent, le dossier ou les messages';
  end if;
end $$;

-- ---- 3. le patron et le client, comme avant --------------------------------------------------------
select verif.comme(:'bogolan');
-- Le semis n'a pas d'historique de stock chez Bogolan : le patron en ajoute
-- un mouvement, ce qui vérifie au passage que l'ajout reste permis.
insert into public.stock_movements (id, product_id, quantity_delta, reason)
select 'verif-stock', id, 1, 'manual_adjustment'
  from public.products where supplier_id = :'bogolan' limit 1;
do $$ begin
  if verif.lignes($q$select 1 from public.notifications where id like 'verif-n-%'$q$) <> 4 then
    raise exception 'ÉCHEC : le patron ne voit plus toutes ses notifications';
  end if;
  if verif.lignes('select 1 from public.order_supplier_groups') = 0
     or verif.lignes('select 1 from public.reviews') = 0
     or verif.lignes('select 1 from public.stock_movements') = 0 then
    raise exception 'ÉCHEC : le patron ne voit plus ses commandes, ses avis ou son stock';
  end if;
  -- L'historique de stock s'ajoute, ne se réécrit pas.
  if verif.touche('update public.stock_movements set quantity_delta = 0 returning 1') > 0
     or verif.touche('delete from public.stock_movements returning 1') > 0 then
    raise exception 'ÉCHEC : l''historique de stock se réécrit';
  end if;
end $$;
select verif.comme(:'awa');
do $$ begin
  if verif.lignes('select 1 from public.orders') = 0
     or verif.lignes('select 1 from public.order_items') = 0 then
    raise exception 'ÉCHEC : le client ne voit plus ses commandes';
  end if;
end $$;
reset role;

\o
select 'TOUTES LES VÉRIFICATIONS PASSENT' as resultat;
rollback;
