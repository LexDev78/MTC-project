-- Vérifie les migrations 0120 à 0122 contre la base locale, sans rien y
-- laisser : tout se passe dans une transaction annulée à la fin.
--
--   docker exec -i supabase_db_MTC_project psql -U postgres -d postgres -q \
--     < supabase/snippets/verif_0120_0122.sql
--
-- Dernière ligne attendue : « TOUTES LES VÉRIFICATIONS PASSENT ». Toute autre
-- issue s'arrête sur l'erreur qui dit ce qui manque.
--
-- Les commandes, livraisons et fichiers vérifiés sont créés ici même. Seuls
-- les comptes de démonstration sont supposés : Awa (client1), Moussa
-- (client2), les boutiques Bogolan Bamako, Electro Bamako et Alimentation
-- Ségou, la collaboratrice « labati » de Bogolan, les livreurs 1 et 2, l'admin
-- et l'agent MTC, et la conversation de démonstration Awa ↔ Bogolan.
\set ON_ERROR_STOP 1
-- Silencieux sauf erreur : seule la dernière ligne compte.
\o /dev/null
\set awa '04060d99-e34d-520e-8b75-631ff4d3c10c'
\set moussa '3355adef-385d-5eee-a565-815c8cf8e4d3'
\set bogolan 'b7eb8585-4091-5b6f-83f7-5d70724e97a3'
\set electro 'dbff9b88-4829-5eed-b15a-78c33431553f'
\set segou '2c66294c-e1d7-59f1-925c-5ab6703827f3'
\set labati '808d8f50-7e2e-4d84-939b-05d96d20b825'
\set livreur1 'f1c4e8a2-0000-5000-9000-000000000001'
\set livreur2 'f1c4e8a2-0000-5000-9000-000000000002'
\set admin '2358888a-b13d-56f8-858b-a0c63831b512'
\set agent '0354c601-5e09-57b6-a23c-affaa5acf0d0'
\set conv '41889195-7cbf-5b45-8d95-de49a8b47cd0'
begin;
set local client_min_messages = warning;

-- ===================== outils (annulés avec le reste) =====================
create schema verif;
grant usage on schema verif to authenticated, anon;

-- Change l'utilisateur simulé, sans changer de rôle Postgres.
create function verif.qui(p_uid uuid) returns void language sql as $$
  select set_config(
    'request.jwt.claims',
    json_build_object('sub', p_uid, 'role', 'authenticated')::text,
    true
  );
$$;

create function verif.egal(p_cas text, p_obtenu jsonb, p_attendu jsonb)
returns void language plpgsql as $$
begin
  if p_obtenu is distinct from p_attendu then
    raise exception 'ÉCHEC % : obtenu %, attendu %',
      p_cas, coalesce(p_obtenu::text, 'null'), coalesce(p_attendu::text, 'null');
  end if;
end $$;

-- Exécute `p_sql` et exige un refus dont le message ressemble à `p_motif`.
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

-- Les coordonnées telles que PostgREST les sert (`select=*,client_contact`) :
-- seulement sur une commande que l'appelant voit.
create function verif.contact(p_commande text) returns jsonb language sql as $$
  select public.client_contact(o) from public.orders o where o.id = p_commande;
$$;

-- La même fonction appelée sur une ligne fabriquée, qui ne porte que
-- l'identifiant et un `client_id` mensonger : elle ne doit rien en croire.
create function verif.contact_fabrique(p_commande text, p_faux_client uuid)
returns jsonb language sql as $$
  select public.client_contact(jsonb_populate_record(
    null::public.orders,
    jsonb_build_object('id', p_commande, 'client_id', p_faux_client)
  ));
$$;

grant execute on all functions in schema verif to authenticated, anon;

-- ===================== jeu d'essai =====================
select phone_number as tel_awa from public.profiles where id = :'awa' \gset

insert into public.orders (id, client_id, client_display_name_snapshot, status, total_fcfa, delivery_city) values
  ('t-cmd-1', :'awa', 'Awa Traoré', 'preparing', 10000, 'Bamako'),
  ('t-cmd-2', :'awa', 'Awa Traoré', 'delivered', 5000, 'Bamako'),
  ('t-cmd-3', :'awa', 'Awa Traoré', 'confirmed', 5000, 'Bamako');

insert into public.order_supplier_groups
  (id, order_id, supplier_id, supplier_name, delivery_mode, delivery_fee_fcfa, subtotal_fcfa, status) values
  ('t-g-1a', 't-cmd-1', :'bogolan', 'Bogolan Bamako', 'self_delivery', 0, 5000, 'confirmed'),
  ('t-g-1b', 't-cmd-1', :'electro', 'Electro Bamako', 'mtc_delivery', 1000, 4000, 'preparing'),
  ('t-g-2', 't-cmd-2', :'bogolan', 'Bogolan Bamako', 'self_delivery', 0, 5000, 'delivered'),
  ('t-g-3', 't-cmd-3', :'bogolan', 'Bogolan Bamako', 'self_delivery', 0, 5000, 'confirmed');

-- t-cmd-3 : le numéro pour le livreur est l'ancien numéro du compte, écrit
-- autrement — il devra suivre le changement de numéro.
insert into public.order_contacts values
  ('t-cmd-1', :'tel_awa', '+22371111111', '+22372222222', 'Maison test', 'Rue test 1', 12.6, -8.0),
  ('t-cmd-2', :'tel_awa', null, null, 'Maison test', 'Rue test 2', 12.61, -8.01),
  ('t-cmd-3', :'tel_awa',
   regexp_replace(right(regexp_replace(:'tel_awa', '[^0-9]', '', 'g'), 8), '(..)(..)(..)(..)', '\1 \2 \3 \4'),
   null, 'Maison test', 'Rue test 3', 12.62, -8.02);

insert into public.deliveries (id, order_id, supplier_group_id, status, offered_to_courier_id, offered_at)
values ('t-liv-1', 't-cmd-1', 't-g-1b', 'offered', :'livreur1', now());

-- ===================== 0120 : la table et les colonnes =====================
do $$
begin
  if exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'orders'
       and column_name in ('client_phone_snapshot', 'courier_phone', 'alternate_phone',
                           'delivery_address_label', 'delivery_details',
                           'delivery_latitude', 'delivery_longitude')
  ) then
    raise exception 'ÉCHEC : une colonne de coordonnées est restée dans orders';
  end if;
  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'orders' and column_name = 'delivery_city'
  ) then
    raise exception 'ÉCHEC : la ville a disparu de orders';
  end if;
  if (select count(*) from public.orders) <> (select count(*) from public.order_contacts) then
    raise exception 'ÉCHEC : une commande sans coordonnées';
  end if;
  if not (select relrowsecurity from pg_class where oid = 'public.order_contacts'::regclass) then
    raise exception 'ÉCHEC : RLS inactive sur order_contacts';
  end if;
  if exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'order_contacts') then
    raise exception 'ÉCHEC : une policy ouvre order_contacts';
  end if;
  if has_table_privilege('authenticated', 'public.order_contacts', 'SELECT')
     or has_table_privilege('anon', 'public.order_contacts', 'SELECT') then
    raise exception 'ÉCHEC : order_contacts lisible directement';
  end if;
  if has_function_privilege('authenticated', 'public.order_contact_access(text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.client_contact(public.orders)', 'EXECUTE') then
    raise exception 'ÉCHEC : une fonction de coordonnées est ouverte à qui ne doit pas';
  end if;
end $$;

set local role authenticated;

-- ---- le client ----
select verif.qui(:'awa');
do $$
begin
  perform verif.egal('Awa, sa commande en cours', verif.contact('t-cmd-1'), jsonb_build_object(
    'phone', '+22371111111', 'alternate_phone', '+22372222222',
    'address_label', 'Maison test', 'address_details', 'Rue test 1',
    'latitude', 12.6, 'longitude', -8.0));
  perform verif.egal('Awa, sa commande livrée garde tout', verif.contact('t-cmd-2') -> 'address_details', to_jsonb('Rue test 2'::text));
  perform verif.egal('Awa, numéro de repli = numéro du compte',
    verif.contact('t-cmd-2') -> 'phone',
    to_jsonb((select phone_number from public.profiles where id = auth.uid())));
  perform verif.refuse('Awa lit order_contacts', 'select * from public.order_contacts', '%permission denied%');
  perform verif.refuse('Awa appelle order_contact_access', 'select * from public.order_contact_access(''t-cmd-1'')', '%permission denied%');
  perform verif.refuse('ancienne colonne', 'select client_phone_snapshot from public.orders', '%does not exist%');
end $$;

-- ---- un autre client ----
select verif.qui(:'moussa');
do $$
begin
  perform verif.egal('Moussa ne voit pas la commande d''Awa', to_jsonb((select count(*) from public.orders where id = 't-cmd-1')), '0');
  perform verif.egal('Moussa, ligne fabriquée à son nom', verif.contact_fabrique('t-cmd-1', auth.uid()), null);
end $$;

-- ---- la boutique qui livre elle-même ----
select verif.qui(:'bogolan');
do $$
begin
  perform verif.egal('Bogolan, en cours et livre lui-même', verif.contact('t-cmd-1'), jsonb_build_object(
    'phone', '+22371111111', 'alternate_phone', '+22372222222',
    'address_label', 'Maison test', 'address_details', 'Rue test 1',
    'latitude', 12.6, 'longitude', -8.0));
  perform verif.egal('Bogolan, part livrée', verif.contact('t-cmd-2'), null);
  perform verif.egal('Bogolan voit encore la commande livrée', to_jsonb((select count(*) from public.orders where id = 't-cmd-2')), '1');
  perform verif.egal('Bogolan voit encore le nom', to_jsonb((select client_display_name_snapshot from public.orders where id = 't-cmd-2')), to_jsonb('Awa Traoré'::text));
  perform verif.refuse('Bogolan lit order_contacts', 'select * from public.order_contacts', '%permission denied%');
end $$;

-- ---- sa collaboratrice : avec la permission « commandes », puis sans ----
select verif.qui(:'labati');
do $$
begin
  perform verif.egal('labati (commandes), numéro', verif.contact('t-cmd-1') -> 'phone', to_jsonb('+22371111111'::text));
end $$;
reset role;
update public.supplier_collaborators set permissions = array['messages'] where user_id = :'labati';
set local role authenticated;
select verif.qui(:'labati');
do $$
begin
  perform verif.egal('labati sans « commandes »', verif.contact_fabrique('t-cmd-1', null), null);
end $$;
reset role;
update public.supplier_collaborators set permissions = array['messages', 'reviews', 'orders'] where user_id = :'labati';
set local role authenticated;

-- ---- la boutique livrée par MTC ----
select verif.qui(:'electro');
do $$
begin
  perform verif.egal('Electro, livré par MTC : adresse sans numéro', verif.contact('t-cmd-1'), jsonb_build_object(
    'address_label', 'Maison test', 'address_details', 'Rue test 1',
    'latitude', 12.6, 'longitude', -8.0));
end $$;

-- ---- une boutique sans rapport, l'admin, l'agent ----
select verif.qui(:'segou');
do $$ begin
  perform verif.egal('Ségou, sans part', verif.contact_fabrique('t-cmd-1', null), null);
end $$;
select verif.qui(:'admin');
do $$ begin
  perform verif.egal('admin', verif.contact_fabrique('t-cmd-1', null), null);
  perform verif.egal('admin, ligne visible', verif.contact('t-cmd-1'), null);
end $$;
select verif.qui(:'agent');
do $$ begin
  perform verif.egal('agent', verif.contact_fabrique('t-cmd-1', null), null);
end $$;

-- ---- le livreur : proposée, acceptée, en route, livrée ----
select verif.qui(:'livreur1');
do $$ begin
  perform verif.egal('livreur 1, course proposée : adresse seule', verif.contact('t-cmd-1'), jsonb_build_object(
    'address_label', 'Maison test', 'address_details', 'Rue test 1',
    'latitude', 12.6, 'longitude', -8.0));
end $$;
select verif.qui(:'livreur2');
do $$ begin
  perform verif.egal('livreur 2, rien', verif.contact_fabrique('t-cmd-1', null), null);
end $$;

reset role;
update public.deliveries
   set status = 'accepted', courier_id = :'livreur1', accepted_at = now()
 where id = 't-liv-1';
set local role authenticated;
select verif.qui(:'livreur1');
do $$ begin
  perform verif.egal('livreur 1, acceptée : numéro', verif.contact('t-cmd-1') -> 'phone', to_jsonb('+22371111111'::text));
  perform verif.egal('livreur 1, acceptée : second numéro', verif.contact('t-cmd-1') -> 'alternate_phone', to_jsonb('+22372222222'::text));
  perform verif.egal('livreur 1, acceptée : adresse', verif.contact('t-cmd-1') -> 'address_details', to_jsonb('Rue test 1'::text));
  perform verif.refuse('livreur lit order_contacts', 'select * from public.order_contacts', '%permission denied%');
end $$;
select verif.qui(:'electro');
do $$ begin
  perform verif.egal('Electro, course acceptée : toujours sans numéro', to_jsonb(verif.contact('t-cmd-1') ? 'phone'), 'false');
end $$;

reset role;
update public.deliveries set status = 'picked_up', picked_up_at = now() where id = 't-liv-1';
set local role authenticated;
select verif.qui(:'livreur1');
do $$ begin
  perform verif.egal('livreur 1, en route : numéro', verif.contact('t-cmd-1') -> 'phone', to_jsonb('+22371111111'::text));
end $$;

reset role;
update public.deliveries set status = 'delivered', delivered_at = now() where id = 't-liv-1';
set local role authenticated;
select verif.qui(:'livreur1');
do $$ begin
  perform verif.egal('livreur 1, livrée : plus rien', verif.contact('t-cmd-1'), null);
end $$;

-- ---- la boutique : sa part livrée, puis l'autre annulée ----
reset role;
update public.order_supplier_groups set status = 'delivered' where id = 't-g-1a';
set local role authenticated;
select verif.qui(:'bogolan');
do $$ begin
  perform verif.egal('Bogolan, sa part livrée', verif.contact('t-cmd-1'), null);
end $$;
select verif.qui(:'electro');
do $$ begin
  perform verif.egal('Electro, sa part encore en cours', verif.contact('t-cmd-1') -> 'address_label', to_jsonb('Maison test'::text));
end $$;
reset role;
update public.order_supplier_groups set status = 'cancelled' where id = 't-g-1b';
set local role authenticated;
select verif.qui(:'electro');
do $$ begin
  perform verif.egal('Electro, sa part annulée', verif.contact('t-cmd-1'), null);
end $$;
select verif.qui(:'awa');
do $$ begin
  perform verif.egal('Awa garde tout après coup', verif.contact('t-cmd-1') -> 'phone', to_jsonb('+22371111111'::text));
end $$;

-- ---- anonyme ----
reset role;
set local role anon;
set local request.jwt.claims to '{"role":"anon"}';
do $$ begin
  perform verif.refuse('anon, colonne calculée', 'select public.client_contact(null::public.orders)', '%permission denied%');
  perform verif.refuse('anon, table', 'select * from public.order_contacts', '%permission denied%');
end $$;
reset role;

-- ---- place_order range les coordonnées à part ----
select v.id as variante from public.product_variants v
 where v.product_id = 'b0fe527e-1f73-55e6-b24e-4d985576d473' and v.is_default \gset
set local role authenticated;
select verif.qui(:'awa');
select public.place_order(
  p_client_display_name_snapshot => 'Awa Traoré',
  p_client_phone_snapshot => '',
  p_groups => jsonb_build_array(jsonb_build_object(
    'supplier_id', :'bogolan', 'supplier_name', 'Bogolan Bamako',
    'delivery_mode', 'self_delivery',
    'items', jsonb_build_array(jsonb_build_object(
      'product_id', 'b0fe527e-1f73-55e6-b24e-4d985576d473', 'variant_id', :'variante',
      'quantity', 1, 'product_name_snapshot', 'Tissu Bogolan traditionnel',
      'variant_name_snapshot', 'Standard'))
  )),
  p_delivery_address_label => 'Maison place_order',
  p_delivery_city => 'Bamako',
  p_delivery_details => 'Rue place_order',
  p_delivery_latitude => 12.64,
  p_delivery_longitude => -7.99,
  p_courier_phone => '  ',
  p_alternate_phone => '+22373333333'
) as nouvelle \gset
select set_config('verif.nouvelle', :'nouvelle', true);
reset role;
do $$
declare
  c public.order_contacts;
begin
  select * into c from public.order_contacts
   where order_id = current_setting('verif.nouvelle');
  if not found then
    raise exception 'ÉCHEC : place_order n''a rangé aucune coordonnée';
  end if;
  if c.address_label is distinct from 'Maison place_order'
     or c.address_details is distinct from 'Rue place_order'
     or c.latitude is distinct from 12.64 then
    raise exception 'ÉCHEC : place_order n''a pas rangé l''adresse (%)', row_to_json(c);
  end if;
  if c.courier_phone is not null then
    raise exception 'ÉCHEC : un numéro vide gardé pour le livreur';
  end if;
  if c.alternate_phone is distinct from '+22373333333' then
    raise exception 'ÉCHEC : second numéro perdu';
  end if;
  if c.client_phone is distinct from (select phone_number from public.profiles where id = '04060d99-e34d-520e-8b75-631ff4d3c10c') then
    raise exception 'ÉCHEC : numéro vide sans repli sur le compte';
  end if;
end $$;
set local role authenticated;
select verif.qui(:'awa');
select verif.egal('Awa, la commande passée', verif.contact(:'nouvelle') -> 'address_label', to_jsonb('Maison place_order'::text));
reset role;

-- ===================== 0121 : numéro, date de naissance, photo =====================
set local role authenticated;
select verif.qui(:'awa');
do $$
declare
  v text;
begin
  perform verif.egal('saisie avec espaces', to_jsonb(public.set_my_phone_number(' 70 99 88 77 ')), to_jsonb('+22370998877'::text));
  perform verif.egal('saisie 00223', to_jsonb(public.set_my_phone_number('0022366554433')), to_jsonb('+22366554433'::text));
  perform verif.egal('saisie 223', to_jsonb(public.set_my_phone_number('223 66 55 44 33')), to_jsonb('+22366554433'::text));
  perform verif.egal('saisie +223 avec tirets', to_jsonb(public.set_my_phone_number('+223 70-99-88-77')), to_jsonb('+22370998877'::text));
  perform verif.refuse('trop court', 'select public.set_my_phone_number(''12345'')', '%Numéro malien invalide%');
  perform verif.refuse('commence par 4', 'select public.set_my_phone_number(''40000000'')', '%Numéro malien invalide%');
  perform verif.refuse('vide', 'select public.set_my_phone_number('''')', '%Numéro malien invalide%');
  perform verif.refuse('autre pays', 'select public.set_my_phone_number(''+33612345678'')', '%Numéro malien invalide%');
  perform verif.refuse('écriture directe', 'update public.profiles set phone_number = ''+22370000000'' where id = auth.uid()', '%permission denied%');
  perform verif.egal('profil', to_jsonb((select phone_number from public.profiles where id = auth.uid())), to_jsonb('+22370998877'::text));
end $$;
reset role;
do $$
declare
  c1 public.order_contacts;
  c2 public.order_contacts;
  c3 public.order_contacts;
begin
  select * into c1 from public.order_contacts where order_id = 't-cmd-1';
  select * into c2 from public.order_contacts where order_id = 't-cmd-2';
  select * into c3 from public.order_contacts where order_id = 't-cmd-3';
  -- t-cmd-1 est maintenant terminée (part livrée, part annulée) : elle garde
  -- son numéro.
  if c1.client_phone = '+22370998877' then raise exception 'ÉCHEC : commande terminée modifiée (1)'; end if;
  if c2.client_phone = '+22370998877' then raise exception 'ÉCHEC : commande livrée modifiée (2)'; end if;
  if c3.client_phone <> '+22370998877' then raise exception 'ÉCHEC : commande en cours non suivie (%)', c3.client_phone; end if;
  if c3.courier_phone <> '+22370998877' then raise exception 'ÉCHEC : numéro livreur égal à l''ancien non suivi (%)', c3.courier_phone; end if;
end $$;

-- Un numéro livreur choisi à part n'est pas écrasé.
update public.order_contacts set courier_phone = '+22371234567' where order_id = 't-cmd-3';
set local role authenticated;
select verif.qui(:'awa');
select public.set_my_phone_number('70 55 44 33');
reset role;
do $$ begin
  if (select courier_phone from public.order_contacts where order_id = 't-cmd-3') <> '+22371234567' then
    raise exception 'ÉCHEC : le numéro choisi pour le livreur a été écrasé';
  end if;
  if (select client_phone from public.order_contacts where order_id = 't-cmd-3') <> '+22370554433' then
    raise exception 'ÉCHEC : le numéro du compte n''a pas suivi';
  end if;
  if (select phone_number from public.profiles where id = '3355adef-385d-5eee-a565-815c8cf8e4d3') = '+22370554433' then
    raise exception 'ÉCHEC : le profil d''un autre a changé';
  end if;
end $$;

-- Les autres rôles ne changent pas leur numéro par là.
set local role authenticated;
select verif.qui(:'bogolan');
do $$ begin
  perform verif.refuse('boutique', 'select public.set_my_phone_number(''70000000'')', '%espace de votre compte%');
  perform verif.refuse('boutique, date', 'select public.set_my_birth_date(''1990-01-01'')', '%compte client%');
  perform verif.refuse('boutique, photo', 'select public.set_my_avatar(null)', '%compte client%');
end $$;
select verif.qui(:'livreur1');
do $$ begin
  perform verif.refuse('livreur', 'select public.set_my_phone_number(''70000000'')', '%espace de votre compte%');
end $$;

-- La date de naissance.
select verif.qui(:'awa');
do $$ begin
  perform verif.egal('date', to_jsonb(public.set_my_birth_date('1995-03-12')), to_jsonb('1995-03-12'::date));
  perform verif.refuse('date future', 'select public.set_my_birth_date(current_date + 1)', '%futur%');
  perform verif.refuse('date trop ancienne', 'select public.set_my_birth_date(''1899-12-31'')', '%1900%');
  perform verif.egal('date toujours là après les refus', to_jsonb((select birth_date from public.profiles where id = auth.uid())), to_jsonb('1995-03-12'::date));
  perform verif.refuse('date en direct', 'update public.profiles set birth_date = ''2000-01-01'' where id = auth.uid()', '%permission denied%');
end $$;
select verif.qui(:'moussa');
do $$ begin
  perform verif.egal('Moussa ne lit pas la date d''Awa',
    to_jsonb((select count(*) from public.profiles where id = '04060d99-e34d-520e-8b75-631ff4d3c10c')), '0');
end $$;
select verif.qui(:'awa');
do $$ begin
  perform verif.egal('date retirée', to_jsonb(public.set_my_birth_date(null)), null);
  perform verif.egal('date bien retirée', to_jsonb((select birth_date from public.profiles where id = auth.uid())), null);
end $$;

-- La photo : le bucket.
reset role;
do $$ begin
  if (select public from storage.buckets where id = 'avatars') then
    raise exception 'ÉCHEC : bucket des photos public';
  end if;
end $$;
-- Deux fichiers déposés par Awa, un par Moussa (en direct : c'est la ligne
-- que l'API de stockage écrit).
insert into storage.objects (bucket_id, name, owner, owner_id) values
  ('avatars', :'awa' || '/a.jpg', :'awa', :'awa'),
  ('avatars', :'awa' || '/b.jpg', :'awa', :'awa'),
  ('avatars', :'moussa' || '/m.jpg', :'moussa', :'moussa');
set local role authenticated;
select verif.qui(:'moussa');
do $$ begin
  perform verif.egal('Moussa ne voit pas les photos d''Awa',
    to_jsonb((select count(*) from storage.objects where bucket_id = 'avatars' and name like '04060d99-e34d-520e-8b75-631ff4d3c10c/%')), '0');
  perform verif.egal('Moussa voit la sienne',
    to_jsonb((select count(*) from storage.objects where bucket_id = 'avatars' and name like '3355adef-385d-5eee-a565-815c8cf8e4d3/%')), '1');
  perform verif.refuse('Moussa dépose chez Awa',
    'insert into storage.objects (bucket_id, name) values (''avatars'', ''04060d99-e34d-520e-8b75-631ff4d3c10c/pirate.jpg'')',
    '%row-level security%');
end $$;
select verif.qui(:'bogolan');
do $$ begin
  perform verif.egal('une boutique ne voit aucune photo de client',
    to_jsonb((select count(*) from storage.objects where bucket_id = 'avatars')), '0');
end $$;
select verif.qui(:'awa');
do $$ begin
  insert into storage.objects (bucket_id, name) values ('avatars', '04060d99-e34d-520e-8b75-631ff4d3c10c/c.jpg');
  perform verif.egal('photo retenue', to_jsonb(public.set_my_avatar('04060d99-e34d-520e-8b75-631ff4d3c10c/a.jpg')),
    to_jsonb('04060d99-e34d-520e-8b75-631ff4d3c10c/a.jpg'::text));
  perform verif.refuse('photo de Moussa', 'select public.set_my_avatar(''3355adef-385d-5eee-a565-815c8cf8e4d3/m.jpg'')', '%Photo introuvable%');
  perform verif.refuse('photo absente', 'select public.set_my_avatar(''04060d99-e34d-520e-8b75-631ff4d3c10c/absente.jpg'')', '%Photo introuvable%');
  perform verif.refuse('sous-dossier', 'select public.set_my_avatar(''04060d99-e34d-520e-8b75-631ff4d3c10c/x/a.jpg'')', '%Photo introuvable%');
  perform verif.refuse('remontée', 'select public.set_my_avatar(''../04060d99-e34d-520e-8b75-631ff4d3c10c/a.jpg'')', '%Photo introuvable%');
  perform verif.refuse('photo en direct', 'update public.profiles set avatar_path = ''x'' where id = auth.uid()', '%permission denied%');
  perform verif.egal('remplacée', to_jsonb(public.set_my_avatar('04060d99-e34d-520e-8b75-631ff4d3c10c/b.jpg')),
    to_jsonb('04060d99-e34d-520e-8b75-631ff4d3c10c/b.jpg'::text));
  perform verif.egal('retirée', to_jsonb(public.set_my_avatar(null)), null);
end $$;
reset role;
do $$ begin
  if (select avatar_path from public.profiles where id = '04060d99-e34d-520e-8b75-631ff4d3c10c') is not null then
    raise exception 'ÉCHEC : photo non retirée';
  end if;
  if (select count(*) from public.storage_purge_queue
       where bucket_id = 'avatars'
         and object_path in ('04060d99-e34d-520e-8b75-631ff4d3c10c/a.jpg', '04060d99-e34d-520e-8b75-631ff4d3c10c/b.jpg')) <> 2 then
    raise exception 'ÉCHEC : les photos remplacées ne sont pas en file d''effacement';
  end if;
end $$;
set local role anon;
set local request.jwt.claims to '{"role":"anon"}';
do $$ begin
  perform verif.refuse('anon, numéro', 'select public.set_my_phone_number(''70000000'')', '%permission denied%');
  perform verif.refuse('anon, date', 'select public.set_my_birth_date(null)', '%permission denied%');
  perform verif.refuse('anon, photo', 'select public.set_my_avatar(null)', '%permission denied%');
  perform verif.refuse('anon, fermeture', 'select public.set_my_conversation_closed(''x'', true)', '%permission denied%');
  perform verif.refuse('anon, lecture', 'select public.mark_my_conversation_read(''x'')', '%permission denied%');
end $$;
reset role;

-- ===================== 0122 : fermer une conversation =====================
select unread_count_client as non_lus_client, unread_count_supplier as non_lus_boutique
  from public.chat_conversations where id = :'conv' \gset

-- Les droits : plus aucune écriture directe sauf la création.
do $$ begin
  if has_table_privilege('authenticated', 'public.chat_conversations', 'UPDATE')
     or has_table_privilege('authenticated', 'public.chat_conversations', 'DELETE') then
    raise exception 'ÉCHEC : chat_conversations modifiable directement';
  end if;
  if has_column_privilege('authenticated', 'public.chat_conversations', 'closed_at', 'INSERT')
     or has_column_privilege('authenticated', 'public.chat_conversations', 'unread_count_client', 'INSERT') then
    raise exception 'ÉCHEC : une colonne tenue par la base est fournie à la création';
  end if;
end $$;

set local role authenticated;
select verif.qui(:'moussa');
do $$ begin
  perform verif.refuse('Moussa ferme la conversation d''Awa', 'select public.set_my_conversation_closed(''41889195-7cbf-5b45-8d95-de49a8b47cd0'', true)', 'Conversation introuvable.');
end $$;
select verif.qui(:'bogolan');
do $$ begin
  perform verif.refuse('la boutique ferme', 'select public.set_my_conversation_closed(''41889195-7cbf-5b45-8d95-de49a8b47cd0'', true)', 'Conversation introuvable.');
end $$;

select verif.qui(:'awa');
do $$ begin
  if public.set_my_conversation_closed('41889195-7cbf-5b45-8d95-de49a8b47cd0', true) is null then
    raise exception 'ÉCHEC : fermeture sans date';
  end if;
end $$;

-- Tout ce par quoi la boutique atteignait le client est fermé.
select verif.qui(:'bogolan');
do $$ begin
  perform verif.refuse('message de la boutique',
    'insert into public.chat_messages (id, conversation_id, sender_id, text) values (''t-msg-b1'', ''41889195-7cbf-5b45-8d95-de49a8b47cd0'', ''b7eb8585-4091-5b6f-83f7-5d70724e97a3'', ''Promo !'')',
    '%fermé la conversation%');
  perform verif.refuse('rouvrir en direct',
    'update public.chat_conversations set closed_at = null where id = ''41889195-7cbf-5b45-8d95-de49a8b47cd0''',
    '%permission denied%');
  perform verif.refuse('aperçu en direct',
    'update public.chat_conversations set last_message_preview = ''Promo !'' where id = ''41889195-7cbf-5b45-8d95-de49a8b47cd0''',
    '%permission denied%');
  perform verif.refuse('compteur en direct',
    'update public.chat_conversations set unread_count_client = 99 where id = ''41889195-7cbf-5b45-8d95-de49a8b47cd0''',
    '%permission denied%');
  perform verif.refuse('supprimer pour recommencer',
    'delete from public.chat_conversations where id = ''41889195-7cbf-5b45-8d95-de49a8b47cd0''',
    '%permission denied%');
  perform verif.refuse('seconde conversation',
    'insert into public.chat_conversations (id, client_id, client_display_name_snapshot, supplier_id, supplier_name) values (''t-conv-bis'', ''04060d99-e34d-520e-8b75-631ff4d3c10c'', ''Awa'', ''b7eb8585-4091-5b6f-83f7-5d70724e97a3'', ''Bogolan'')',
    '%duplicate key%');
  perform verif.refuse('pièce jointe',
    'insert into storage.objects (bucket_id, name) values (''chat-attachments'', ''41889195-7cbf-5b45-8d95-de49a8b47cd0/pirate.jpg'')',
    '%row-level security%');
  perform verif.egal('la boutique relit encore', to_jsonb((select count(*) from public.chat_messages where conversation_id = '41889195-7cbf-5b45-8d95-de49a8b47cd0') > 0), 'true');
  perform public.mark_my_conversation_read('41889195-7cbf-5b45-8d95-de49a8b47cd0');
end $$;
select verif.qui(:'labati');
do $$ begin
  perform verif.refuse('message de la collaboratrice',
    'insert into public.chat_messages (id, conversation_id, sender_id, text) values (''t-msg-l1'', ''41889195-7cbf-5b45-8d95-de49a8b47cd0'', ''808d8f50-7e2e-4d84-939b-05d96d20b825'', ''Bonjour'')',
    '%fermé la conversation%');
end $$;
reset role;
do $$ begin
  if (select closed_at from public.chat_conversations where id = '41889195-7cbf-5b45-8d95-de49a8b47cd0') is null then
    raise exception 'ÉCHEC : la conversation s''est rouverte sans le client';
  end if;
  if (select last_message_preview from public.chat_conversations where id = '41889195-7cbf-5b45-8d95-de49a8b47cd0') = 'Promo !' then
    raise exception 'ÉCHEC : aperçu réécrit';
  end if;
end $$;

-- Le client rouvre en écrivant ; aperçu et compteur suivent.
set local role authenticated;
select verif.qui(:'awa');
insert into public.chat_messages (id, conversation_id, sender_id, text)
values ('t-msg-a1', :'conv', :'awa', 'Finalement, une question.');
reset role;
do $$ begin
  if (select closed_at from public.chat_conversations where id = '41889195-7cbf-5b45-8d95-de49a8b47cd0') is not null then
    raise exception 'ÉCHEC : écrire n''a pas rouvert';
  end if;
  if (select last_message_preview from public.chat_conversations where id = '41889195-7cbf-5b45-8d95-de49a8b47cd0') <> 'Finalement, une question.' then
    raise exception 'ÉCHEC : aperçu non tenu par la base';
  end if;
  -- La boutique avait tout lu juste avant : son compteur repart de 1.
  if (select unread_count_supplier from public.chat_conversations where id = '41889195-7cbf-5b45-8d95-de49a8b47cd0') <> 1 then
    raise exception 'ÉCHEC : compteur boutique non incrémenté';
  end if;
end $$;
set local role authenticated;
select verif.qui(:'bogolan');
insert into public.chat_messages (id, conversation_id, sender_id, text, product_name_snapshot)
values ('t-msg-b2', :'conv', :'bogolan', '', 'Tissu Bogolan');
reset role;
do $$ begin
  if (select last_message_preview from public.chat_conversations where id = '41889195-7cbf-5b45-8d95-de49a8b47cd0') <> '📦 Tissu Bogolan' then
    raise exception 'ÉCHEC : aperçu produit';
  end if;
end $$;
select unread_count_client as client_avant_lecture from public.chat_conversations where id = :'conv' \gset
select verif.egal('compteur client', to_jsonb(:'client_avant_lecture'::int), to_jsonb(:'non_lus_client'::int + 1));

-- Lire remet son propre compteur à zéro et ne marque lus que les messages de
-- l'autre.
set local role authenticated;
select verif.qui(:'awa');
select public.mark_my_conversation_read(:'conv');
reset role;
do $$ begin
  if (select unread_count_client from public.chat_conversations where id = '41889195-7cbf-5b45-8d95-de49a8b47cd0') <> 0 then
    raise exception 'ÉCHEC : compteur client non remis à zéro';
  end if;
  if (select unread_count_supplier from public.chat_conversations where id = '41889195-7cbf-5b45-8d95-de49a8b47cd0') <> 1 then
    raise exception 'ÉCHEC : le compteur de la boutique a bougé';
  end if;
  if not (select is_read from public.chat_messages where id = 't-msg-b2') then
    raise exception 'ÉCHEC : message de la boutique non marqué lu';
  end if;
  if (select is_read from public.chat_messages where id = 't-msg-a1') then
    raise exception 'ÉCHEC : son propre message marqué lu';
  end if;
end $$;
set local role authenticated;
select verif.qui(:'moussa');
do $$ begin
  perform verif.refuse('Moussa lit la conversation d''Awa', 'select public.mark_my_conversation_read(''41889195-7cbf-5b45-8d95-de49a8b47cd0'')', 'Conversation introuvable.');
end $$;

-- Rouvrir d'un geste, refermer.
select verif.qui(:'awa');
do $$ begin
  perform public.set_my_conversation_closed('41889195-7cbf-5b45-8d95-de49a8b47cd0', true);
  if public.set_my_conversation_closed('41889195-7cbf-5b45-8d95-de49a8b47cd0', false) is not null then
    raise exception 'ÉCHEC : réouverture';
  end if;
end $$;
select verif.qui(:'bogolan');
insert into public.chat_messages (id, conversation_id, sender_id, text)
values ('t-msg-b3', :'conv', :'bogolan', 'Merci de votre retour.');

-- Qui ouvre une conversation, et sous quel nom.
select verif.qui(:'electro');
insert into public.chat_conversations (id, client_id, client_display_name_snapshot, supplier_id, supplier_name)
values ('t-conv-electro', :'awa', 'Nom inventé', :'electro', 'MTC Service client');
do $$ begin
  perform verif.refuse('Electro écrit à Moussa sans commande',
    'insert into public.chat_conversations (id, client_id, client_display_name_snapshot, supplier_id, supplier_name) values (''t-conv-electro-2'', ''3355adef-385d-5eee-a565-815c8cf8e4d3'', ''Moussa'', ''dbff9b88-4829-5eed-b15a-78c33431553f'', ''Electro'')',
    '%row-level security%');
  perform verif.refuse('Electro se fait passer pour Bogolan',
    'insert into public.chat_conversations (id, client_id, client_display_name_snapshot, supplier_id, supplier_name) values (''t-conv-usurpe'', ''3355adef-385d-5eee-a565-815c8cf8e4d3'', ''Moussa'', ''b7eb8585-4091-5b6f-83f7-5d70724e97a3'', ''Bogolan'')',
    '%row-level security%');
end $$;
select verif.qui(:'moussa');
insert into public.chat_conversations (id, client_id, client_display_name_snapshot, supplier_id, supplier_name)
values ('t-conv-moussa', :'moussa', 'Moussa', :'electro', 'Faux nom');
do $$ begin
  perform verif.refuse('Moussa ouvre au nom d''Awa',
    'insert into public.chat_conversations (id, client_id, client_display_name_snapshot, supplier_id, supplier_name) values (''t-conv-faux'', ''04060d99-e34d-520e-8b75-631ff4d3c10c'', ''Awa'', ''2c66294c-e1d7-59f1-925c-5ab6703827f3'', ''Ségou'')',
    '%row-level security%');
end $$;
reset role;
do $$ begin
  if (select supplier_name from public.chat_conversations where id = 't-conv-electro') <> 'Electro Bamako'
     or (select client_display_name_snapshot from public.chat_conversations where id = 't-conv-electro')
        <> (select display_name from public.profiles where id = '04060d99-e34d-520e-8b75-631ff4d3c10c') then
    raise exception 'ÉCHEC : noms fournis par l''application gardés';
  end if;
  if (select supplier_name from public.chat_conversations where id = 't-conv-moussa') <> 'Electro Bamako' then
    raise exception 'ÉCHEC : nom de boutique fourni par le client gardé';
  end if;
end $$;

-- Une conversation fermée reste fermée pour la boutique même après son
-- propre message refusé ; le client peut toujours déposer une pièce jointe.
set local role authenticated;
select verif.qui(:'awa');
select public.set_my_conversation_closed(:'conv', true);
insert into storage.objects (bucket_id, name) values ('chat-attachments', :'conv' || '/photo.jpg');
reset role;

rollback;

\o
\echo 'TOUTES LES VÉRIFICATIONS PASSENT'
