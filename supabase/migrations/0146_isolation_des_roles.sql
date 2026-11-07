-- 0146 — Chacun dans son rôle, et rien de plus (trouvé en corrigeant l'audit
-- du 27/10/2026, le 05/11/2026 ; règle du projet : aucun utilisateur ne voit
-- ni n'atteint un rôle qui n'est pas le sien).
--
-- 1. Les chemins du client acceptaient n'importe quel rôle. Constaté : un
--    livreur remplit un panier, commande, se fait proposer sa propre
--    commande en livraison MTC, la clôt avec le code du client qu'il lit, et
--    se note 5★. La base exige désormais un compte client pour le panier,
--    les favoris, les adresses et l'ouverture d'une conversation avec une
--    boutique ; `place_order` aussi (`0147`), ce qui coupe toute la chaîne à
--    sa source.
--
-- 2. `pickup_point(deliveries)` jugeait l'appelant sur la ligne qu'on lui
--    passait, sans la relire : `pickup_point('(x,x,<groupe>,accepted,
--    <moi>,…)')` rendait l'adresse exacte et le GPS de n'importe quelle
--    boutique, que `0133` avait justement rendus privés. Elle relit
--    désormais la course par son identifiant.
--
-- 3. Le livreur lisait la ligne entière de la commande (`orders_select_
--    courier`), y compris le message privé du client à la boutique, et la
--    gardait après la livraison. Il ne lit plus que ce que son écran
--    affiche, par `courier_order(deliveries)` — et plus rien de privé une
--    fois la course finie.
--
-- 4. Une boutique supprimée continuait de fonctionner par ses
--    collaborateurs : `operating_supplier_id()` et `supplier_can()` ne
--    regardaient pas `suppliers.deleted_at`. Constaté : après la
--    suppression, un collaborateur lit encore les conversations et les
--    commandes, et écrit aux clients au nom de la boutique.
--
-- 5. L'annulation d'une commande livrée par MTC ne fermait jamais la
--    course : le livreur gardait le numéro et l'adresse du client, le client
--    voyait toujours le GPS du livreur, et le livreur, « occupé », ne
--    recevait plus de course. Annuler ferme désormais la course ; et une
--    fois le colis chez le livreur, l'annulation passe par MTC.

-- ------------------------------------------------------- 1. le rôle client
-- `is_client()` est définie en `0140`, son premier usage (commentaires).
drop policy if exists addresses_all_own on public.addresses;
create policy addresses_all_own on public.addresses
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid() and public.is_client());

drop policy if exists cart_items_all_own on public.cart_items;
create policy cart_items_all_own on public.cart_items
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid() and public.is_client());

drop policy if exists favorites_all_own on public.favorites;
create policy favorites_all_own on public.favorites
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid() and public.is_client());

drop policy if exists chat_conversations_insert_client on public.chat_conversations;
create policy chat_conversations_insert_client on public.chat_conversations
  for insert with check (client_id = auth.uid() and public.is_client());

-- ---------------------------------------------- 2. le point de retrait
create or replace function public.pickup_point(d public.deliveries)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  -- Rien n'est lu sur `d` sauf son identifiant : la ligne vient de
  -- l'appelant, qui peut l'avoir fabriquée.
  select jsonb_strip_nulls(jsonb_build_object(
           'full_address', s.full_address,
           'latitude', s.address_latitude,
           'longitude', s.address_longitude
         ))
    from public.deliveries dd
    join public.order_supplier_groups g on g.id = dd.supplier_group_id
    join public.suppliers s on s.id = g.supplier_id
   where dd.id = d.id
     and (
       public.is_staff()
       or (g.supplier_id = public.operating_supplier_id() and public.supplier_can('orders'))
       or (dd.status in ('accepted', 'picked_up') and dd.courier_id = auth.uid())
       -- Une offre expirée n'est plus une offre (contre-vérification du
       -- 06/11/2026) : le livreur qui l'a laissée passer ne voit plus rien.
       or (dd.status = 'offered' and dd.offered_to_courier_id = auth.uid()
           and (dd.offer_expires_at is null or dd.offer_expires_at > now()))
     );
$$;

-- ------------------------------------- 3. ce que le livreur lit de la commande
-- Les quatre champs de l'écran du livreur (`supabase_delivery_repository`,
-- `_fromRow`) et ses coordonnées de contact (`client_contact`, qui décide
-- seul de ce qui en reste visible selon l'avancement de la course).
create or replace function public.courier_order(d public.deliveries)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
           'id', o.id,
           'client_display_name_snapshot', o.client_display_name_snapshot,
           'delivery_city', o.delivery_city,
           'payment_method', o.payment_method,
           -- Ce que le livreur encaisse se décide ici, pas dans l'app : une
           -- commande « payer maintenant » que MTC n'a pas vu payée
           -- (`payment_status`) s'encaisse à la remise, comme un paiement à
           -- la livraison. L'app se fiait au seul moyen choisi et le
           -- livreur remettait le colis sans rien demander
           -- (contre-vérification du 06/11/2026).
           'collect_on_delivery', o.payment_status <> 'paid',
           'client_contact', public.client_contact(o)
         )
    from public.deliveries dd
    join public.orders o on o.id = dd.order_id
   where dd.id = d.id
     and (dd.courier_id = auth.uid()
          or (dd.offered_to_courier_id = auth.uid()
              and (dd.offer_expires_at is null or dd.offer_expires_at > now())));
$$;

revoke all on function public.courier_order(public.deliveries) from public, anon;
grant execute on function public.courier_order(public.deliveries) to authenticated;

drop policy if exists orders_select_courier on public.orders;

-- ----------------------------------------------- 4. une boutique supprimée
create or replace function public.operating_supplier_id()
returns uuid
language sql
stable
security definer
set search_path to 'public'
as $function$
  select coalesce(
    -- Un compte supprimé n'opère plus rien, même avec un jeton encore valide
    -- (contre-vérification du 06/11/2026).
    case (select role from public.profiles where id = auth.uid() and deleted_at is null)
      when 'supplier_tiers' then (
        select s.id from public.suppliers s
         where s.id = auth.uid() and s.deleted_at is null
      )
      when 'supplier_principal' then
        case when public.is_staff() then '3331cbb4-0a65-5f94-9812-fe4270e50fe2'::uuid end
      else null
    end,
    -- Pas de boutique à soi : peut-être travaille-t-on pour celle d'un
    -- autre — tant qu'elle existe (`0146`).
    (
      select c.supplier_id from public.supplier_collaborators c
        join public.suppliers s on s.id = c.supplier_id
       where c.user_id = auth.uid()
         -- `0110` : un collaborateur dont l'accès est retiré garde sa
         -- ligne, mais n'opère plus aucune boutique.
         and c.deactivated_at is null
         and s.deleted_at is null
    )
  );
$function$;

create or replace function public.supplier_can(p_permission text)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  -- Le staff MTC passe aussi : il opère la boutique officielle sans
  -- posséder de ligne `suppliers` à son nom — `operating_supplier_id()`
  -- lui rend un identifiant fixe depuis `0001`. L'oublier le privait
  -- d'écrire sur son propre catalogue, ce qu'un test a dit aussitôt.
  select public.is_staff() or public.is_supplier_owner() or exists (
    select 1 from public.supplier_collaborators c
      join public.suppliers s on s.id = c.supplier_id
      join public.profiles p on p.id = c.user_id
     where c.user_id = auth.uid()
       and c.deactivated_at is null
       and s.deleted_at is null
       and p.deleted_at is null
       and p_permission = any (c.permissions)
  );
$function$;

-- La suppression du compte d'un patron retire aussi l'accès de son équipe.
-- Reprise de la définition en vigueur, cette instruction seule ajoutée.
create or replace function public.deactivate_account()
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
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
  if v_role = 'livreur' and exists (
    select 1 from public.deliveries
     where courier_id = auth.uid() and status in ('accepted', 'picked_up')
  ) then
    raise exception
      'Vous avez une course en cours — terminez-la avant de supprimer votre compte.';
  end if;
  update public.profiles set deleted_at = now() where id = auth.uid();
  if v_role = 'supplier_tiers' then
    update public.suppliers set deleted_at = now() where id = auth.uid();
    update public.supplier_collaborators
       set deactivated_at = now()
     where supplier_id = auth.uid() and deactivated_at is null;
  end if;
  -- Un collaborateur qui supprime son compte quitte aussi la boutique : sa
  -- ligne restait active, et son jeton encore valide l'opérait toujours
  -- (contre-vérification du 06/11/2026).
  update public.supplier_collaborators
     set deactivated_at = now()
   where user_id = auth.uid() and deactivated_at is null;
  -- Un livreur supprimé ne reçoit plus de course : hors ligne, suspendu, et
  -- l'offre qu'il avait sous les yeux repart au suivant.
  if v_role = 'livreur' then
    update public.couriers
       set is_online = false, status = 'suspended'
     where id = auth.uid();
    update public.deliveries
       set offer_expires_at = now()
     where offered_to_courier_id = auth.uid() and status = 'offered';
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
$function$;

-- Les équipes des boutiques déjà supprimées.
update public.supplier_collaborators c
   set deactivated_at = now()
  from public.suppliers s
 where s.id = c.supplier_id and s.deleted_at is not null and c.deactivated_at is null;

-- ------------------------------------- 5. l'annulation ferme la course MTC
create or replace function public.guard_cancel_after_pickup()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status <> 'cancelled' or old.status = 'cancelled'
     or auth.uid() is null or public.is_staff() then
    return new;
  end if;
  -- `for update` : un scan de retrait simultané attend que l'annulation soit
  -- jugée, ou l'annulation attend le scan — jamais les deux à la fois
  -- (contre-vérification du 06/11/2026).
  perform 1 from public.deliveries d where d.supplier_group_id = new.id for update;
  if exists (
    select 1 from public.deliveries d
     where d.supplier_group_id = new.id and d.status = 'picked_up'
  ) then
    raise exception
      'Le colis est déjà chez le livreur : l''annulation passe par MTC.';
  end if;
  return new;
end;
$$;

revoke all on function public.guard_cancel_after_pickup() from public, anon, authenticated;

drop trigger if exists order_supplier_groups_guard_cancel_after_pickup on public.order_supplier_groups;
create trigger order_supplier_groups_guard_cancel_after_pickup
  before update of status on public.order_supplier_groups
  for each row execute function public.guard_cancel_after_pickup();

create or replace function public.close_delivery_of_cancelled_group()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_courier uuid;
begin
  for v_courier in
    update public.deliveries
       set status = 'cancelled',
           offered_to_courier_id = null,
           offer_expires_at = null,
           courier_latitude = null,
           courier_longitude = null,
           courier_position_at = null
     where supplier_group_id = new.id
       and status in ('offered', 'accepted', 'picked_up')
    returning courier_id
  loop
    -- Le livreur qui l'avait acceptée l'apprend, au lieu de se rendre chez
    -- la boutique pour rien.
    if v_courier is not null then
      insert into public.notifications (id, user_id, type, title, body, reference_id)
      values (gen_random_uuid()::text, v_courier, 'delivery_status',
              'Course annulée', 'La commande ' || new.supplier_name || ' a été annulée.',
              new.order_id);
    end if;
  end loop;
  return null;
end;
$$;

revoke all on function public.close_delivery_of_cancelled_group() from public, anon, authenticated;

drop trigger if exists order_supplier_groups_close_cancelled_delivery on public.order_supplier_groups;
create trigger order_supplier_groups_close_cancelled_delivery
  after update of status on public.order_supplier_groups
  for each row
  when (new.status = 'cancelled' and old.status is distinct from 'cancelled')
  execute function public.close_delivery_of_cancelled_group();

-- Les courses restées ouvertes sur des groupes déjà annulés.
update public.deliveries d
   set status = 'cancelled',
       offered_to_courier_id = null,
       offer_expires_at = null,
       courier_latitude = null,
       courier_longitude = null,
       courier_position_at = null
  from public.order_supplier_groups g
 where g.id = d.supplier_group_id
   and g.status = 'cancelled'
   and d.status in ('offered', 'accepted', 'picked_up');
