-- Deux comptes livreurs de démonstration, dans un helper **à part** plutôt
-- qu'ajoutés au corps de `test_reset_and_seed()`.
--
-- Ce dernier fait six cents lignes : le rouvrir pour y glisser deux comptes
-- obligerait à le recopier entier dans cette migration, avec tout ce que ça
-- comporte de risque de divergence silencieuse. Un helper séparé, appelé
-- juste après lui (par `seed.sql` et par le harnais de test), donne le même
-- résultat sans toucher à l'existant.
--
-- Idempotent : les deux comptes sont supprimés puis recréés, pour que deux
-- appels d'affilée ne se marchent pas dessus.
--
-- `livreur1` est **validé** (il reçoit des courses tout de suite) et
-- `livreur2` reste **en attente** : les deux états de l'écran livreur sont
-- ainsi visibles sans manipulation en base.
create or replace function public.test_seed_couriers()
returns void
language plpgsql
security definer
-- `extensions` en plus de `public` : `crypt`/`gen_salt` (pgcrypto) y vivent
-- dans Supabase, comme pour `test_reset_and_seed()` (0002/0020).
set search_path = public, extensions
as $$
begin
  delete from auth.users where id in (
    'f1c4e8a2-0000-5000-9000-000000000001',
    'f1c4e8a2-0000-5000-9000-000000000002'
  );

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token, email_change, email_change_token_new
  ) values
    (
      '00000000-0000-0000-0000-000000000000',
      'f1c4e8a2-0000-5000-9000-000000000001', 'authenticated', 'authenticated',
      'livreur1@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"livreur","username_or_phone":"livreur1","display_name":"Oumar Sidibé","phone_number":"+22378000001","city":"Bamako","vehicle_label":"Moto"}',
      '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      'f1c4e8a2-0000-5000-9000-000000000002', 'authenticated', 'authenticated',
      'livreur2@mtc.local', crypt('password123', gen_salt('bf')), now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"role":"livreur","username_or_phone":"livreur2","display_name":"Fanta Cissé","phone_number":"+22378000002","city":"Bamako","vehicle_label":"Tricycle"}',
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
    'f1c4e8a2-0000-5000-9000-000000000001',
    'f1c4e8a2-0000-5000-9000-000000000002'
  );

  -- `handle_new_user()` vient de créer les deux fiches en `pending` ; seule
  -- la première est validée, la seconde reste en attente exprès.
  update public.couriers
     set status = 'approved', reviewed_at = now()
   where id = 'f1c4e8a2-0000-5000-9000-000000000001';
end;
$$;

-- Même verrou que les autres helpers de test
-- (`0039_lock_test_helpers_in_production.sql`) : exécutable seulement par
-- `service_role`, et la permission n'est re-accordée que par `seed.sql`, que
-- seul `supabase db reset` joue — jamais `db push`.
revoke all on function public.test_seed_couriers() from public, anon, authenticated;

-- Force le statut d'un groupe fournisseur, sans passer par les transitions
-- autorisées ni par une session de fournisseur.
--
-- Sert à **remettre en place** un décor que le jeu de démo livre déjà joué :
-- ses deux groupes livrés par MTC sont déjà `in_transit`, alors que c'est la
-- transition *vers* cet état qui crée une course. Rien qu'un vrai
-- utilisateur puisse faire — d'où le helper de test plutôt qu'un détour par
-- l'app.
create or replace function public.test_set_group_status(
  p_group_id text,
  p_status text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.order_supplier_groups
     set status = p_status::public.order_status
   where id = p_group_id;
end;
$$;

revoke all on function public.test_set_group_status(text, text) from public, anon, authenticated;
