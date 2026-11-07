-- Corrige trois failles trouvées en audit complet :
--
-- 1) CRITIQUE — `handle_new_user()` faisait confiance à `raw_user_meta_data`
--    (100% contrôlé par le client au moment du `signUp`, un endpoint
--    public) pour `role` ET `staff_role`. Un signup public avec
--    `data: {role: "supplier_principal", staff_role: "admin"}` obtenait
--    `profiles.staff_role = 'admin'` — prise de contrôle admin complète
--    sans authentification préalable, `is_staff()`/`is_admin()` (qui
--    gardent absolument tout) étant entièrement dérivées de cette colonne.
--    Remède : `staff_role` n'est plus jamais lu depuis `raw_user_meta_data`
--    pour un vrai signup public (détecté via `session_user =
--    'supabase_auth_admin'`, le rôle Postgres dédié que GoTrue utilise pour
--    écrire dans `auth.users` — stable sur toute instance Supabase, locale
--    ou hébergée), et `role = 'supplier_principal'` y est rejeté purement
--    et simplement. Le harnais de test (`test_reset_and_seed`, 0002/0020)
--    continue de fonctionner : il écrit dans `auth.users` en tant que
--    `postgres` (propriétaire `security definer` de la fonction), jamais
--    en tant que `supabase_auth_admin`.
--
-- 2) CRITIQUE — `products_update_rating_reviewer` (0001) autorise l'UPDATE
--    de toute la ligne `products` dès que `has_reviewed_supplier(supplier_id)`
--    — Postgres RLS ne restreint pas par colonne, donc un client ayant
--    laissé un avis pouvait réécrire `price_fcfa`/`stock_quantity`/
--    `is_supplier_verified`/n'importe quoi d'autre sur les produits de ce
--    fournisseur, pas seulement `rating_average`/`rating_count`. Même
--    classe de faille que celle fermée pour `suppliers.verification_status`
--    (0029), même remède : un trigger de garde, qui compare `new`/`old` en
--    entier plutôt qu'une liste de colonnes interdites — une future colonne
--    ajoutée à `products` est protégée par défaut, jamais oubliée.
--
-- 3) ÉLEVÉ — `reviews_update_own_supplier` (0001) autorise le fournisseur
--    concerné à modifier toute la ligne `reviews`, y compris `stars`/
--    `comment` qui appartiennent au client — un fournisseur pouvait
--    réécrire la note/le texte d'un avis client. C'est la SEULE policy
--    UPDATE sur `reviews` (pas de policy "le client édite son propre avis",
--    et pas de policy staff/admin) : la restriction s'applique donc à
--    quiconque atteint cette table en écriture, sans condition de
--    contournement à part `supplier_reply`/`supplier_replied_at`.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  meta jsonb := new.raw_user_meta_data;
  v_role public.account_role := (meta ->> 'role')::public.account_role;
  v_is_public_signup boolean := session_user = 'supabase_auth_admin';
  v_staff_role public.staff_role;
begin
  if v_is_public_signup and v_role = 'supplier_principal' then
    raise exception 'Ce mode d''inscription n''est pas disponible via l''API publique.';
  end if;

  -- `staff_role` ne vient jamais du client sur un vrai signup public — seul
  -- le harnais de test (`session_user <> 'supabase_auth_admin'`) peut le
  -- fixer, exactement comme aujourd'hui pour `admin1`/`agent1`.
  if not v_is_public_signup and v_role = 'supplier_principal' then
    v_staff_role := (meta ->> 'staff_role')::public.staff_role;
  else
    v_staff_role := null;
  end if;

  insert into public.profiles (id, role, username_or_phone, display_name, phone_number, staff_role)
  values (
    new.id,
    v_role,
    meta ->> 'username_or_phone',
    meta ->> 'display_name',
    meta ->> 'phone_number',
    v_staff_role
  );

  if v_role = 'supplier_tiers' then
    insert into public.suppliers (id, business_name, supplier_type, city, verification_status, legal_type)
    values (
      new.id,
      meta ->> 'business_name',
      'tiers',
      meta ->> 'city',
      'unverified',
      (meta ->> 'legal_type')::public.supplier_legal_type
    );
  end if;

  return new;
end;
$$;

-- ----------------------------------------------------------------------------
-- Garde colonnes `products` : le chemin "reviewer" ne touche jamais rien
-- d'autre que `rating_average`/`rating_count`. Propriétaire (`products_write_own`)
-- et staff (`products_update_verification_staff`) gardent un accès complet.
-- ----------------------------------------------------------------------------
create or replace function public.guard_products_reviewer_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or public.is_staff() or old.supplier_id = public.operating_supplier_id() then
    return new;
  end if;

  if to_jsonb(new) is distinct from (to_jsonb(old) || jsonb_build_object(
    'rating_average', new.rating_average,
    'rating_count', new.rating_count
  )) then
    raise exception 'Non autorisé à modifier ce produit au-delà de sa note.';
  end if;
  return new;
end;
$$;

drop trigger if exists products_guard_reviewer_columns on public.products;
create trigger products_guard_reviewer_columns
  before update on public.products
  for each row
  execute function public.guard_products_reviewer_columns();

-- ----------------------------------------------------------------------------
-- Garde colonnes `reviews` : `reviews_update_own_supplier` est la SEULE
-- policy UPDATE sur cette table — le fournisseur concerné ne touche jamais
-- rien d'autre que `supplier_reply`/`supplier_replied_at`.
-- ----------------------------------------------------------------------------
create or replace function public.guard_reviews_supplier_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return new;
  end if;

  if to_jsonb(new) is distinct from (to_jsonb(old) || jsonb_build_object(
    'supplier_reply', new.supplier_reply,
    'supplier_replied_at', new.supplier_replied_at
  )) then
    raise exception 'Non autorisé à modifier cet avis au-delà de la réponse du fournisseur.';
  end if;
  return new;
end;
$$;

drop trigger if exists reviews_guard_supplier_columns on public.reviews;
create trigger reviews_guard_supplier_columns
  before update on public.reviews
  for each row
  execute function public.guard_reviews_supplier_columns();
