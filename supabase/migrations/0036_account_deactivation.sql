-- Suppression de compte (soft delete) — voir
-- /Users/solomon/.claude/plans/fluffy-sauteeing-pudding.md.
--
-- Aucune fonctionnalité de suppression de compte n'existait avant cette
-- migration. Un compte "supprimé" n'est jamais détruit : `orders.client_id`,
-- `reviews.client_id`, `chat_conversations.client_id` référencent
-- `profiles.id` sans cascade (`NO ACTION`) — une vraie suppression casserait
-- dès qu'un compte a la moindre commande/avis/conversation. Et `suppliers`
-- n'a aucune clé étrangère vers son compte propriétaire (le storefront MTC
-- partagé n'a pas de compte auth) — une vraie suppression laisserait la
-- boutique et ses produits orphelins et vivants pour toujours.

alter table public.profiles add column deleted_at timestamptz;
alter table public.suppliers add column deleted_at timestamptz;

-- ---- suppliers/products : un compte supprimé disparaît du catalogue -------
drop policy if exists "suppliers_select_public" on public.suppliers;
create policy "suppliers_select_public" on public.suppliers
  for select using (deleted_at is null);

drop policy if exists "products_select_public" on public.products;
create policy "products_select_public" on public.products
  for select using (
    (
      status = 'active'
      and is_supplier_verified = true
      and exists (
        select 1 from public.suppliers s where s.id = supplier_id and s.deleted_at is null
      )
    )
    or supplier_id = public.operating_supplier_id()
  );

-- ---- écriture bloquée pour un compte déjà supprimé -------------------------
-- Défense en profondeur seulement : le compte est de toute façon déconnecté
-- immédiatement (voir `SupabaseAuthRepository._hydrateAppUser`) et ne peut
-- plus se reconnecter (`AccountDeletedException`), donc cette policy ne
-- protège que contre un jeton encore valide utilisé après coup. Le staff
-- (`is_staff()`) et le recalcul de note par un client qui laisse un avis
-- (`has_reviewed_supplier`) restent inchangés — seul le propriétaire
-- lui-même perd le droit d'écrire sur sa propre ligne une fois supprimé.
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update
  using (id = auth.uid() and deleted_at is null)
  with check (id = auth.uid() and deleted_at is null);

drop policy if exists "suppliers_update_own" on public.suppliers;
create policy "suppliers_update_own" on public.suppliers
  for update using (
    (id = public.operating_supplier_id() and deleted_at is null)
    or public.is_staff()
    or public.has_reviewed_supplier(id)
  )
  with check (
    (id = public.operating_supplier_id() and deleted_at is null)
    or public.is_staff()
    or public.has_reviewed_supplier(id)
  );

-- ---- deactivate_account() --------------------------------------------------
-- Un compte staff (`supplier_principal`) ne peut jamais s'auto-supprimer —
-- provisionné en interne, jamais en libre-service (voir `handle_new_user()`,
-- qui refuse déjà ce rôle à l'inscription publique). Un fournisseur tiers
-- avec des commandes ou un retrait non résolus ne peut pas non plus se
-- supprimer — pas de compte qui disparaît en pleine transaction.
create or replace function public.deactivate_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role public.account_role;
begin
  select role into v_role from public.profiles where id = auth.uid();
  if v_role is null then
    raise exception 'Compte introuvable.';
  end if;
  if v_role = 'supplier_principal' then
    raise exception 'Les comptes staff ne peuvent pas être supprimés depuis cette fonction.';
  end if;

  if v_role = 'supplier_tiers' then
    if exists (
      select 1 from public.order_supplier_groups
      where supplier_id = auth.uid() and status not in ('delivered', 'cancelled')
    ) then
      raise exception
        'Vous avez des commandes en cours — terminez-les avant de supprimer votre compte.';
    end if;
    if exists (
      select 1 from public.payout_requests
      where supplier_id = auth.uid() and status not in ('paid', 'rejected')
    ) then
      raise exception
        'Vous avez une demande de retrait en cours — attendez son traitement avant de '
        'supprimer votre compte.';
    end if;
  end if;

  update public.profiles set deleted_at = now() where id = auth.uid();
  if v_role = 'supplier_tiers' then
    update public.suppliers set deleted_at = now() where id = auth.uid();
  end if;

  -- Best-effort : verrouille aussi la connexion côté Supabase Auth
  -- lui-même, pour bloquer une future connexion/rafraîchissement de session
  -- plus tôt qu'à la prochaine hydratation côté app. Aucune fonction
  -- `security definer` de ce projet n'écrit dans le schéma `auth`
  -- aujourd'hui, et les droits `postgres` dessus peuvent différer entre le
  -- stack local et un projet hébergé — si ça échoue, RLS + le contrôle côté
  -- app (`SupabaseAuthRepository._hydrateAppUser`) suffisent déjà.
  begin
    update auth.users set banned_until = '2500-01-01'::timestamptz where id = auth.uid();
  exception when others then
    null;
  end;
end;
$$;

revoke all on function public.deactivate_account() from public, anon;
grant execute on function public.deactivate_account() to authenticated;
