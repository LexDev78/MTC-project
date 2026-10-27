-- Vérifie les migrations 0116 à 0119 contre la base locale, sans rien y
-- laisser : tout se passe dans une transaction annulée à la fin.
--
--   docker exec -i supabase_db_MTC_project psql -U postgres -d postgres -q \
--     < supabase/snippets/verif_0116_0119.sql
--
-- Dernière ligne attendue : « TOUTES LES VÉRIFICATIONS PASSENT ». Toute
-- autre issue s'arrête sur l'erreur qui dit ce qui manque.
--
-- S'appuie sur les comptes de démonstration (Awa, client1 ; Moussa,
-- client2 ; la boutique Bogolan Bamako) et sur deux parts livrées encore
-- sans avis (Alimentation Ségou pour Moussa, Bogolan Bamako pour Awa) : sur
-- une base où ces avis ont été laissés, la partie 0119 le signalera.
\set ON_ERROR_STOP 1
-- Vérification des migrations 0116 à 0119, dans une transaction annulée.
-- Awa (client1) 04060d99-e34d-520e-8b75-631ff4d3c10c
-- Moussa (client2) 3355adef-385d-5eee-a565-815c8cf8e4d3
begin;

-- ===================== 0116 : le nom =====================
set local role authenticated;
set local request.jwt.claims to '{"sub":"04060d99-e34d-520e-8b75-631ff4d3c10c","role":"authenticated"}';
do $$
declare v text;
begin
  v := public.set_my_display_name('  Awa   Traoré  Diallo ');
  if v <> 'Awa Traoré Diallo' then raise exception 'nom mal normalisé : %', v; end if;
  begin
    perform public.set_my_display_name('A');
    raise exception 'ÉCHEC : nom trop court accepté';
  exception when others then
    if sqlerrm not like '%au moins 2%' then raise exception 'refus court inattendu : %', sqlerrm; end if;
  end;
  begin
    perform public.set_my_display_name(repeat('x', 61));
    raise exception 'ÉCHEC : nom trop long accepté';
  exception when others then
    if sqlerrm not like '%60 caractères%' then raise exception 'refus long inattendu : %', sqlerrm; end if;
  end;
  -- L'écriture directe reste fermée.
  begin
    update public.profiles set display_name = 'Pirate' where id = auth.uid();
    raise exception 'ÉCHEC : écriture directe dans profiles permise';
  exception when others then
    if sqlerrm not like '%permission denied%' then raise exception 'refus direct inattendu : %', sqlerrm; end if;
  end;
end $$;
reset role;
do $$
begin
  if (select display_name from public.profiles where id = '04060d99-e34d-520e-8b75-631ff4d3c10c') <> 'Awa Traoré Diallo' then
    raise exception 'nom d''Awa non enregistré';
  end if;
  if (select display_name from public.profiles where id = '3355adef-385d-5eee-a565-815c8cf8e4d3') <> 'Moussa Diarra' then
    raise exception 'le nom d''un autre compte a changé';
  end if;
  if (select role::text from public.profiles where id = '04060d99-e34d-520e-8b75-631ff4d3c10c') <> 'client' then
    raise exception 'le rôle a changé';
  end if;
end $$;
set local role anon;
set local request.jwt.claims to '{"role":"anon"}';
do $$
begin
  perform public.set_my_display_name('Anonyme');
  raise exception 'ÉCHEC : anon a pu appeler set_my_display_name';
exception when others then
  if sqlerrm not like '%permission denied%' then raise exception 'refus anon inattendu : %', sqlerrm; end if;
end $$;
reset role;

-- ===================== 0117 : l'adresse par défaut =====================
insert into public.addresses (id, user_id, label, city, details, latitude, longitude) values
  ('t-adr-awa', '04060d99-e34d-520e-8b75-631ff4d3c10c', 'Test Awa', 'Bamako', 'Rue test', 12.6, -8.0),
  ('t-adr-moussa', '3355adef-385d-5eee-a565-815c8cf8e4d3', 'Test Moussa', 'Bamako', 'Rue test', 12.6, -8.0);
select default_address_id as avant_moussa from public.profiles where id = '3355adef-385d-5eee-a565-815c8cf8e4d3' \gset
set local role authenticated;
set local request.jwt.claims to '{"sub":"04060d99-e34d-520e-8b75-631ff4d3c10c","role":"authenticated"}';
do $$
declare v text;
begin
  v := public.set_my_default_address('t-adr-awa');
  if v <> 't-adr-awa' then raise exception 'retour inattendu : %', v; end if;
  begin
    perform public.set_my_default_address('t-adr-moussa');
    raise exception 'ÉCHEC : adresse d''un autre client acceptée';
  exception when others then
    if sqlerrm <> 'Adresse introuvable.' then raise exception 'refus inattendu (autre) : %', sqlerrm; end if;
  end;
  begin
    perform public.set_my_default_address('n-existe-pas');
    raise exception 'ÉCHEC : adresse inexistante acceptée';
  exception when others then
    if sqlerrm <> 'Adresse introuvable.' then raise exception 'refus inattendu (inexistante) : %', sqlerrm; end if;
  end;
end $$;
reset role;
do $$
begin
  if (select default_address_id from public.profiles where id = '04060d99-e34d-520e-8b75-631ff4d3c10c') is distinct from 't-adr-awa' then
    raise exception 'adresse par défaut d''Awa non enregistrée';
  end if;
end $$;
do $$
begin
  if (select default_address_id from public.profiles where id = '3355adef-385d-5eee-a565-815c8cf8e4d3') = 't-adr-awa' then
    raise exception 'le profil de Moussa a été touché';
  end if;
end $$;
-- Supprimer l'adresse choisie retire le choix.
delete from public.addresses where id = 't-adr-awa';
do $$
begin
  if (select default_address_id from public.profiles where id = '04060d99-e34d-520e-8b75-631ff4d3c10c') is not null then
    raise exception 'adresse supprimée encore désignée par défaut';
  end if;
end $$;
-- null retire le choix explicitement.
insert into public.addresses (id, user_id, label, city, details, latitude, longitude) values
  ('t-adr-awa-2', '04060d99-e34d-520e-8b75-631ff4d3c10c', 'Test 2', 'Bamako', 'Rue test', 12.6, -8.0);
set local role authenticated;
set local request.jwt.claims to '{"sub":"04060d99-e34d-520e-8b75-631ff4d3c10c","role":"authenticated"}';
select public.set_my_default_address('t-adr-awa-2');
select public.set_my_default_address(null);
reset role;
do $$
begin
  if (select default_address_id from public.profiles where id = '04060d99-e34d-520e-8b75-631ff4d3c10c') is not null then
    raise exception 'null n''a pas retiré le choix';
  end if;
end $$;

-- ===================== 0118 : les réglages de notification =====================
insert into public.notification_preferences (user_id) values ('3355adef-385d-5eee-a565-815c8cf8e4d3');
set local role authenticated;
set local request.jwt.claims to '{"sub":"04060d99-e34d-520e-8b75-631ff4d3c10c","role":"authenticated"}';
insert into public.notification_preferences (user_id, messages)
  values ('04060d99-e34d-520e-8b75-631ff4d3c10c', false);
insert into public.notification_preferences (user_id, messages, comments)
  values ('04060d99-e34d-520e-8b75-631ff4d3c10c', false, false)
  on conflict (user_id) do update
  set messages = excluded.messages, comments = excluded.comments;
do $$
begin
  if (select count(*) from public.notification_preferences) <> 1 then
    raise exception 'Awa voit les réglages d''un autre compte';
  end if;
  begin
    insert into public.notification_preferences (user_id) values ('b7eb8585-4091-5b6f-83f7-5d70724e97a3');
    raise exception 'ÉCHEC : ligne créée pour un autre compte';
  exception when others then
    if sqlerrm not like '%row-level security%' then raise exception 'refus inattendu : %', sqlerrm; end if;
  end;
  update public.notification_preferences set enabled = false
   where user_id = '3355adef-385d-5eee-a565-815c8cf8e4d3';
  begin
    delete from public.notification_preferences;
    raise exception 'ÉCHEC : suppression permise';
  exception when others then
    if sqlerrm not like '%permission denied%' then raise exception 'refus suppression inattendu : %', sqlerrm; end if;
  end;
end $$;
reset role;
do $$
begin
  if not (select enabled from public.notification_preferences where user_id = '3355adef-385d-5eee-a565-815c8cf8e4d3') then
    raise exception 'Awa a pu modifier les réglages de Moussa';
  end if;
end $$;
set local role anon;
set local request.jwt.claims to '{"role":"anon"}';
do $$
begin
  perform count(*) from public.notification_preferences;
  raise exception 'ÉCHEC : anon lit les réglages';
exception when others then
  if sqlerrm not like '%permission denied%' then raise exception 'refus anon inattendu : %', sqlerrm; end if;
end $$;
reset role;
do $$
declare avant integer; apres integer;
begin
  select count(*) into avant from public.notifications where user_id = '04060d99-e34d-520e-8b75-631ff4d3c10c';
  insert into public.notifications (id, user_id, type, title, body) values
    ('t-n1', '04060d99-e34d-520e-8b75-631ff4d3c10c', 'new_message', 't', 't'),
    ('t-n2', '04060d99-e34d-520e-8b75-631ff4d3c10c', 'new_comment', 't', 't'),
    ('t-n3', '04060d99-e34d-520e-8b75-631ff4d3c10c', 'order_status_update', 't', 't');
  select count(*) into apres from public.notifications where user_id = '04060d99-e34d-520e-8b75-631ff4d3c10c';
  if apres - avant <> 1 then raise exception 'filtrage : % notifications écrites au lieu de 1', apres - avant; end if;
  if not exists (select 1 from public.notifications where id = 't-n3') then
    raise exception 'le suivi de commande, resté permis, a été écarté';
  end if;
  update public.notification_preferences set enabled = false
   where user_id = '04060d99-e34d-520e-8b75-631ff4d3c10c';
  insert into public.notifications (id, user_id, type, title, body) values
    ('t-n4', '04060d99-e34d-520e-8b75-631ff4d3c10c', 'order_status_update', 't', 't');
  if exists (select 1 from public.notifications where id = 't-n4') then
    raise exception 'tout est coupé, et pourtant écrite';
  end if;
  -- Moussa (tout permis) et une boutique sans réglages ne sont pas touchés.
  insert into public.notifications (id, user_id, type, title, body) values
    ('t-n5', '3355adef-385d-5eee-a565-815c8cf8e4d3', 'new_message', 't', 't'),
    ('t-n6', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'new_order', 't', 't');
  if (select count(*) from public.notifications where id in ('t-n5', 't-n6')) <> 2 then
    raise exception 'les notifications d''autres comptes ont été écartées';
  end if;
end $$;

-- ===================== 0119 : le titre d'avis =====================
set local role authenticated;
set local request.jwt.claims to '{"sub":"3355adef-385d-5eee-a565-815c8cf8e4d3","role":"authenticated"}';
do $$
declare v text;
begin
  begin
    perform public.submit_review('f1db68f7-e2b3-5c0e-be0f-ed0098a40807', '04f30401-2cc9-5e3b-be84-16c5e7ecc81e',
      4, 'Bon riz', '{}', null, repeat('t', 101));
    raise exception 'ÉCHEC : titre trop long accepté';
  exception when others then
    if sqlerrm not like '%100 caractères%' then raise exception 'refus titre inattendu : %', sqlerrm; end if;
  end;
  v := public.submit_review('f1db68f7-e2b3-5c0e-be0f-ed0098a40807', '04f30401-2cc9-5e3b-be84-16c5e7ecc81e',
    4, 'Bon riz', '{}', null, '  Riz parfait  ');
  if (select title from public.reviews where id = v) is distinct from 'Riz parfait' then
    raise exception 'titre non enregistré';
  end if;
  if not exists (
    select 1 from jsonb_array_elements(public.fetch_product_reviews('d9d25e13-71ac-51c4-93f7-ed042a996500', 50, 0, 'recent')) e
     where e ->> 'title' = 'Riz parfait'
  ) then
    raise exception 'fetch_product_reviews ne rend pas le titre';
  end if;
end $$;
reset role;
do $$
begin
  if not exists (
    select 1 from public.notifications
     where type = 'new_review' and body = '4★ — Riz parfait'
  ) then
    raise exception 'la notification de la boutique ne reprend pas le titre';
  end if;
end $$;
-- Sans titre, appel à l'ancienne (six paramètres), puis titre blanc.
set local role authenticated;
set local request.jwt.claims to '{"sub":"04060d99-e34d-520e-8b75-631ff4d3c10c","role":"authenticated"}';
do $$
declare v text;
begin
  v := public.submit_review('222a8eb1-59d2-57e4-a57e-7cc382ca72f1', 'efbd44fe-a725-533d-ba6c-a9c867b161cb',
    5, 'Tissu superbe', '{}', null);
  if (select title from public.reviews where id = v) is not null then
    raise exception 'un avis sans titre a un titre';
  end if;
end $$;
reset role;
delete from public.reviews where supplier_group_id = 'efbd44fe-a725-533d-ba6c-a9c867b161cb';
set local role authenticated;
set local request.jwt.claims to '{"sub":"04060d99-e34d-520e-8b75-631ff4d3c10c","role":"authenticated"}';
do $$
declare v text;
begin
  v := public.submit_review('222a8eb1-59d2-57e4-a57e-7cc382ca72f1', 'efbd44fe-a725-533d-ba6c-a9c867b161cb',
    5, 'Tissu superbe', '{}', null, '   ');
  if (select title from public.reviews where id = v) is not null then
    raise exception 'un titre blanc a été enregistré';
  end if;
end $$;
reset role;

select 'TOUTES LES VÉRIFICATIONS PASSENT' as resultat;
rollback;
