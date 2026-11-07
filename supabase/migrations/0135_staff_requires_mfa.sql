-- Un compte du staff MTC ne vaut plus rien avec son seul mot de passe.
--
-- Signalé par l'audit : 6 caractères au minimum, aucune double
-- authentification, même pour les administrateurs — des comptes qui voient
-- toutes les commandes, les pièces d'identité des vendeurs et des livreurs,
-- et décident des paiements et des versements. Un mot de passe deviné,
-- réutilisé ou hameçonné suffisait.
--
-- Désormais `is_staff()` et `is_admin()` exigent une session de niveau
-- `aal2` : mot de passe **et** code à usage unique d'une application
-- d'authentification (TOTP, Supabase Auth). Une session `aal1` d'un compte
-- staff ne voit rien de ce que voit le staff, et n'opère pas la boutique
-- MTC — exactement comme un faux administrateur depuis `0128`.
--
-- Le mot de passe, lui : 10 caractères au moins pour un compte staff
-- (`reset_password_with_code`, `0132`, l'écran de changement de mot de
-- passe, et le script de création des comptes staff). Supabase Auth n'a
-- qu'un minimum pour tous les comptes ; le relever pour les clients reste
-- une décision à part.
--
-- ## Le réglage `staff_mfa_required`
--
-- Exigé par défaut : sans ligne dans `app_settings`, la double
-- authentification l'est. Le jeu de démonstration local l'éteint
-- (`seeds/test_helpers.sql`), parce que la pile locale n'active la TOTP
-- qu'avec `[auth.mfa.totp]` de `config.toml` et un redémarrage. En
-- production on ne l'éteint pas : seule une session `postgres` ou la clé de
-- service peut écrire cette table.
--
-- **Avant de déployer cette migration sur un projet hébergé** : activer la
-- TOTP dans Authentication → Multi-Factor (enrôlement et vérification),
-- sans quoi aucun membre du staff ne pourra plus rien faire. Voir
-- `supabase/production/MISE_EN_PRODUCTION.md`.

create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.app_settings enable row level security;
revoke all on public.app_settings from public, anon, authenticated;

comment on table public.app_settings is
  'Réglages de sécurité de la plateforme (0135). Aucune politique : lus par '
  'des fonctions security definer, écrits par postgres ou la clé de service.';

-- Vrai sauf si l'exploitant l'a explicitement éteint.
create or replace function public.staff_mfa_required()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select (s.value #>> '{}')::boolean from public.app_settings s where s.key = 'staff_mfa_required'),
    true
  );
$$;

-- L'app le demande pour savoir s'il faut montrer l'écran du code : elle ne
-- décide rien, la base refuse de toute façon une session `aal1`.
revoke all on function public.staff_mfa_required() from public, anon;
grant execute on function public.staff_mfa_required() to authenticated;

-- Reprise de `0128`, avec le niveau de la session.
create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
     where p.id = auth.uid()
       and p.staff_role is not null
       and p.staff_role::text = (auth.jwt() -> 'app_metadata' ->> 'staff_role')
  )
  and (
    coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2'
    or not public.staff_mfa_required()
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
     where p.id = auth.uid()
       and p.staff_role = 'admin'
       and (auth.jwt() -> 'app_metadata' ->> 'staff_role') = 'admin'
  )
  and (
    coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2'
    or not public.staff_mfa_required()
  );
$$;

notify pgrst, 'reload schema';
