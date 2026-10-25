-- Vérifie la migration 0129 (une commande ne porte que ce qui est en
-- vente) contre la base locale, sans rien y laisser : tout se passe dans
-- une transaction annulée, notifications et e-mails compris.
--
--   docker exec -i supabase_db_MTC_project psql -U postgres -d postgres -q \
--     < supabase/snippets/verif_0129.sql
--
-- Dernière ligne attendue : « TOUTES LES VÉRIFICATIONS PASSENT ».
--
-- Joué en client2 (Moussa), sur les produits de Bogolan Bamako et
-- d'Artisanat Sikasso.
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

-- Une commande d'un seul groupe, en ne donnant que ce qui varie d'un cas à
-- l'autre. Les noms envoyés sont faux exprès : la base doit les ignorer.
create function verif.commander(p_boutique uuid, p_mode text, p_lignes jsonb)
returns text language sql as $$
  select public.place_order(
    'Moussa', '+22370000002',
    jsonb_build_array(jsonb_build_object(
      'supplier_id', p_boutique, 'supplier_name', 'Nom inventé',
      'delivery_mode', p_mode, 'items', p_lignes)),
    'Maison', 'Bamako', 'Rue 1', 12.6, -8.0);
$$;
grant execute on all functions in schema verif to anon, authenticated;

-- Produits et variantes du décor. Artisanat Sikasso est en attente de
-- vérification : ses produits ne se vendent pas, c'est l'un des cas testés.
\set boubou '62599202-a3f0-5adc-ae1c-fe2a691adf92'
\set boubou_v 'bf018c0c-bc89-4a35-be63-fefee9faeceb'
\set sac '31987995-52ae-5c1f-81ce-b253f7fe55c3'
\set sac_v '4f7636da-2e02-4a7f-87b7-281ca1b78872'
\set tissu 'b0fe527e-1f73-55e6-b24e-4d985576d473'
\set tissu_v '10402247-9d2f-465c-a690-363488af673f'
\set bogolan 'b7eb8585-4091-5b6f-83f7-5d70724e97a3'
\set artisanat 'b6b1daf0-1c8e-583f-939f-687991d429ca'

select set_config('verif.stock_sac', (select stock_quantity::text from public.product_variants where id = :'sac_v'), true);
select set_config('verif.stock_boubou', (select stock_quantity::text from public.product_variants where id = :'boubou_v'), true);

\set client2 '{"sub":"3355adef-385d-5eee-a565-815c8cf8e4d3","role":"authenticated","app_metadata":{}}'
set local role authenticated;
set local request.jwt.claims to :'client2';

-- ---- 1. les quantités ---------------------------------------------------------------------
do $$
declare
  v_lignes jsonb;
  v_quantite text;
begin
  -- Le cas de l'audit : un boubou plus « −3 sacs ».
  perform verif.refuse('boubou + −3 sacs', format($q$select verif.commander(%L, 'self_delivery', %L)$q$,
    'b7eb8585-4091-5b6f-83f7-5d70724e97a3',
    '[{"product_id":"62599202-a3f0-5adc-ae1c-fe2a691adf92","variant_id":"bf018c0c-bc89-4a35-be63-fefee9faeceb","quantity":1},
      {"product_id":"31987995-52ae-5c1f-81ce-b253f7fe55c3","variant_id":"4f7636da-2e02-4a7f-87b7-281ca1b78872","quantity":-3}]'),
    'Quantité invalide (-3)%');
  foreach v_quantite in array array['0', '-0', '1.5', '" 2"', '"un"', 'null', '1000000'] loop
    v_lignes := format('[{"product_id":"62599202-a3f0-5adc-ae1c-fe2a691adf92","variant_id":"bf018c0c-bc89-4a35-be63-fefee9faeceb","quantity":%s}]', v_quantite)::jsonb;
    perform verif.refuse('quantité ' || v_quantite,
      format($q$select verif.commander('b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'self_delivery', %L)$q$, v_lignes),
      'Quantité invalide%');
  end loop;
  perform verif.refuse('quantité absente', $q$select verif.commander('b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'self_delivery',
    '[{"product_id":"62599202-a3f0-5adc-ae1c-fe2a691adf92","variant_id":"bf018c0c-bc89-4a35-be63-fefee9faeceb"}]')$q$,
    'Quantité invalide (aucune)%');
end $$;

-- ---- 2. le panier tel que la base le connaît ---------------------------------------------
do $$ begin
  perform verif.refuse('le boubou de Bogolan dans un groupe d''Artisanat', $q$select verif.commander('b6b1daf0-1c8e-583f-939f-687991d429ca', 'self_delivery',
    '[{"product_id":"62599202-a3f0-5adc-ae1c-fe2a691adf92","variant_id":"bf018c0c-bc89-4a35-be63-fefee9faeceb","quantity":1}]')$q$,
    'Le produit « Boubou en bogolan brodé » n''est pas vendu par cette boutique.');
  perform verif.refuse('livraison MTC d''un sac qui ne la propose pas', $q$select verif.commander('b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'mtc_delivery',
    '[{"product_id":"31987995-52ae-5c1f-81ce-b253f7fe55c3","variant_id":"4f7636da-2e02-4a7f-87b7-281ca1b78872","quantity":1}]')$q$,
    '%n''est pas proposé en livraison MTC.');
  perform verif.refuse('mode de livraison inventé', $q$select verif.commander('b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'teleportation',
    '[{"product_id":"62599202-a3f0-5adc-ae1c-fe2a691adf92","variant_id":"bf018c0c-bc89-4a35-be63-fefee9faeceb","quantity":1}]')$q$,
    'Mode de livraison inconnu%');
  perform verif.refuse('variante d''un autre produit', $q$select verif.commander('b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'self_delivery',
    '[{"product_id":"62599202-a3f0-5adc-ae1c-fe2a691adf92","variant_id":"4f7636da-2e02-4a7f-87b7-281ca1b78872","quantity":1}]')$q$,
    'Produit introuvable%');
  perform verif.refuse('commande vide', $q$select public.place_order('Moussa', '+22370000002', '[]', 'Maison', 'Bamako', 'Rue 1', 12.6, -8.0)$q$,
    'Une commande porte au moins un article.');
  perform verif.refuse('boutique sans article', $q$select verif.commander('b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'self_delivery', '[]')$q$,
    'Une commande porte au moins un article.');
  perform verif.refuse('la même boutique deux fois', $q$select public.place_order('Moussa', '+22370000002',
    '[{"supplier_id":"b7eb8585-4091-5b6f-83f7-5d70724e97a3","delivery_mode":"self_delivery","items":[{"product_id":"62599202-a3f0-5adc-ae1c-fe2a691adf92","variant_id":"bf018c0c-bc89-4a35-be63-fefee9faeceb","quantity":1}]},
      {"supplier_id":"b7eb8585-4091-5b6f-83f7-5d70724e97a3","delivery_mode":"self_delivery","items":[{"product_id":"b0fe527e-1f73-55e6-b24e-4d985576d473","variant_id":"10402247-9d2f-465c-a690-363488af673f","quantity":1}]}]',
    'Maison', 'Bamako', 'Rue 1', 12.6, -8.0)$q$,
    'Chaque boutique n''apparaît qu''une fois dans une commande.');
end $$;

-- Ce qui n'est plus en vente : en pause, en brouillon, d'une boutique non
-- vérifiée ou supprimée.
reset role;
set local request.jwt.claims to '{}';
update public.products set status = 'paused' where id = :'tissu';
set local request.jwt.claims to :'client2';
set local role authenticated;
do $$ begin
  perform verif.refuse('produit en pause', $q$select verif.commander('b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'self_delivery',
    '[{"product_id":"b0fe527e-1f73-55e6-b24e-4d985576d473","variant_id":"10402247-9d2f-465c-a690-363488af673f","quantity":1}]')$q$,
    'Le produit « Tissu Bogolan traditionnel » n''est plus en vente.');
end $$;
reset role;
set local request.jwt.claims to '{}';
update public.products set status = 'active', is_supplier_verified = false where id = :'tissu';
set local request.jwt.claims to :'client2';
set local role authenticated;
do $$ begin
  perform verif.refuse('boutique non vérifiée', $q$select verif.commander('b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'self_delivery',
    '[{"product_id":"b0fe527e-1f73-55e6-b24e-4d985576d473","variant_id":"10402247-9d2f-465c-a690-363488af673f","quantity":1}]')$q$,
    '%n''est plus en vente.');
end $$;
reset role;
set local request.jwt.claims to '{}';
update public.products set is_supplier_verified = true where id = :'tissu';
update public.suppliers set deleted_at = now() where id = :'bogolan';
set local request.jwt.claims to :'client2';
set local role authenticated;
do $$ begin
  perform verif.refuse('boutique supprimée', $q$select verif.commander('b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'self_delivery',
    '[{"product_id":"b0fe527e-1f73-55e6-b24e-4d985576d473","variant_id":"10402247-9d2f-465c-a690-363488af673f","quantity":1}]')$q$,
    '%n''est plus en vente.');
end $$;
reset role;
set local request.jwt.claims to '{}';
update public.suppliers set deleted_at = null where id = :'bogolan';
set local request.jwt.claims to :'client2';

-- Rien de tout cela n'a touché au stock.
do $$ begin
  if (select stock_quantity from public.product_variants where id = '4f7636da-2e02-4a7f-87b7-281ca1b78872')::text <> current_setting('verif.stock_sac')
     or (select stock_quantity from public.product_variants where id = 'bf018c0c-bc89-4a35-be63-fefee9faeceb')::text <> current_setting('verif.stock_boubou') then
    raise exception 'ÉCHEC : une commande refusée a déplacé du stock';
  end if;
end $$;

-- ---- 3. une commande normale passe, avec les noms de la base -------------------------------
set local role authenticated;
select verif.commander(:'bogolan', 'self_delivery',
  '[{"product_id":"62599202-a3f0-5adc-ae1c-fe2a691adf92","variant_id":"bf018c0c-bc89-4a35-be63-fefee9faeceb","product_name_snapshot":"Diamant","variant_name_snapshot":"Or massif","quantity":2},
    {"product_id":"31987995-52ae-5c1f-81ce-b253f7fe55c3","variant_id":"4f7636da-2e02-4a7f-87b7-281ca1b78872","quantity":1}]') as commande \gset
select verif.commander('dbff9b88-4829-5eed-b15a-78c33431553f', 'mtc_delivery',
  '[{"product_id":"7a383e7f-0bd1-5d70-9cf7-b17f561f89ef","variant_id":"df3873c6-f5af-4d32-9db4-5bbf3d8d6946","quantity":1}]') as commande_mtc \gset
reset role;
select set_config('verif.commande', :'commande', true), set_config('verif.commande_mtc', :'commande_mtc', true);
do $$
declare
  v_attendu integer := 2 * public.effective_unit_price_fcfa('62599202-a3f0-5adc-ae1c-fe2a691adf92', 'bf018c0c-bc89-4a35-be63-fefee9faeceb', 2)
                     + public.effective_unit_price_fcfa('31987995-52ae-5c1f-81ce-b253f7fe55c3', '4f7636da-2e02-4a7f-87b7-281ca1b78872', 1);
begin
  if (select total_fcfa from public.orders where id = current_setting('verif.commande')) <> v_attendu then
    raise exception 'ÉCHEC : total % au lieu de %', (select total_fcfa from public.orders where id = current_setting('verif.commande')), v_attendu;
  end if;
  if exists (select 1 from public.order_items i join public.order_supplier_groups g on g.id = i.group_id
              where g.order_id = current_setting('verif.commande')
                and (i.product_name_snapshot in ('Diamant') or i.variant_name_snapshot = 'Or massif'))
     or (select supplier_name from public.order_supplier_groups where order_id = current_setting('verif.commande')) <> 'Bogolan Bamako' then
    raise exception 'ÉCHEC : un nom écrit par le client est resté sur la commande';
  end if;
  if (select string_agg(i.product_name_snapshot || '/' || i.variant_name_snapshot, ',' order by i.product_name_snapshot)
        from public.order_items i join public.order_supplier_groups g on g.id = i.group_id
       where g.order_id = current_setting('verif.commande')) <> 'Boubou en bogolan brodé/Standard,Sac en bogolan/Standard' then
    raise exception 'ÉCHEC : les noms de la base ne sont pas sur la commande';
  end if;
  if (select stock_quantity from public.product_variants where id = 'bf018c0c-bc89-4a35-be63-fefee9faeceb') <> current_setting('verif.stock_boubou')::integer - 2
     or (select stock_quantity from public.product_variants where id = '4f7636da-2e02-4a7f-87b7-281ca1b78872') <> current_setting('verif.stock_sac')::integer - 1 then
    raise exception 'ÉCHEC : le stock n''a pas baissé comme il fallait';
  end if;
  if (select delivery_fee_fcfa from public.order_supplier_groups where order_id = current_setting('verif.commande_mtc')) <= 0 then
    raise exception 'ÉCHEC : la livraison MTC n''a pas de frais';
  end if;
end $$;

-- ---- 4. le code promo : l'aperçu refuse, la commande l'applique toujours -----------------------
set local request.jwt.claims to '{"sub":"b7eb8585-4091-5b6f-83f7-5d70724e97a3","role":"authenticated","app_metadata":{}}';
set local role authenticated;
insert into public.promo_codes (code, percent) values ('VERIF129', 10);
set local request.jwt.claims to '{"sub":"3355adef-385d-5eee-a565-815c8cf8e4d3","role":"authenticated","app_metadata":{}}';
do $$
declare
  v jsonb;
begin
  v := public.preview_promo_code('VERIF129',
    '[{"product_id":"62599202-a3f0-5adc-ae1c-fe2a691adf92","variant_id":"bf018c0c-bc89-4a35-be63-fefee9faeceb","quantity":1},
      {"product_id":"31987995-52ae-5c1f-81ce-b253f7fe55c3","variant_id":"4f7636da-2e02-4a7f-87b7-281ca1b78872","quantity":-3}]');
  if (v ->> 'valid')::boolean or v ->> 'reason' not like 'Quantité invalide%' then
    raise exception 'ÉCHEC : l''aperçu du code accepte une quantité négative (%)', v;
  end if;
  v := public.preview_promo_code('VERIF129',
    '[{"product_id":"62599202-a3f0-5adc-ae1c-fe2a691adf92","variant_id":"bf018c0c-bc89-4a35-be63-fefee9faeceb","quantity":1}]');
  if not (v ->> 'valid')::boolean then
    raise exception 'ÉCHEC : l''aperçu refuse un code valide (%)', v;
  end if;
  perform set_config('verif.remise_annoncee', v ->> 'discount_fcfa', true);
end $$;
select public.place_order('Moussa', '+22370000002',
  '[{"supplier_id":"b7eb8585-4091-5b6f-83f7-5d70724e97a3","delivery_mode":"self_delivery","items":[{"product_id":"62599202-a3f0-5adc-ae1c-fe2a691adf92","variant_id":"bf018c0c-bc89-4a35-be63-fefee9faeceb","quantity":1}]}]',
  'Maison', 'Bamako', 'Rue 1', 12.6, -8.0, p_promo_code => 'VERIF129') as commande_code \gset
reset role;
select set_config('verif.commande_code', :'commande_code', true);
do $$ begin
  if (select discount_fcfa from public.promo_code_redemptions where order_id = current_setting('verif.commande_code'))::text
     is distinct from current_setting('verif.remise_annoncee') then
    raise exception 'ÉCHEC : remise % au lieu de %',
      (select discount_fcfa from public.promo_code_redemptions where order_id = current_setting('verif.commande_code')),
      current_setting('verif.remise_annoncee');
  end if;
end $$;

-- ---- 5. les contraintes, pour tout autre chemin --------------------------------------------
do $$ begin
  perform verif.refuse('ligne de commande à −1', format($q$insert into public.order_items (group_id, product_id, product_name_snapshot, unit_price_fcfa_snapshot, quantity)
    select id, '62599202-a3f0-5adc-ae1c-fe2a691adf92', 'x', 100, -1 from public.order_supplier_groups where order_id = %L$q$, current_setting('verif.commande')),
    '%order_items_quantity_positive%');
  perform verif.refuse('total négatif', format($q$update public.orders set total_fcfa = -1 where id = %L$q$, current_setting('verif.commande')),
    '%orders_total_not_negative%');
end $$;
set local role authenticated;
do $$ begin
  perform verif.refuse('panier à zéro', $q$insert into public.cart_items (id, user_id, product_id, supplier_id, product_name_snapshot, unit_price_fcfa_snapshot, quantity)
    values ('verif-panier', '3355adef-385d-5eee-a565-815c8cf8e4d3', '62599202-a3f0-5adc-ae1c-fe2a691adf92', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'x', 100, 0)$q$,
    '%cart_items_quantity_positive%');
end $$;
reset role;

\o
select 'TOUTES LES VÉRIFICATIONS PASSENT' as resultat;
rollback;
