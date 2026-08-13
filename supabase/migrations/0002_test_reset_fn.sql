-- RPC locale-only : tronque toutes les tables applicatives puis rejoue le
-- jeu de données de démo. Source unique de vérité pour le seed — le
-- `supabase/seed.sql` exécuté par `supabase db reset` se contente
-- d'appeler cette fonction, et le harnais de test (Lot 3,
-- `test/support/supabase_test_harness.dart`) l'appellera directement via
-- `supabase.rpc('test_reset_and_seed')` entre les tests pour repartir d'un
-- état propre sans repasser par le CLI.
--
-- `security definer` : les inserts dans `auth.users`/`auth.identities`
-- exigent les privilèges du propriétaire de la fonction (`postgres` en
-- local), pas ceux de l'appelant.
create or replace function public.test_reset_and_seed()
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  -- Un seul TRUNCATE ... CASCADE suffit : chaque autre table applicative
  -- référence (directement ou transitivement) `auth.users` ou `suppliers`,
  -- sauf `pickup_points`/`notifications` (aucune FK entrante), listées ici
  -- explicitement.
  truncate table auth.users, public.suppliers, public.pickup_points, public.notifications cascade;

  -- ------------------------------------------------------------------------
  -- 1. Comptes (auth.users + auth.identities -> handle_new_user() en cascade)
  -- ------------------------------------------------------------------------
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token, email_change, email_change_token_new
  ) values
    (
      '00000000-0000-0000-0000-000000000000',
      '04060d99-e34d-520e-8b75-631ff4d3c10c', 'authenticated', 'authenticated',
      'client1@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"client","username_or_phone":"client1","display_name":"Awa Traoré","phone_number":"+22370000001"}',
      '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      '3355adef-385d-5eee-a565-815c8cf8e4d3', 'authenticated', 'authenticated',
      'client2@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"client","username_or_phone":"client2","display_name":"Moussa Diarra","phone_number":"+22370000002"}',
      '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'authenticated', 'authenticated',
      'fournisseur1@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"supplier_tiers","username_or_phone":"fournisseur1","display_name":"Ibrahima Coulibaly","phone_number":"+22376000001","business_name":"Bogolan Bamako","city":"Bamako","legal_type":"company"}',
      '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      'b6b1daf0-1c8e-583f-939f-687991d429ca', 'authenticated', 'authenticated',
      'fournisseur2@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"supplier_tiers","username_or_phone":"fournisseur2","display_name":"Fatoumata Keita","phone_number":"+22376000002","business_name":"Artisanat Sikasso","city":"Sikasso","legal_type":"company"}',
      '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      'bc82e68c-b1d9-538a-a8ed-8393a5ba739f', 'authenticated', 'authenticated',
      'fournisseur3@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"supplier_tiers","username_or_phone":"fournisseur3","display_name":"Aïssata Sangaré","phone_number":"+22376000003","business_name":"Couture Kayes","city":"Kayes","legal_type":"individual"}',
      '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      'deb94bf5-bddb-5399-8010-3b0264c98f1a', 'authenticated', 'authenticated',
      'fournisseur4@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"supplier_tiers","username_or_phone":"fournisseur4","display_name":"Seydou Traoré","phone_number":"+22376000004","business_name":"Fruits Niono","city":"Niono","legal_type":"company"}',
      '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      '0354c601-5e09-57b6-a23c-affaa5acf0d0', 'authenticated', 'authenticated',
      'agent1@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"supplier_principal","username_or_phone":"agent1","display_name":"Agent MTC","phone_number":"+22378000001","staff_role":"agent"}',
      '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      '2358888a-b13d-56f8-858b-a0c63831b512', 'authenticated', 'authenticated',
      'admin1@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"supplier_principal","username_or_phone":"admin1","display_name":"Admin MTC","phone_number":"+22378000002","staff_role":"admin"}',
      '', '', '', ''
    ),
    -- fournisseur5-8 : les 4 fournisseurs tiers "de remplissage" du
    -- catalogue (multi-fournisseur), sans dossier KYC dans la narration —
    -- mais Lot 5+ a besoin de vraies sessions pour eux aussi (vue commande
    -- côté fournisseur, chat, avis...), donc ils passent par le même
    -- trigger `handle_new_user()` que fournisseur1-4 plutôt que d'être
    -- insérés directement dans `suppliers` (voir section 2 plus bas).
    (
      '00000000-0000-0000-0000-000000000000',
      'dbff9b88-4829-5eed-b15a-78c33431553f', 'authenticated', 'authenticated',
      'fournisseur5@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"supplier_tiers","username_or_phone":"fournisseur5","display_name":"Oumar Diallo","phone_number":"+22376000005","business_name":"Electro Bamako","city":"Bamako","legal_type":"company"}',
      '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      '2c66294c-e1d7-59f1-925c-5ab6703827f3', 'authenticated', 'authenticated',
      'fournisseur6@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"supplier_tiers","username_or_phone":"fournisseur6","display_name":"Mariam Coulibaly","phone_number":"+22376000006","business_name":"Alimentation Ségou","city":"Ségou","legal_type":"company"}',
      '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      '01e2be08-764b-5ea6-8a32-a1b5152497b1', 'authenticated', 'authenticated',
      'fournisseur7@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"supplier_tiers","username_or_phone":"fournisseur7","display_name":"Sekou Traoré","phone_number":"+22376000007","business_name":"Matériaux Koutiala","city":"Koutiala","legal_type":"company"}',
      '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      'b8e6fcc1-ef1c-5248-8ffa-5de27e9beebb', 'authenticated', 'authenticated',
      'fournisseur8@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"supplier_tiers","username_or_phone":"fournisseur8","display_name":"Aminata Konaté","phone_number":"+22376000008","business_name":"Tissus Mopti","city":"Mopti","legal_type":"company"}',
      '', '', '', ''
    );

  insert into auth.identities (
    id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  )
  select
    gen_random_uuid(), u.id::text, u.id,
    jsonb_build_object('sub', u.id::text, 'email', u.email),
    'email', now(), now(), now()
  from auth.users u
  where u.id in (
    '04060d99-e34d-520e-8b75-631ff4d3c10c', '3355adef-385d-5eee-a565-815c8cf8e4d3',
    'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'b6b1daf0-1c8e-583f-939f-687991d429ca',
    'bc82e68c-b1d9-538a-a8ed-8393a5ba739f', 'deb94bf5-bddb-5399-8010-3b0264c98f1a',
    '0354c601-5e09-57b6-a23c-affaa5acf0d0', '2358888a-b13d-56f8-858b-a0c63831b512',
    'dbff9b88-4829-5eed-b15a-78c33431553f', '2c66294c-e1d7-59f1-925c-5ab6703827f3',
    '01e2be08-764b-5ea6-8a32-a1b5152497b1', 'b8e6fcc1-ef1c-5248-8ffa-5de27e9beebb'
  );

  -- ------------------------------------------------------------------------
  -- 2. suppliers — complète les 9 fournisseurs
  -- ------------------------------------------------------------------------
  update public.suppliers set
    rating_average = 4.6, rating_count = 132, product_count = 4, verification_status = 'verified'
    where id = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3';

  update public.suppliers set
    rating_average = 0, rating_count = 0, product_count = 3, verification_status = 'pending'
    where id = 'b6b1daf0-1c8e-583f-939f-687991d429ca';

  update public.suppliers set
    rating_average = 0, rating_count = 0, product_count = 0, verification_status = 'unverified'
    where id = 'bc82e68c-b1d9-538a-a8ed-8393a5ba739f';

  update public.suppliers set
    rating_average = 0, rating_count = 0, product_count = 0, verification_status = 'rejected'
    where id = 'deb94bf5-bddb-5399-8010-3b0264c98f1a';

  -- fournisseur5-8 (Electro Bamako, Alimentation Ségou, Matériaux Koutiala,
  -- Tissus Mopti) : `suppliers` déjà créé par `handle_new_user()` ci-dessus
  -- (section 1) — complète juste les stats, comme pour fournisseur1-4.
  update public.suppliers set
    rating_average = 4.2, rating_count = 54, product_count = 4, verification_status = 'verified'
    where id = 'dbff9b88-4829-5eed-b15a-78c33431553f';

  update public.suppliers set
    rating_average = 4.8, rating_count = 210, product_count = 4, verification_status = 'verified'
    where id = '2c66294c-e1d7-59f1-925c-5ab6703827f3';

  update public.suppliers set
    rating_average = 3.9, rating_count = 41, product_count = 3, verification_status = 'verified'
    where id = '01e2be08-764b-5ea6-8a32-a1b5152497b1';

  update public.suppliers set
    rating_average = 4.4, rating_count = 76, product_count = 3, verification_status = 'verified'
    where id = 'b8e6fcc1-ef1c-5248-8ffa-5de27e9beebb';

  insert into public.suppliers (id, business_name, supplier_type, city, rating_average, rating_count, product_count) values
    ('3331cbb4-0a65-5f94-9812-fe4270e50fe2', 'MTC Officiel', 'principal', 'Bamako', 4.9, 340, 4);

  -- ------------------------------------------------------------------------
  -- 3. products (25)
  -- ------------------------------------------------------------------------
  insert into public.products (
    id, supplier_id, supplier_name, supplier_type, name, description, category,
    price_fcfa, stock_quantity, image_urls, city, rating_average, rating_count,
    allows_self_delivery, allows_mtc_delivery, weight_kg, is_supplier_verified,
    sizes, colors, region
  ) values
    ('product-001', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'Bogolan Bamako', 'tiers',
     'Tissu Bogolan traditionnel', 'Tissu bogolan teint et peint à la main selon la tradition malienne, 2m x 1,5m.',
     'textiles_bogolan', 25000, 40,
     array['assets/images/products/textiles/fabric.jpg','assets/images/products/textiles/fabric_2.jpg'],
     'Bamako', 4.6, 132, true, true, 0.6, true, '{}', array['Marron','Ocre','Noir','Beige'], 'mali'),

    ('product-002', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'Bogolan Bamako', 'tiers',
     'Boubou en bogolan brodé', 'Boubou homme brodé main, tissu bogolan 100% coton, plusieurs tailles disponibles.',
     'textiles_bogolan', 45000, 15,
     array['assets/images/products/textiles/fabric.jpg','assets/images/products/textiles/fabric_2.jpg'],
     'Bamako', 4.6, 132, true, true, 0.8, true, array['S','M','L','XL'], array['Marron','Noir','Ocre'], 'mali'),

    ('product-003', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'Bogolan Bamako', 'tiers',
     'Sac en bogolan', 'Sac à main artisanal en tissu bogolan doublé, fermeture éclair.',
     'textiles_bogolan', 15000, 60,
     array['assets/images/products/artisanat/basket.jpg','assets/images/products/artisanat/basket_2.jpg'],
     'Bamako', 4.6, 132, true, false, 0.5, true, '{}', array['Marron','Noir'], 'mali'),

    ('product-004', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'Bogolan Bamako', 'tiers',
     'Masque décoratif Bambara', 'Masque décoratif en bois sculpté, style Bambara, pièce unique.',
     'artisanat', 20000, 20,
     array['assets/images/products/artisanat/mask.jpg'],
     'Bamako', 4.6, 132, true, true, 1.5, true, '{}', '{}', 'mali'),

    ('product-005', 'b8e6fcc1-ef1c-5248-8ffa-5de27e9beebb', 'Tissus Mopti', 'tiers',
     'Pagne Wax 6 yards', 'Pagne wax haute qualité, 6 yards, motifs colorés.',
     'textiles_bogolan', 18000, 80,
     array['assets/images/products/textiles/fabric.jpg','assets/images/products/textiles/fabric_2.jpg'],
     'Mopti', 4.4, 76, true, true, 0.9, true, '{}', array['Rouge','Bleu','Jaune','Vert'], 'mali'),

    ('product-006', 'b8e6fcc1-ef1c-5248-8ffa-5de27e9beebb', 'Tissus Mopti', 'tiers',
     'Foulard traditionnel', 'Foulard en coton local, teinture artisanale.',
     'textiles_bogolan', 8000, 100,
     array['assets/images/products/textiles/fabric.jpg','assets/images/products/textiles/fabric_2.jpg'],
     'Mopti', 4.4, 76, true, true, 0.2, true, '{}', array['Rouge','Bleu','Blanc'], 'mali'),

    ('product-007', 'b8e6fcc1-ef1c-5248-8ffa-5de27e9beebb', 'Tissus Mopti', 'tiers',
     'Nappe brodée', 'Nappe de table brodée main, 8 personnes.',
     'textiles_bogolan', 22000, 25,
     array['assets/images/products/textiles/fabric.jpg','assets/images/products/textiles/fabric_2.jpg'],
     'Mopti', 4.4, 76, true, true, 0.7, true, '{}', array['Blanc','Beige'], 'mali'),

    ('product-008', 'b6b1daf0-1c8e-583f-939f-687991d429ca', 'Artisanat Sikasso', 'tiers',
     'Masque en bois sculpté', 'Masque cérémoniel en bois local sculpté à la main.',
     'artisanat', 35000, 12,
     array['assets/images/products/artisanat/mask.jpg'],
     'Sikasso', 0, 0, true, true, 2.0, false, '{}', '{}', 'mali'),

    ('product-009', 'b6b1daf0-1c8e-583f-939f-687991d429ca', 'Artisanat Sikasso', 'tiers',
     'Statuette Bambara', 'Statuette en bois dur, finition huilée.',
     'artisanat', 28000, 8,
     array['assets/images/products/artisanat/mask.jpg'],
     'Sikasso', 0, 0, true, true, 3.0, false, '{}', '{}', 'mali'),

    ('product-010', 'b6b1daf0-1c8e-583f-939f-687991d429ca', 'Artisanat Sikasso', 'tiers',
     'Panier tressé', 'Panier tressé à la main en fibres naturelles.',
     'artisanat', 6000, 50,
     array['assets/images/products/artisanat/basket.jpg','assets/images/products/artisanat/basket_2.jpg'],
     'Sikasso', 0, 0, true, true, 0.8, false, '{}', '{}', 'mali'),

    ('product-011', 'dbff9b88-4829-5eed-b15a-78c33431553f', 'Electro Bamako', 'tiers',
     'Smartphone Android 64GB', 'Smartphone double SIM, 64GB, écran 6,5", garantie 12 mois.',
     'electronique', 85000, 30,
     array['assets/images/products/electronique/smartphone.jpg','assets/images/products/electronique/smartphone_2.jpg'],
     'Bamako', 4.2, 54, true, true, 0.3, true, array['64 Go','128 Go'], array['Noir','Bleu','Or'], 'chine'),

    ('product-012', 'dbff9b88-4829-5eed-b15a-78c33431553f', 'Electro Bamako', 'tiers',
     'Chargeur solaire portable', 'Panneau solaire pliable 20W avec batterie intégrée.',
     'electronique', 12000, 70,
     array['assets/images/products/electronique/solar_panel.jpg','assets/images/products/electronique/solar_panel_2.jpg'],
     'Bamako', 4.2, 54, true, true, 1.0, true, array['20W','40W'], array['Noir'], 'chine'),

    ('product-013', 'dbff9b88-4829-5eed-b15a-78c33431553f', 'Electro Bamako', 'tiers',
     'Radio FM à piles', 'Radio portable FM/AM, fonctionne à piles ou secteur.',
     'electronique', 9500, 45,
     array['assets/images/products/electronique/radio.jpg','assets/images/products/electronique/radio_2.jpg'],
     'Bamako', 4.2, 54, true, false, 0.7, true, '{}', array['Noir','Gris'], 'chine'),

    ('product-014', 'dbff9b88-4829-5eed-b15a-78c33431553f', 'Electro Bamako', 'tiers',
     'Enceinte Bluetooth', 'Enceinte portable Bluetooth 10W, autonomie 8h.',
     'electronique', 18000, 35,
     array['assets/images/products/electronique/speaker.jpg','assets/images/products/electronique/speaker_2.jpg'],
     'Bamako', 4.2, 54, true, true, 0.9, true, '{}', array['Noir','Rouge','Bleu'], 'chine'),

    ('product-015', '2c66294c-e1d7-59f1-925c-5ab6703827f3', 'Alimentation Ségou', 'tiers',
     'Riz local 25kg', 'Riz malien de qualité supérieure, sac de 25kg.',
     'alimentation', 12500, 200,
     array['assets/images/products/alimentation/rice.jpg','assets/images/products/alimentation/rice_2.jpg'],
     'Ségou', 4.8, 210, true, true, 25.0, true, '{}', '{}', 'mali'),

    ('product-016', '2c66294c-e1d7-59f1-925c-5ab6703827f3', 'Alimentation Ségou', 'tiers',
     'Mil (sac 50kg)', 'Mil local, sac de 50kg, récolte récente.',
     'alimentation', 18000, 150,
     array['assets/images/products/alimentation/millet.jpg','assets/images/products/alimentation/millet_2.jpg'],
     'Ségou', 4.8, 210, true, true, 50.0, true, '{}', '{}', 'mali'),

    ('product-017', '2c66294c-e1d7-59f1-925c-5ab6703827f3', 'Alimentation Ségou', 'tiers',
     'Huile d''arachide 5L', 'Huile d''arachide pure, pressée à froid, bidon de 5 litres.',
     'alimentation', 7500, 90,
     array['assets/images/products/alimentation/oil.jpg','assets/images/products/alimentation/oil_2.jpg'],
     'Ségou', 4.8, 210, true, true, 4.6, true, '{}', '{}', 'mali'),

    ('product-018', '2c66294c-e1d7-59f1-925c-5ab6703827f3', 'Alimentation Ségou', 'tiers',
     'Miel pur de brousse 1L', 'Miel artisanal récolté en brousse, pot de 1 litre.',
     'alimentation', 6000, 60,
     array['assets/images/products/alimentation/honey.jpg','assets/images/products/alimentation/honey_2.jpg'],
     'Ségou', 4.8, 210, true, true, 1.3, true, '{}', '{}', 'mali'),

    ('product-019', '01e2be08-764b-5ea6-8a32-a1b5152497b1', 'Matériaux Koutiala', 'tiers',
     'Ciment (sac 50kg)', 'Ciment CPJ 32,5, sac de 50kg.',
     'materiaux_construction', 5000, 500,
     array['assets/images/products/materiaux/cement.jpg'],
     'Koutiala', 3.9, 41, true, true, 50.0, true, '{}', '{}', 'afrique_hors_mali'),

    ('product-020', '01e2be08-764b-5ea6-8a32-a1b5152497b1', 'Matériaux Koutiala', 'tiers',
     'Tôles ondulées (unité)', 'Tôle galvanisée ondulée, 2m, épaisseur 0,4mm.',
     'materiaux_construction', 8500, 120,
     array['assets/images/products/materiaux/corrugated_sheets.jpg','assets/images/products/materiaux/corrugated_sheets_2.jpg'],
     'Koutiala', 3.9, 41, true, true, 6.0, true, '{}', '{}', 'afrique_hors_mali'),

    ('product-021', '01e2be08-764b-5ea6-8a32-a1b5152497b1', 'Matériaux Koutiala', 'tiers',
     'Fer à béton 12mm (barre)', 'Barre de fer à béton torsadé, diamètre 12mm, 6m.',
     'materiaux_construction', 6500, 300,
     array['assets/images/products/materiaux/steel.jpg','assets/images/products/materiaux/steel_2.jpg'],
     'Koutiala', 3.9, 41, true, false, 5.3, true, '{}', '{}', 'afrique_hors_mali'),

    ('product-022', '3331cbb4-0a65-5f94-9812-fe4270e50fe2', 'MTC Officiel', 'principal',
     'Kit solaire MTC 100W', 'Kit solaire complet 100W avec batterie et régulateur, garantie MTC 24 mois.',
     'electronique', 95000, 25,
     array['assets/images/products/electronique/solar_panel.jpg','assets/images/products/electronique/solar_panel_2.jpg'],
     'Bamako', 4.9, 340, true, false, 8.0, true, array['100W','200W'], array['Noir'], 'europe'),

    ('product-023', '3331cbb4-0a65-5f94-9812-fe4270e50fe2', 'MTC Officiel', 'principal',
     'Sac de riz MTC Premium 25kg', 'Riz premium sélectionné et conditionné par MTC, sac de 25kg.',
     'alimentation', 14000, 100,
     array['assets/images/products/alimentation/rice.jpg','assets/images/products/alimentation/rice_2.jpg'],
     'Bamako', 4.9, 340, true, false, 25.0, true, '{}', '{}', 'mali'),

    ('product-024', '3331cbb4-0a65-5f94-9812-fe4270e50fe2', 'MTC Officiel', 'principal',
     'Pagne MTC édition limitée', 'Pagne exclusif MTC, édition limitée, tissage haut de gamme.',
     'textiles_bogolan', 30000, 40,
     array['assets/images/products/textiles/fabric.jpg','assets/images/products/textiles/fabric_2.jpg'],
     'Bamako', 4.9, 340, true, false, 0.9, true, '{}', array['Bleu','Vert','Or'], 'mali'),

    ('product-025', '3331cbb4-0a65-5f94-9812-fe4270e50fe2', 'MTC Officiel', 'principal',
     'Ciment MTC Pro (sac 50kg)', 'Ciment haute résistance distribué par MTC, sac de 50kg.',
     'materiaux_construction', 5200, 400,
     array['assets/images/products/materiaux/cement.jpg'],
     'Bamako', 4.9, 340, true, false, 50.0, true, '{}', '{}', 'mali');

  -- ------------------------------------------------------------------------
  -- 4. cart_items (2) / favorites (1)
  -- ------------------------------------------------------------------------
  insert into public.cart_items (id, user_id, product_id, supplier_id, product_name_snapshot, unit_price_fcfa_snapshot, quantity) values
    (gen_random_uuid()::text, '3355adef-385d-5eee-a565-815c8cf8e4d3', 'product-015', '2c66294c-e1d7-59f1-925c-5ab6703827f3', 'Riz local 25kg', 12500, 2),
    (gen_random_uuid()::text, '3355adef-385d-5eee-a565-815c8cf8e4d3', 'product-011', 'dbff9b88-4829-5eed-b15a-78c33431553f', 'Smartphone Android 64GB', 85000, 1);

  insert into public.favorites (id, user_id, product_id) values
    (gen_random_uuid()::text, '04060d99-e34d-520e-8b75-631ff4d3c10c', 'product-001');

  -- ------------------------------------------------------------------------
  -- 5. addresses (2)
  -- ------------------------------------------------------------------------
  insert into public.addresses (user_id, label, city, details, latitude, longitude) values
    ('04060d99-e34d-520e-8b75-631ff4d3c10c', 'Domicile', 'Bamako', 'Hippodrome, Rue 12, Porte 34', 12.6492, -7.9929),
    ('3355adef-385d-5eee-a565-815c8cf8e4d3', 'Domicile', 'Bamako', 'Badalabougou, Porte 45', 12.6242, -8.0109);

  -- ------------------------------------------------------------------------
  -- 6. orders / order_supplier_groups / order_items
  -- ------------------------------------------------------------------------
  insert into public.orders (
    id, client_id, client_display_name_snapshot, client_phone_snapshot, status, placed_at,
    total_fcfa, delivery_address_label, delivery_city, delivery_details, delivery_latitude, delivery_longitude
  ) values
    ('order-awa-delivered', '04060d99-e34d-520e-8b75-631ff4d3c10c', 'Awa Traoré', '+22370000001', 'delivered',
     now() - interval '6 days', 25000, 'Domicile', 'Bamako', 'Hippodrome, Rue 12, Porte 34', 12.6492, -7.9929),
    ('order-awa-intransit', '04060d99-e34d-520e-8b75-631ff4d3c10c', 'Awa Traoré', '+22370000001', 'in_transit',
     now() - interval '3 hours', 87000, 'Domicile', 'Bamako', 'Hippodrome, Rue 12, Porte 34', 12.6492, -7.9929),
    ('order-moussa-delivered', '3355adef-385d-5eee-a565-815c8cf8e4d3', 'Moussa Diarra', '+22370000002', 'delivered',
     now() - interval '4 days', 12500, 'Domicile', 'Bamako', 'Badalabougou, Porte 45', 12.6242, -8.0109),
    ('order-moussa-intransit', '3355adef-385d-5eee-a565-815c8cf8e4d3', 'Moussa Diarra', '+22370000002', 'in_transit',
     now() - interval '1 hour', 22000, 'Domicile', 'Bamako', 'Badalabougou, Porte 45', 12.6242, -8.0109),
    ('seed-order-1', '3355adef-385d-5eee-a565-815c8cf8e4d3', 'Moussa Diarra', '+22370000002', 'delivered',
     now() - interval '12 days', 25000, 'Domicile', 'Bamako', 'Badalabougou, Porte 45', 12.6242, -8.0109),
    ('seed-order-2', '04060d99-e34d-520e-8b75-631ff4d3c10c', 'Awa Traoré', '+22370000001', 'delivered',
     now() - interval '22 days', 12500, 'Domicile', 'Bamako', 'Hippodrome, Rue 12, Porte 34', 12.6492, -7.9929);

  insert into public.order_supplier_groups (
    id, order_id, supplier_id, supplier_name, delivery_mode, delivery_fee_fcfa, subtotal_fcfa, status
  ) values
    ('group-awa-delivered-1', 'order-awa-delivered', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'Bogolan Bamako', 'self_delivery', 0, 25000, 'delivered'),
    ('group-awa-intransit-1', 'order-awa-intransit', 'dbff9b88-4829-5eed-b15a-78c33431553f', 'Electro Bamako', 'mtc_delivery', 2000, 85000, 'in_transit'),
    ('group-moussa-delivered-1', 'order-moussa-delivered', '2c66294c-e1d7-59f1-925c-5ab6703827f3', 'Alimentation Ségou', 'self_delivery', 0, 12500, 'delivered'),
    ('group-moussa-intransit-1', 'order-moussa-intransit', '01e2be08-764b-5ea6-8a32-a1b5152497b1', 'Matériaux Koutiala', 'mtc_delivery', 2000, 20000, 'in_transit'),
    ('seed-group-1', 'seed-order-1', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'Bogolan Bamako', 'self_delivery', 0, 25000, 'delivered'),
    ('seed-group-2', 'seed-order-2', '2c66294c-e1d7-59f1-925c-5ab6703827f3', 'Alimentation Ségou', 'self_delivery', 0, 12500, 'delivered');

  insert into public.order_items (group_id, product_id, product_name_snapshot, unit_price_fcfa_snapshot, quantity) values
    ('group-awa-delivered-1', 'product-001', 'Tissu Bogolan traditionnel', 25000, 1),
    ('group-awa-intransit-1', 'product-011', 'Smartphone Android 64GB', 85000, 1),
    ('group-moussa-delivered-1', 'product-015', 'Riz local 25kg', 12500, 1),
    ('group-moussa-intransit-1', 'product-019', 'Ciment (sac 50kg)', 5000, 4),
    ('seed-group-1', 'product-001', 'Tissu Bogolan traditionnel', 25000, 1),
    ('seed-group-2', 'product-015', 'Riz local 25kg', 12500, 1);

  -- ------------------------------------------------------------------------
  -- 7. reviews (2)
  -- ------------------------------------------------------------------------
  insert into public.reviews (id, order_id, supplier_group_id, client_id, supplier_id, stars, comment, created_at) values
    ('seed-review-1', 'seed-order-1', 'seed-group-1', '3355adef-385d-5eee-a565-815c8cf8e4d3', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3',
     5, 'Très beau tissu, livraison rapide.', now() - interval '10 days'),
    ('seed-review-2', 'seed-order-2', 'seed-group-2', '04060d99-e34d-520e-8b75-631ff4d3c10c', '2c66294c-e1d7-59f1-925c-5ab6703827f3',
     5, 'Riz de très bonne qualité, je recommande.', now() - interval '20 days');

  -- ------------------------------------------------------------------------
  -- 8. supplier_kyc / supplier_documents (3 dossiers, 5 documents)
  -- ------------------------------------------------------------------------
  insert into public.supplier_kyc (
    id, supplier_id, legal_type, status, created_at, submitted_at, reviewed_at, reviewed_by_staff_id,
    rejection_reason, rccm_number, tax_id, legal_representative_name, registered_address
  ) values
    ('kyc-bogolan-bamako', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'company', 'approved',
     now() - interval '61 days', now() - interval '60 days', now() - interval '58 days',
     '2358888a-b13d-56f8-858b-a0c63831b512', null,
     'MA.BKO.2022.B.0456', 'NIF-004521', 'Ibrahima Coulibaly', 'Zone Industrielle, Bamako'),
    ('kyc-artisanat-sikasso', 'b6b1daf0-1c8e-583f-939f-687991d429ca', 'company', 'submitted',
     now() - interval '3 days', now() - interval '2 days', null, null, null,
     'MA.SIK.2026.B.0789', 'NIF-009873', 'Fatoumata Keita', 'Marché Central, Sikasso'),
    ('kyc-fruits-niono', 'deb94bf5-bddb-5399-8010-3b0264c98f1a', 'company', 'rejected',
     now() - interval '6 days', now() - interval '5 days', now() - interval '4 days',
     '0354c601-5e09-57b6-a23c-affaa5acf0d0',
     'Le numéro RCCM fourni ne correspond à aucun enregistrement valide. Merci de soumettre un extrait RCCM lisible et à jour.',
     null, 'NIF-002211', 'Seydou Traoré', 'Marché de Niono');

  insert into public.supplier_documents (id, kyc_id, type, file_path, uploaded_at) values
    ('doc-bogolan-rccm', 'kyc-bogolan-bamako', 'rccm_certificate', 'seed://rccm-bogolan.jpg', now() - interval '60 days'),
    ('doc-bogolan-manager-id', 'kyc-bogolan-bamako', 'manager_id_card', 'seed://id-bogolan.jpg', now() - interval '60 days'),
    ('doc-sikasso-rccm', 'kyc-artisanat-sikasso', 'rccm_certificate', 'seed://rccm-sikasso.jpg', now() - interval '2 days'),
    ('doc-sikasso-manager-id', 'kyc-artisanat-sikasso', 'manager_id_card', 'seed://id-sikasso.jpg', now() - interval '2 days'),
    ('doc-niono-manager-id', 'kyc-fruits-niono', 'manager_id_card', 'seed://id-niono.jpg', now() - interval '5 days');

  -- ------------------------------------------------------------------------
  -- 9. payout_requests (1)
  -- ------------------------------------------------------------------------
  insert into public.payout_requests (id, supplier_id, amount_fcfa, status, requested_at, method, payout_destination, processed_at) values
    ('payout-bogolan-1', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 10000, 'paid',
     now() - interval '4 days', 'orange_money', '+22370000010', now() - interval '3 days');

  -- ------------------------------------------------------------------------
  -- 10. chat (2 conversations, 3 messages)
  -- ------------------------------------------------------------------------
  insert into public.chat_conversations (
    id, client_id, client_display_name_snapshot, supplier_id, supplier_name,
    last_message_preview, last_message_at, unread_count_client, unread_count_supplier
  ) values
    ('conv-awa-bogolan', '04060d99-e34d-520e-8b75-631ff4d3c10c', 'Awa Traoré', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'Bogolan Bamako',
     'Oui, disponible en plusieurs coloris !', now() - interval '2 hours', 1, 0),
    ('conv-moussa-mtc', '3355adef-385d-5eee-a565-815c8cf8e4d3', 'Moussa Diarra', '3331cbb4-0a65-5f94-9812-fe4270e50fe2', 'MTC Officiel',
     'Bienvenue sur Mali Trade Connect !', now() - interval '1 day', 0, 0);

  insert into public.chat_messages (id, conversation_id, sender_id, text, sent_at, is_read) values
    ('msg-1', 'conv-awa-bogolan', '04060d99-e34d-520e-8b75-631ff4d3c10c',
     'Bonjour, le tissu bogolan est-il disponible en plusieurs couleurs ?', now() - interval '3 hours', true),
    ('msg-2', 'conv-awa-bogolan', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3',
     'Oui, disponible en plusieurs coloris !', now() - interval '2 hours', false),
    ('msg-3', 'conv-moussa-mtc', '3331cbb4-0a65-5f94-9812-fe4270e50fe2',
     'Bienvenue sur Mali Trade Connect ! Nous sommes là pour vous aider.', now() - interval '1 day', true);

  -- ------------------------------------------------------------------------
  -- 11. product_comments (3) + comment_likes (1)
  -- ------------------------------------------------------------------------
  insert into public.product_comments (id, product_id, supplier_id, author_id, author_name, created_at, text, is_supplier, parent_id) values
    ('comment-001', 'product-001', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', '3355adef-385d-5eee-a565-815c8cf8e4d3', 'Moussa Diarra',
     now() - interval '2 days',
     'Le tissu est-il aussi solide qu''il en a l''air ? Je cherche quelque chose de durable pour un boubou de tous les jours.',
     false, null),
    ('comment-002', 'product-001', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', 'Bogolan Bamako',
     now() - interval '1 day 20 hours',
     'Oui, c''est un coton épais tissé main, teint deux fois pour bien fixer les motifs. Très résistant à l''usage quotidien.',
     true, 'comment-001'),
    ('comment-003', 'product-001', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', '04060d99-e34d-520e-8b75-631ff4d3c10c', 'Awa Traoré',
     now() - interval '5 hours',
     'Magnifiques couleurs, exactement comme sur les photos !',
     false, null);

  insert into public.comment_likes (comment_id, user_id) values
    ('comment-003', '3355adef-385d-5eee-a565-815c8cf8e4d3');
end;
$$;

-- Le rôle `authenticated`/`anon` ne doit PAS pouvoir appeler ceci en
-- production (recrée des comptes avec mot de passe connu) — mais ce projet
-- ne tourne que localement pour l'instant (Lot 0). Restreint quand même à
-- `service_role` par prudence : le harnais de test (Lot 3) appellera cette
-- fonction via la clé secrète, jamais depuis l'app Flutter elle-même.
revoke all on function public.test_reset_and_seed() from public, anon, authenticated;
grant execute on function public.test_reset_and_seed() to service_role;
