-- Vérifie la migration 0134 (un avis public ne dit plus qui l'a écrit, ni
-- pour quelle commande) contre la base locale, sans rien y laisser : tout
-- se passe dans une transaction annulée.
--
--   docker exec -i supabase_db_MTC_project psql -U postgres -d postgres -q \
--     < supabase/snippets/verif_0134.sql
--
-- Dernière ligne attendue : « TOUTES LES VÉRIFICATIONS PASSENT ».
\set ON_ERROR_STOP 1
\o /dev/null
begin;
set local client_min_messages = warning;

create schema verif;
grant usage on schema verif to anon, authenticated;
create function verif.jeton(p_id uuid) returns text language sql as $$
  select jsonb_build_object('sub', p_id, 'role', 'authenticated',
    'app_metadata', (select raw_app_meta_data from auth.users where id = p_id))::text;
$$;
grant execute on all functions in schema verif to anon, authenticated;

\set bogolan 'b7eb8585-4091-5b6f-83f7-5d70724e97a3'
\set awa '04060d99-e34d-520e-8b75-631ff4d3c10c'
\set moussa '3355adef-385d-5eee-a565-815c8cf8e4d3'

-- Un avis d'Awa sur Bogolan, sur une commande livrée qu'on crée ici.
insert into public.orders (id, client_id, client_display_name_snapshot, status, total_fcfa, delivery_city)
values ('verif-cmd', :'awa', 'Awa Traoré', 'delivered', 10000, 'Bamako');
insert into public.order_supplier_groups (id, order_id, supplier_id, supplier_name, delivery_mode,
                                          delivery_fee_fcfa, subtotal_fcfa, status)
values ('verif-grp', 'verif-cmd', :'bogolan', 'Bogolan Bamako', 'self_delivery', 0, 10000, 'delivered');
insert into public.reviews (id, order_id, supplier_group_id, client_id, supplier_id, stars, comment,
                            client_display_name_snapshot)
values ('verif-avis', 'verif-cmd', 'verif-grp', :'awa', :'bogolan', 4, 'Bon tissu.', 'Awa Traoré');

select verif.jeton(:'awa') as awa_jeton \gset
select verif.jeton(:'moussa') as moussa_jeton \gset
select verif.jeton(:'bogolan') as patron \gset
select verif.jeton('2358888a-b13d-56f8-858b-a0c63831b512') as admin1 \gset
select set_config('verif.awa', :'awa_jeton', true), set_config('verif.moussa', :'moussa_jeton', true),
       set_config('verif.patron', :'patron', true), set_config('verif.admin1', :'admin1', true);

-- ---- 1. le public ne lit plus la table -------------------------------------------------
set local role anon;
set local request.jwt.claims to '{"role":"anon"}';
do $$
declare
  v jsonb := public.fetch_supplier_reviews('b7eb8585-4091-5b6f-83f7-5d70724e97a3', 50);
  v_avis jsonb;
begin
  if exists (select 1 from public.reviews) then
    raise exception 'ÉCHEC : un visiteur lit encore la table des avis';
  end if;
  select a into v_avis from jsonb_array_elements(v) a where a ->> 'id' = 'verif-avis';
  if v_avis is null or v_avis ->> 'comment' <> 'Bon tissu.' or (v_avis ->> 'stars')::int <> 4 then
    raise exception 'ÉCHEC : l''avis n''est pas sur la vitrine publique (%)', v;
  end if;
  if v_avis ?| array['client_id', 'order_id', 'supplier_group_id', 'supplier_id'] then
    raise exception 'ÉCHEC : la vitrine publique dit qui, ou quelle commande (%)', v_avis;
  end if;
end $$;

-- ---- 2. les parties, elles, lisent la ligne entière ---------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', current_setting('verif.awa'), true);
do $$ begin
  if (select order_id from public.reviews where id = 'verif-avis') <> 'verif-cmd' then
    raise exception 'ÉCHEC : l''auteure ne retrouve plus son avis';
  end if;
end $$;
select set_config('request.jwt.claims', current_setting('verif.patron'), true);
do $$ begin
  if not exists (select 1 from public.reviews where id = 'verif-avis' and client_id is not null) then
    raise exception 'ÉCHEC : la boutique ne lit plus les avis qu''elle doit gérer';
  end if;
end $$;
select set_config('request.jwt.claims', current_setting('verif.admin1'), true);
do $$ begin
  if not exists (select 1 from public.reviews where id = 'verif-avis') then
    raise exception 'ÉCHEC : le staff ne lit plus les avis';
  end if;
end $$;
-- Un autre client ne lit pas l'avis d'Awa, mais le voit sur la vitrine — et
-- peut toujours le commenter.
select set_config('request.jwt.claims', current_setting('verif.moussa'), true);
do $$ begin
  if exists (select 1 from public.reviews where id = 'verif-avis') then
    raise exception 'ÉCHEC : un autre client lit la ligne de l''avis';
  end if;
  insert into public.review_comments (id, review_id, body) values ('verif-com', 'verif-avis', 'Il déteint ?');
  if (select (a -> 'comments' -> 0 ->> 'body') from jsonb_array_elements(
        public.fetch_supplier_reviews('b7eb8585-4091-5b6f-83f7-5d70724e97a3', 50)) a
       where a ->> 'id' = 'verif-avis') <> 'Il déteint ?' then
    raise exception 'ÉCHEC : le commentaire ne s''affiche pas sous l''avis';
  end if;
end $$;
reset role;

-- ---- 3. une boutique supprimée n'a plus d'avis à montrer -------------------------------------
update public.suppliers set deleted_at = now() where id = :'bogolan';
set local role anon;
do $$ begin
  if public.fetch_supplier_reviews('b7eb8585-4091-5b6f-83f7-5d70724e97a3') <> '[]'::jsonb then
    raise exception 'ÉCHEC : les avis d''une boutique supprimée restent publics';
  end if;
end $$;
reset role;

\o
select 'TOUTES LES VÉRIFICATIONS PASSENT' as resultat;
rollback;
