-- Vérifie 0138 (un avis par client, boutique et période) et 0139 (la remise
-- d'une commande livrée par la boutique se prouve) contre une base où elles
-- sont appliquées, sans rien y laisser : tout se passe dans une transaction
-- annulée.
--
--   docker exec -i supabase_db_mtc_verif psql -U postgres -d postgres -q \
--     < supabase/snippets/verif_0138_0139.sql
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
-- Une commande d'une ligne chez Bogolan, livrée par la boutique, passée par
-- le client courant : le même appel que l'app.
create function verif.commander() returns text language sql as $$
  select public.place_order(
    'Client essai', '+22370000009',
    jsonb_build_array(jsonb_build_object(
      'supplier_id', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3',
      'supplier_name', 'Bogolan Bamako',
      'delivery_mode', 'self_delivery',
      'items', jsonb_build_array(jsonb_build_object(
        'product_id', 'b0fe527e-1f73-55e6-b24e-4d985576d473',
        -- Les identifiants de variantes sont tirés au semis : on les lit.
        'variant_id', (select v.id from public.product_variants v
                        where v.product_id = 'b0fe527e-1f73-55e6-b24e-4d985576d473'
                        order by v.id limit 1),
        'quantity', 1)))),
    'Domicile', 'Bamako', 'Badalabougou', 12.63, -8.0);
$$;
create function verif.groupe(p_commande text) returns text language sql security definer as $$
  select id from public.order_supplier_groups where order_id = p_commande;
$$;
create function verif.statut(p_groupe text) returns text language sql security definer as $$
  select status::text from public.order_supplier_groups where id = p_groupe;
$$;
grant execute on all functions in schema verif to anon, authenticated;

\set bogolan 'b7eb8585-4091-5b6f-83f7-5d70724e97a3'
\set awa '04060d99-e34d-520e-8b75-631ff4d3c10c'
\set moussa '3355adef-385d-5eee-a565-815c8cf8e4d3'

-- Un collaborateur de Bogolan qui n'a que les messages.
insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data, raw_user_meta_data)
values ('cccccccc-0000-4000-8000-000000000139', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'verif-collab-139@mtc.local',
        jsonb_build_object('collaborator_of', :'bogolan', 'permissions', jsonb_build_array('messages')),
        jsonb_build_object('username_or_phone', 'verif-collab-139', 'display_name', 'Vendeur', 'phone_number', '+22370000139'));

-- ---- 1. la boutique ne se déclare plus livrée seule --------------------------------------
set local role authenticated;
select verif.comme(:'awa');
select verif.commander() as cmd \gset
select verif.groupe(:'cmd') as grp \gset
select set_config('verif.cmd', :'cmd', true), set_config('verif.grp', :'grp', true);

select verif.comme(:'bogolan');
select public.update_order_group_status(:'cmd', :'grp', 'confirmed');
select public.update_order_group_status(:'cmd', :'grp', 'preparing');
select public.update_order_group_status(:'cmd', :'grp', 'in_transit');
do $$ begin
  begin
    perform public.update_order_group_status(
      current_setting('verif.cmd'), current_setting('verif.grp'), 'delivered');
    raise exception 'ÉCHEC : la boutique passe seule une commande à « livrée »';
  exception when raise_exception then
    if sqlerrm like 'ÉCHEC%' then raise; end if;
  end;
  if verif.statut(current_setting('verif.grp')) <> 'in_transit' then
    raise exception 'ÉCHEC : le groupe a bougé (%)', verif.statut(current_setting('verif.grp'));
  end if;
  -- Et elle ne lit pas le code du client.
  begin
    perform public.fetch_self_delivery_code(current_setting('verif.grp'));
    raise exception 'ÉCHEC : la boutique lit le code de remise du client';
  exception when raise_exception then
    if sqlerrm like 'ÉCHEC%' then raise; end if;
  end;
  if exists (select 1 from public.self_delivery_handovers) then
    raise exception 'ÉCHEC : la table des remises est lisible';
  end if;
exception when insufficient_privilege then null;  -- la table : refusée, c'est le but
end $$;

-- ---- 2. le code : au client seul, une fois, et exact --------------------------------------
select verif.comme(:'moussa');
do $$ begin
  begin
    perform public.fetch_self_delivery_code(current_setting('verif.grp'));
    raise exception 'ÉCHEC : un autre client lit le code de remise';
  exception when raise_exception then
    if sqlerrm like 'ÉCHEC%' then raise; end if;
  end;
end $$;
select verif.comme(:'awa');
select public.fetch_self_delivery_code(:'grp') as code \gset
select public.fetch_self_delivery_code(:'grp') as code2 \gset
select set_config('verif.code', :'code', true), set_config('verif.code2', :'code2', true);

do $$ begin
  if length(current_setting('verif.code')) <> 64 then
    raise exception 'ÉCHEC : code de remise trop court (%)', current_setting('verif.code');
  end if;
  if current_setting('verif.code') <> current_setting('verif.code2') then
    raise exception 'ÉCHEC : le code change à chaque lecture';
  end if;
end $$;

-- Le collaborateur sans « commandes » ne scanne pas, même avec le bon code.
select verif.comme('cccccccc-0000-4000-8000-000000000139');
do $$ begin
  begin
    perform public.confirm_self_delivery_by_code(current_setting('verif.grp'), current_setting('verif.code'));
    raise exception 'ÉCHEC : un collaborateur sans accès aux commandes clôt une remise';
  exception when raise_exception then
    if sqlerrm like 'ÉCHEC%' then raise; end if;
  end;
end $$;

-- La boutique : un faux code échoue, le bon clôt, et ne resert pas.
select verif.comme(:'bogolan');
do $$ begin
  begin
    perform public.confirm_self_delivery_by_code(current_setting('verif.grp'), repeat('0', 64));
    raise exception 'ÉCHEC : un faux code clôt la remise';
  exception when raise_exception then
    if sqlerrm like 'ÉCHEC%' then raise; end if;
    if sqlerrm <> 'Code de remise invalide.' then
      raise exception 'ÉCHEC : message inattendu pour un faux code (%)', sqlerrm;
    end if;
  end;
  perform public.confirm_self_delivery_by_code(current_setting('verif.grp'), current_setting('verif.code'));
  if verif.statut(current_setting('verif.grp')) <> 'delivered' then
    raise exception 'ÉCHEC : le bon code ne clôt pas la remise';
  end if;
end $$;
select verif.comme(:'awa');
do $$ begin
  if public.fetch_self_delivery_code(current_setting('verif.grp')) is not null then
    raise exception 'ÉCHEC : le code reste affiché une fois servi';
  end if;
end $$;

-- ---- 3. le client confirme lui-même --------------------------------------------------------
select verif.commander() as cmd2 \gset
select verif.groupe(:'cmd2') as grp2 \gset
select set_config('verif.cmd2', :'cmd2', true), set_config('verif.grp2', :'grp2', true);
select verif.comme(:'bogolan');
select public.update_order_group_status(:'cmd2', :'grp2', 'confirmed');
-- Une commande seulement acceptée ne se confirme pas reçue : elle n'est pas
-- partie (contre-vérification du 06/11/2026).
select verif.comme(:'awa');
do $$ begin
  begin
    perform public.confirm_self_delivery_received(current_setting('verif.grp2'));
    raise exception 'ÉCHEC : le client clôt une commande que la boutique vient d''accepter';
  exception when raise_exception then
    if sqlerrm like 'ÉCHEC%' then raise; end if;
  end;
end $$;
select verif.comme(:'bogolan');
select public.update_order_group_status(:'cmd2', :'grp2', 'preparing');
select public.update_order_group_status(:'cmd2', :'grp2', 'in_transit');

-- Un autre client ne confirme pas à sa place.
select verif.comme(:'moussa');
do $$ begin
  begin
    perform public.confirm_self_delivery_received(current_setting('verif.grp2'));
    raise exception 'ÉCHEC : un autre client confirme la réception';
  exception when raise_exception then
    if sqlerrm like 'ÉCHEC%' then raise; end if;
  end;
end $$;

select verif.comme(:'awa');
select public.confirm_self_delivery_received(:'grp2');
select public.confirm_self_delivery_received(:'grp2');  -- double appui : sans effet
reset role;
do $$ begin
  if verif.statut(current_setting('verif.grp2')) <> 'delivered' then
    raise exception 'ÉCHEC : la confirmation du client ne clôt pas la commande';
  end if;
  if (select status from public.orders where id = current_setting('verif.cmd2')) <> 'delivered' then
    raise exception 'ÉCHEC : la commande ne suit pas son groupe';
  end if;
  if (select count(*) from public.notifications
       where user_id = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3'
         and reference_id = current_setting('verif.cmd2')
         and title = 'Réception confirmée') <> 1 then
    raise exception 'ÉCHEC : la boutique n''est pas avertie (une fois) de la réception';
  end if;
end $$;

-- ---- 4. 0138 : un avis par boutique et par période -----------------------------------------
set local role authenticated;
select verif.comme(:'awa');
-- Les avis qu'Awa a déjà laissés chez Bogolan sont mis hors période ; le
-- premier de cette vérification passe, le second (une autre commande, la
-- même boutique) non.
reset role;
select set_config('request.jwt.claims', '{}', true);  -- le décor, hors de toute session
update public.reviews set created_at = now() - interval '40 days'
 where client_id = :'awa' and supplier_id = :'bogolan';
set local role authenticated;
select verif.comme(:'awa');
select public.submit_review(:'cmd', :'grp', 5, 'Très beau pagne.');
do $$ begin
  begin
    perform public.submit_review(current_setting('verif.cmd2'), current_setting('verif.grp2'), 5, 'Encore parfait.');
    raise exception 'ÉCHEC : deux avis sur la même boutique le même mois';
  exception when raise_exception then
    if sqlerrm like 'ÉCHEC%' then raise; end if;
    if sqlerrm not like 'Vous avez déjà noté cette boutique le %' then
      raise exception 'ÉCHEC : message inattendu (%)', sqlerrm;
    end if;
  end;
end $$;
-- Trente jours plus tard, elle peut noter à nouveau.
reset role;
select set_config('request.jwt.claims', '{}', true);
update public.reviews set created_at = now() - interval '31 days'
 where client_id = :'awa' and supplier_id = :'bogolan';
set local role authenticated;
select verif.comme(:'awa');
select public.submit_review(:'cmd2', :'grp2', 4, 'Toujours bien.');
reset role;

\o
select 'TOUTES LES VÉRIFICATIONS PASSENT' as resultat;
rollback;
