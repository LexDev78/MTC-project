-- Vérifie la migration 0123 contre la base locale, sans rien y laisser :
-- tout se passe dans une transaction annulée à la fin.
--
--   docker exec -i supabase_db_MTC_project psql -U postgres -d postgres -q \
--     < supabase/snippets/verif_0123.sql
--
-- Dernière ligne attendue : « TOUTES LES VÉRIFICATIONS PASSENT ».
--
-- S'appuie sur Bogolan Bamako (vérifiée, des produits actifs), Artisanat
-- Sikasso (en attente de vérification, des produits actifs) et Awa (client1).
--
-- Chaque nombre est lu par un client **et** par la boutique elle-même : pour
-- un client, les règles d'accès aux produits masquent déjà brouillons et
-- boutiques non vérifiées ; la boutique, elle, voit les siens. C'est sa
-- lecture qui prouve que la fonction filtre par elle-même.
\set ON_ERROR_STOP 1
\o /dev/null
begin;

select public.listed_product_count(s) as avant
  from public.suppliers s where s.id = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3' \gset

-- Un produit mis en pause sort du compte.
update public.products set status = 'paused'
 where id = (
   select id from public.products
    where supplier_id = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3' and status = 'active'
    order by name limit 1
 );

-- La boutique gonfle son compteur de travail elle-même : le nombre montré
-- aux clients n'en dépend pas.
set local role authenticated;
set local request.jwt.claims to '{"sub":"b7eb8585-4091-5b6f-83f7-5d70724e97a3","role":"authenticated"}';
update public.suppliers set product_count = 9999 where id = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3';

-- Lu par un client.
set local request.jwt.claims to '{"sub":"04060d99-e34d-520e-8b75-631ff4d3c10c","role":"authenticated"}';
select public.listed_product_count(s) as apres
  from public.suppliers s where s.id = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3' \gset
select public.listed_product_count(s) as en_attente
  from public.suppliers s where s.business_name = 'Artisanat Sikasso' \gset

-- Lu par chaque boutique, qui voit ses propres produits en pause.
set local request.jwt.claims to '{"sub":"b7eb8585-4091-5b6f-83f7-5d70724e97a3","role":"authenticated"}';
select public.listed_product_count(s) as apres_par_la_boutique
  from public.suppliers s where s.id = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3' \gset
set local request.jwt.claims to '{"sub":"b6b1daf0-1c8e-583f-939f-687991d429ca","role":"authenticated"}';
select public.listed_product_count(s) as en_attente_par_la_boutique
  from public.suppliers s where s.business_name = 'Artisanat Sikasso' \gset
reset role;

-- Le jeu d'essai tient-il encore ? Sans produit actif chez Artisanat
-- Sikasso, la ligne précédente ne prouverait rien.
select count(*) as actifs_en_attente
  from public.products p
  join public.suppliers s on s.id = p.supplier_id
 where s.business_name = 'Artisanat Sikasso' and p.status = 'active' \gset

rollback;
\o

select :apres = :avant - 1 and :apres_par_la_boutique = :avant - 1 as pause_ok,
       :en_attente = 0 and :en_attente_par_la_boutique = 0 as attente_ok,
       :actifs_en_attente > 0 as jeu_ok \gset
\if :jeu_ok
\else
\echo 'ÉCHEC : jeu d''essai — Artisanat Sikasso n''a plus de produit actif'
\quit
\endif
\if :pause_ok
\else
\echo 'ÉCHEC : produit en pause encore compté (avant' :avant ', client' :apres ', boutique' :apres_par_la_boutique ')'
\quit
\endif
\if :attente_ok
\else
\echo 'ÉCHEC : boutique en attente comptée (client' :en_attente ', boutique' :en_attente_par_la_boutique ')'
\quit
\endif
\echo 'TOUTES LES VÉRIFICATIONS PASSENT'
