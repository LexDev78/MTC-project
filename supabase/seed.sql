-- MTC — données de démo (Lot 1).
--
-- Joué par `supabase db reset` seulement — jamais par `supabase db push` —,
-- juste après `seeds/test_helpers.sql` (voir `[db.seed]` dans
-- `config.toml`). Ce dernier crée les fonctions de test, que les migrations
-- n'installent plus depuis `0130` ; ce fichier-ci se contente de les
-- appeler.
--
-- Le contenu réel du jeu de démonstration vit dans
-- `public.test_reset_and_seed()`, pour rester la source unique de vérité :
-- le harnais de test (`test/support/supabase_test_harness.dart`) appelle la
-- même fonction entre les tests pour repartir d'un état propre.

select public.test_reset_and_seed();
-- Les comptes livreurs vivent dans leur propre helper, appelé juste après
-- le jeu principal.
select public.test_seed_couriers();
-- Adresses de retrait des fournisseurs : sans elles, aucune commande ne peut
-- être confiée à la livraison MTC (voir `0050`).
select public.test_seed_supplier_pickup_points();
