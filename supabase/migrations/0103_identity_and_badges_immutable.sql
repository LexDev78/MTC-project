-- Trois colonnes que l'on pouvait s'attribuer soi-même.
--
-- Tout a été mesuré sur la base, en transaction annulée, en se présentant
-- comme un utilisateur ordinaire (`set local role authenticated` plus le
-- `sub` du jeton) — c'est-à-dire exactement ce que PostgREST fait d'une
-- requête de l'application.
--
-- ## 1. Devenir administrateur MTC en une requête
--
--   update profiles set role='supplier_principal', staff_role='admin'
--    where id = auth.uid();                                      -- UPDATE 1
--   select is_staff(), is_admin();                               -- t, t
--
-- La politique `profiles_update_own` autorise un utilisateur à écrire sa
-- propre ligne, et `authenticated` avait le droit de mettre à jour **toutes**
-- les colonnes, `role` et `staff_role` comprises. La contrainte
-- `staff_role_matches_role` n'exigeait que de changer les deux ensemble.
--
-- À partir de là tout s'ouvre : `is_staff()` donne les dossiers KYC de tous
-- les fournisseurs, `is_admin()` donne `update_payout_status` — donc le
-- pouvoir de marquer n'importe quel retrait comme payé.
--
-- Or l'application **n'écrit jamais** dans `profiles` : elle la lit
-- (`supabase_auth_datasource.dart`). Les quatre écritures légitimes passent
-- par des fonctions `security definer` — `handle_new_user`,
-- `deactivate_account`, `mark_password_changed`,
-- `reset_collaborator_password_flag`. Le droit accordé n'avait aucun usage.
--
-- ## 2. Se décerner le badge « vérifié »
--
--   update suppliers set verification_status='verified' where id=<soi>;
--                                                                -- UPDATE 1
--
-- `suppliers_update_own` autorise le fournisseur (permission `storefront`) à
-- écrire sa fiche — pour sa vitrine. Le badge que l'acheteur lit comme la
-- garantie de MTC était dans le même lot. Côté serveur, il n'appartient qu'à
-- `review_supplier_kyc`, que seul le staff peut appeler.
--
-- ## 3. S'attribuer cinq étoiles
--
--   update suppliers set rating_average=5, rating_count=9999 ...  -- UPDATE 1
--   update products  set rating_average=5, rating_count=9999 ...  -- UPDATE 5
--
-- La moyenne et le compte d'avis sont écrits par `submit_review` (`0063`),
-- qui les recalcule à partir de la table `reviews`. Les colonnes restaient
-- malgré tout ouvertes en écriture directe : la note qu'un acheteur regarde
-- avant d'acheter était déclarative.
--
-- ## Le mécanisme
--
-- Deux verrous, parce qu'ils n'arrêtent pas la même chose.
--
-- Le **droit de colonne** arrête la requête directe, avant toute politique.
-- Il ne sert que pour `profiles`, où aucune écriture directe n'est légitime.
-- Ailleurs, la vitrine doit rester modifiable : révoquer la table pour la
-- rendre colonne par colonne obligerait à tenir la liste à jour à chaque
-- nouveau champ, et un oubli y rouvrirait le trou en silence.
--
-- Le **déclencheur** distingue donc la requête directe du code serveur par
-- `current_user` : PostgREST exécute une requête sous `anon` ou
-- `authenticated`, tandis qu'une fonction `security definer` s'exécute sous
-- son propriétaire. Vérifié avant d'être écrit :
--
--   requête directe : current_user = authenticated
--   dans un definer : current_user = postgres
--
-- C'est la même division que les gardes de collaborateur (`0097`) : la
-- politique pour la requête, le déclencheur pour ce qui la contourne.

-- ---------------------------------------------------------------------------
-- 1. `profiles` : plus aucune écriture directe, et une identité immuable.
-- ---------------------------------------------------------------------------

revoke update on public.profiles from authenticated, anon;

-- L'identité ne change par **aucun** chemin, pas même serveur. Rien ne la
-- modifie aujourd'hui : `handle_new_user` l'écrit à l'inscription, et les
-- trois autres fonctions ne touchent que `deleted_at` et
-- `must_change_password`. Promouvoir quelqu'un au staff redevient donc une
-- opération de schéma, délibérée et tracée — ce qu'elle doit être.
create or replace function public.guard_profile_identity()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.id is distinct from old.id then
    raise exception 'L''identifiant d''un profil ne change pas.';
  end if;
  if new.role is distinct from old.role then
    raise exception 'Le rôle d''un compte ne se change pas après coup (% → %).',
      old.role, new.role;
  end if;
  if new.staff_role is distinct from old.staff_role then
    raise exception 'Le rôle de staff ne s''attribue pas par mise à jour.';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_identity_immutable on public.profiles;
create trigger profiles_identity_immutable
  before update on public.profiles
  for each row execute function public.guard_profile_identity();

-- ---------------------------------------------------------------------------
-- 2. `suppliers` : le badge et la note sortent de la vitrine.
-- ---------------------------------------------------------------------------

create or replace function public.guard_supplier_badges()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  -- Seule la requête directe est visée : `review_supplier_kyc`,
  -- `submit_review` et le semis des tests s'exécutent sous le propriétaire.
  if current_user not in ('anon', 'authenticated') then
    return new;
  end if;

  if new.verification_status is distinct from old.verification_status then
    raise exception
      'Le statut de vérification est décidé par MTC, pas par la boutique.';
  end if;
  if new.rating_average is distinct from old.rating_average
     or new.rating_count is distinct from old.rating_count then
    raise exception 'La note d''une boutique se calcule à partir des avis.';
  end if;
  -- La forme juridique commande les pièces exigées au dossier : la changer
  -- après coup ferait accepter un dossier de particulier pour une société.
  if new.legal_type is distinct from old.legal_type
     or new.supplier_type is distinct from old.supplier_type then
    raise exception 'La forme juridique se change par le dossier, pas ici.';
  end if;
  return new;
end;
$$;

drop trigger if exists suppliers_badges_immutable on public.suppliers;
create trigger suppliers_badges_immutable
  before update on public.suppliers
  for each row execute function public.guard_supplier_badges();

-- ---------------------------------------------------------------------------
-- 3. `products` : même règle pour la note recopiée.
-- ---------------------------------------------------------------------------

create or replace function public.guard_product_rating()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_user not in ('anon', 'authenticated') then
    return new;
  end if;
  if new.rating_average is distinct from old.rating_average
     or new.rating_count is distinct from old.rating_count then
    raise exception 'La note d''un produit se calcule à partir des avis.';
  end if;
  return new;
end;
$$;

drop trigger if exists products_rating_immutable on public.products;
create trigger products_rating_immutable
  before update on public.products
  for each row execute function public.guard_product_rating();
