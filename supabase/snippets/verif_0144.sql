-- Vérifie 0144 (identité à l'inscription, noms réservés) contre une base où
-- elle est appliquée, sans rien y laisser : tout se passe dans une
-- transaction annulée.
--
--   docker exec -i supabase_db_mtc_verif psql -U postgres -d postgres -q \
--     < supabase/snippets/verif_0144.sql
--
-- Dernière ligne attendue : « TOUTES LES VÉRIFICATIONS PASSENT ».
\set ON_ERROR_STOP 1
\o /dev/null
begin;
set local client_min_messages = warning;

create schema verif;
grant usage on schema verif to anon, authenticated;
-- Une inscription telle que GoTrue l'écrit : une ligne dans `auth.users`,
-- les métadonnées de l'appelant, et le contrôle différé joué tout de suite.
-- Vrai si elle est refusée.
create function verif.inscription_refusee(p_email text, p_meta jsonb, p_app jsonb default '{}')
returns boolean language plpgsql as $$
begin
  insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data, raw_user_meta_data)
  values (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', p_email, p_app,
          jsonb_build_object('display_name', 'Essai', 'phone_number', '+22370009000') || p_meta);
  set constraints all immediate;
  set constraints all deferred;
  return false;
exception when others then
  return true;
end $$;
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
grant execute on all functions in schema verif to anon, authenticated;

-- ---- 1. l'identifiant est celui du compte ------------------------------------------------------
do $$ begin
  -- « Client1 » à côté de « client1 », sous une autre adresse…
  if not verif.inscription_refusee('autre@mtc.local', '{"username_or_phone": "Client1"}') then
    raise exception 'ÉCHEC : un identifiant sans rapport avec l''adresse passe';
  end if;
  -- …et sous la bonne adresse : l'unicité ignore la casse.
  if not verif.inscription_refusee('client1@mtc.local', '{"username_or_phone": "Client1"}')
     and not verif.inscription_refusee('Client1@mtc.local', '{"username_or_phone": "Client1"}') then
    raise exception 'ÉCHEC : « Client1 » s''inscrit à côté de « client1 »';
  end if;
  if not verif.inscription_refusee('client1@mtc.local', '{"username_or_phone": " client1 "}') then
    raise exception 'ÉCHEC : « client1 » entouré d''espaces s''inscrit à côté de « client1 »';
  end if;
  -- Réserver l'identifiant d'un autre.
  if not verif.inscription_refusee('pirate@mtc.local', '{"username_or_phone": "future-cliente"}') then
    raise exception 'ÉCHEC : on réserve l''identifiant d''un autre';
  end if;
  -- L'inscription normale, celle de l'app.
  if verif.inscription_refusee('nouvelle-cliente@mtc.local', '{"username_or_phone": "Nouvelle-Cliente"}') then
    raise exception 'ÉCHEC : une inscription normale est refusée';
  end if;
  if (select username_or_phone from public.profiles where lower(username_or_phone) = 'nouvelle-cliente') <> 'Nouvelle-Cliente' then
    raise exception 'ÉCHEC : l''identifiant n''est pas gardé tel que saisi';
  end if;
end $$;

-- La réinitialisation retrouve le bon compte, quelle que soit la casse.
do $$ begin
  if public.password_reset_account(' CLIENT1 ') <> '04060d99-e34d-520e-8b75-631ff4d3c10c' then
    raise exception 'ÉCHEC : la réinitialisation ne retrouve pas client1';
  end if;
end $$;

-- ---- 2. les noms réservés ---------------------------------------------------------------------------
do $$ begin
  if not verif.inscription_refusee('pirate-boutique@mtc.local',
       '{"username_or_phone": "pirate-boutique", "role": "supplier_tiers", "business_name": "MTC Officiel", "city": "Bamako", "legal_type": "individual"}') then
    raise exception 'ÉCHEC : une boutique s''inscrit sous le nom « MTC Officiel »';
  end if;
  if not verif.inscription_refusee('pirate-boutique2@mtc.local',
       '{"username_or_phone": "pirate-boutique2", "role": "supplier_tiers", "business_name": "M.T.C Shop", "city": "Bamako", "legal_type": "individual"}') then
    raise exception 'ÉCHEC : une boutique s''inscrit sous le nom « M.T.C Shop »';
  end if;
  if verif.inscription_refusee('boutique-awa@mtc.local',
       '{"username_or_phone": "boutique-awa", "role": "supplier_tiers", "business_name": "Boutique Awa", "city": "Bamako", "legal_type": "individual"}') then
    raise exception 'ÉCHEC : une boutique ordinaire ne s''inscrit plus';
  end if;
  if not verif.inscription_refusee('pirate-client@mtc.local',
       '{"username_or_phone": "pirate-client", "display_name": "Service client MTC"}') then
    raise exception 'ÉCHEC : un client s''inscrit sous le nom « Service client MTC »';
  end if;
  if not verif.inscription_refusee('pirate-livreur@mtc.local',
       '{"username_or_phone": "pirate-livreur", "role": "livreur", "display_name": "Livreur MTC"}') then
    raise exception 'ÉCHEC : un livreur s''inscrit sous le nom « Livreur MTC »';
  end if;
end $$;
-- Le staff, créé en deux temps comme par l'API d'administration :
-- l'insertion (le nom réservé n'est pas encore permis)…
insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data, raw_user_meta_data)
values ('dddddddd-0000-4000-8000-000000000144', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'agent2@mtc.local', '{}',
        '{"username_or_phone": "agent2", "display_name": "Agent MTC", "phone_number": "+22370000144"}');
-- …puis `app_metadata`, qui le fait staff, avant la validation.
update auth.users set raw_app_meta_data = '{"staff_role": "agent"}'
 where id = 'dddddddd-0000-4000-8000-000000000144';
set constraints all immediate;
set constraints all deferred;
do $$ begin
  if (select staff_role from public.profiles where id = 'dddddddd-0000-4000-8000-000000000144') is null then
    raise exception 'ÉCHEC : le compte « Agent MTC » n''est pas devenu staff';
  end if;
end $$;

-- Une boutique ne se renomme pas « MTC Officiel » ; un vrai renommage
-- descend sur ses produits.
set local role authenticated;
select verif.comme('b7eb8585-4091-5b6f-83f7-5d70724e97a3');
do $$ begin
  if not verif.refuse($q$update public.suppliers set business_name = 'MTC Officiel'
                       where id = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3'$q$) then
    raise exception 'ÉCHEC : une boutique se renomme « MTC Officiel »';
  end if;
  update public.suppliers set business_name = 'Bogolan de Bamako'
   where id = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3';
  if exists (select 1 from public.products
              where supplier_id = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3'
                and supplier_name <> 'Bogolan de Bamako') then
    raise exception 'ÉCHEC : les produits gardent l''ancien nom de la boutique';
  end if;
end $$;
reset role;

\o
select 'TOUTES LES VÉRIFICATIONS PASSENT' as resultat;
rollback;
