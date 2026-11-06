-- Vérifie 0136 et 0137 (avis forgés, colonnes de confiance d'un produit)
-- contre une base où elles sont appliquées, sans rien y laisser : tout se
-- passe dans une transaction annulée.
--
--   docker exec -i supabase_db_mtc_verif psql -U postgres -d postgres -q \
--     < supabase/snippets/verif_0136_0137.sql
--
-- Dernière ligne attendue : « TOUTES LES VÉRIFICATIONS PASSENT ».
\set ON_ERROR_STOP 1
\o /dev/null
begin;
set local client_min_messages = warning;

create schema verif;
grant usage on schema verif to anon, authenticated;
create function verif.jeton(p_id uuid) returns text language sql security definer as $$
  select jsonb_build_object('sub', p_id, 'role', 'authenticated', 'aal', 'aal1',
    'app_metadata', (select raw_app_meta_data from auth.users where id = p_id))::text;
$$;
create function verif.comme(p_id uuid) returns void language sql as $$
  select set_config('request.jwt.claims', verif.jeton(p_id), true);
$$;
grant execute on all functions in schema verif to anon, authenticated;

-- fournisseur1 (Bogolan, vérifiée, 4,6★/132), fournisseur2 (Artisanat
-- Sikasso, dossier en attente), fournisseur8 (Tissus Mopti), client1.
\set bogolan 'b7eb8585-4091-5b6f-83f7-5d70724e97a3'
\set sikasso 'b6b1daf0-1c8e-583f-939f-687991d429ca'
\set mopti 'b8e6fcc1-ef1c-5248-8ffa-5de27e9beebb'
\set awa '04060d99-e34d-520e-8b75-631ff4d3c10c'
\set admin1 '2358888a-b13d-56f8-858b-a0c63831b512'
select set_config('verif.bogolan', :'bogolan', true), set_config('verif.sikasso', :'sikasso', true),
       set_config('verif.mopti', :'mopti', true), set_config('verif.awa', :'awa', true),
       set_config('verif.admin1', :'admin1', true);

-- ---- 1. faille 1 : un client n'écrit plus d'avis directement ----------------------------
set local role authenticated;
select verif.comme(:'awa');
do $$
declare
  v_commande text;
  v_groupe text;
begin
  -- Une commande livrée d'Awa, n'importe laquelle, comme dans l'audit.
  select g.order_id, g.id into v_commande, v_groupe
    from public.order_supplier_groups g join public.orders o on o.id = g.order_id
   where o.client_id = auth.uid() and g.status = 'delivered' limit 1;
  if v_commande is null then
    raise exception 'ÉCHEC du décor : Awa n''a pas de commande livrée';
  end if;
  begin
    -- L'attaque de l'audit : le même groupe livré, une AUTRE commande à
    -- chaque fois (la policy comparait `g.order_id` à lui-même), et la
    -- boutique de son choix.
    insert into public.reviews (id, order_id, supplier_group_id, client_id, supplier_id,
                                stars, comment, client_display_name_snapshot)
    select 'verif-forge-' || o.id, o.id, v_groupe, auth.uid(),
           current_setting('verif.mopti')::uuid, 1, 'arnaque', 'Awa'
      from public.orders o where o.id <> v_commande limit 1;
    raise exception 'ÉCHEC : un client insère encore un avis sur une boutique de son choix';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- ---- 2. faille 2 : le produit forgé de l'audit ---------------------------------------------
set local role authenticated;
select verif.comme(:'sikasso');
insert into public.products (id, supplier_id, supplier_name, supplier_type, name, description,
                             category, price_fcfa, stock_quantity, city, weight_kg, status,
                             is_supplier_verified, rating_average, rating_count, view_count,
                             has_variants, variant_count, max_price_fcfa, created_at)
select 'verif-forge', :'sikasso', 'MTC Officiel', 'principal', 'Panier', 'Un panier.',
       category, 1000, 5, 'Sikasso', 1, 'draft',
       true, 5, 999, 99999, true, 50, 1, '2030-01-01'
  from public.products limit 1;
do $$
declare
  p public.products;
begin
  select * into p from public.products where id = 'verif-forge';
  if p.is_supplier_verified then
    raise exception 'ÉCHEC : une boutique en attente se déclare vérifiée';
  end if;
  if p.supplier_name <> 'Artisanat Sikasso' or p.supplier_type <> 'tiers' then
    raise exception 'ÉCHEC : le produit est signé % (%)', p.supplier_name, p.supplier_type;
  end if;
  if p.rating_average <> 0 or p.rating_count <> 0 then
    raise exception 'ÉCHEC : le produit naît noté %★ sur % avis', p.rating_average, p.rating_count;
  end if;
  if p.view_count <> 0 or p.has_variants or p.variant_count <> 0 or p.max_price_fcfa is not null then
    raise exception 'ÉCHEC : compteurs forgés acceptés (vues %, variantes %/%)',
      p.view_count, p.has_variants, p.variant_count;
  end if;
  if p.created_at > now() + interval '1 minute' then
    raise exception 'ÉCHEC : date de création forgée acceptée (%)', p.created_at;
  end if;

  -- La modification ne fait pas mieux.
  update public.products
     set is_supplier_verified = true, supplier_name = 'MTC Officiel', view_count = 5000,
         created_at = '2030-01-01', has_variants = true, variant_count = 9
   where id = 'verif-forge';
  select * into p from public.products where id = 'verif-forge';
  if p.is_supplier_verified or p.supplier_name <> 'Artisanat Sikasso' or p.view_count <> 0
     or p.created_at > now() + interval '1 minute' or p.has_variants or p.variant_count <> 0 then
    raise exception 'ÉCHEC : la modification fait passer des colonnes de confiance';
  end if;

  begin
    update public.products set id = 'verif-forge-2' where id = 'verif-forge';
    raise exception 'ÉCHEC : l''identifiant d''un produit change';
  exception when raise_exception then
    if sqlerrm like 'ÉCHEC%' then raise; end if;
  end;
end $$;

-- Le public ne le voit pas.
reset role;
set local role anon;
set local request.jwt.claims to '{"role":"anon"}';
do $$ begin
  if exists (select 1 from public.products where id = 'verif-forge') then
    raise exception 'ÉCHEC : le produit d''une boutique non vérifiée est public';
  end if;
end $$;
reset role;

-- ---- 3. les gestes légitimes passent ---------------------------------------------------
-- Une boutique vérifiée crée un produit : vérifié, et noté comme elle.
set local role authenticated;
select verif.comme(:'bogolan');
insert into public.products (id, supplier_id, supplier_name, supplier_type, name, description,
                             category, price_fcfa, stock_quantity, city, weight_kg, status,
                             is_supplier_verified)
select 'verif-legit', :'bogolan', 'Bogolan Bamako', 'tiers', 'Pagne', 'Un pagne.',
       category, 5000, 3, 'Bamako', 1, 'draft', false
  from public.products limit 1;
do $$
declare
  p public.products;
  s record;
begin
  select * into p from public.products where id = 'verif-legit';
  -- Pas de `select *` : l'adresse de la boutique n'est plus lisible (`0133`).
  select rating_average, rating_count into s
    from public.suppliers where id = current_setting('verif.bogolan')::uuid;
  if not p.is_supplier_verified then
    raise exception 'ÉCHEC : le produit d''une boutique vérifiée naît non vérifié';
  end if;
  if p.rating_average <> s.rating_average or p.rating_count <> s.rating_count then
    raise exception 'ÉCHEC : le produit ne porte pas la note de sa boutique (% / %)',
      p.rating_average, s.rating_average;
  end if;

  -- Sa première variante : les agrégats suivent (déclencheur de la base).
  insert into public.product_variants (id, product_id, name, price_fcfa, stock_quantity, is_default)
  values ('verif-var', 'verif-legit', 'Unique', 6000, 4, true);
  select * into p from public.products where id = 'verif-legit';
  if not p.has_variants or p.variant_count <> 1 or p.max_price_fcfa <> 6000 or p.stock_quantity <> 4 then
    raise exception 'ÉCHEC : les agrégats des variantes ne suivent plus';
  end if;

  -- Une modification ordinaire passe.
  update public.products set name = 'Pagne indigo', status = 'active' where id = 'verif-legit';
  if (select name from public.products where id = 'verif-legit') <> 'Pagne indigo' then
    raise exception 'ÉCHEC : la boutique ne modifie plus son produit';
  end if;

end $$;

-- Deux clients qui regardent le produit font monter le compteur (une vue
-- par personne et par jour : la seconde visite d'Awa ne compte pas).
select verif.comme(:'awa');
select public.increment_product_view('verif-legit');
select public.increment_product_view('verif-legit');
select verif.comme('3355adef-385d-5eee-a565-815c8cf8e4d3');
select public.increment_product_view('verif-legit');
reset role;
do $$ begin
  if (select view_count from public.products where id = 'verif-legit') <> 2 then
    raise exception 'ÉCHEC : le compteur de vues ne compte plus (%)',
      (select view_count from public.products where id = 'verif-legit');
  end if;
end $$;

-- Le staff retire la vérification d'une boutique : ses produits suivent.
set local role authenticated;
select verif.comme(:'admin1');
select public.set_products_supplier_verification(:'bogolan', false);
reset role;
do $$ begin
  if (select is_supplier_verified from public.products where id = 'verif-legit') then
    raise exception 'ÉCHEC : la décision du staff ne descend plus sur les produits';
  end if;
end $$;

-- Le défaut ne rend plus public.
do $$ begin
  if (select column_default from information_schema.columns
       where table_schema = 'public' and table_name = 'products'
         and column_name = 'is_supplier_verified') <> 'false' then
    raise exception 'ÉCHEC : is_supplier_verified est encore vrai par défaut';
  end if;
end $$;

\o
select 'TOUTES LES VÉRIFICATIONS PASSENT' as resultat;
rollback;
