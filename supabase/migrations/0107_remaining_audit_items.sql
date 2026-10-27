-- Les quatre points que l'audit avait signalés sans les corriger.
--
-- Aucun n'ouvre l'accès d'un rôle à un autre — c'est pourquoi ils étaient
-- restés en attente d'un arbitrage. L'arbitrage est rendu : on les ferme.

-- ===========================================================================
-- 1. Le compteur de vues était gonflable à volonté.
-- ===========================================================================
--
-- Mesuré : vingt-cinq appels, vingt-cinq vues, sur n'importe quel produit.
--
--   select view_count from products where id=…;            -- 0
--   select increment_product_view(…) from generate_series(1,25);
--   select view_count from products where id=…;            -- 25
--
-- Le tableau de bord du fournisseur affiche « visionnage des produits » : la
-- statistique était donc déclarative, et un concurrent pouvait aussi bien
-- gonfler le chiffre d'un voisin que le sien.
--
-- Ce que cela change pour la mesure, dit franchement : `view_count` ne
-- compte plus les affichages, il compte les **personnes par jour**. C'est un
-- nombre plus petit et plus utile — « combien de gens ont regardé » plutôt
-- que « combien de fois l'écran s'est ouvert », une distinction qui compte
-- quand on recharge trois fois une fiche sur un réseau lent.
--
-- Le journal d'activité (`user_activity_events`, `0081`) porte déjà un genre
-- `product_view`, mais il est écrit par un **autre** appel de l'app. S'y
-- adosser rendrait le compteur dépendant de l'ordre des deux appels : si la
-- trace partait la première, le compteur ne bougerait plus jamais. D'où une
-- mémoire qui lui est propre.

create table if not exists public.product_view_marks (
  product_id text not null references public.products(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  viewed_on date not null default (now() at time zone 'utc')::date,
  primary key (product_id, user_id, viewed_on)
);

alter table public.product_view_marks enable row level security;

-- Aucune politique : la table n'est lisible ni écrivable par personne. Elle
-- n'existe que pour `increment_product_view`, qui est `security definer` et
-- passe donc outre. Rien dans l'app n'a à la consulter.
comment on table public.product_view_marks is
  'Mémoire du compteur de vues : une marque par personne, produit et jour. '
  'Propriété exclusive de increment_product_view().';

create or replace function public.increment_product_view(p_product_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    return;
  end if;

  -- La marque **d'abord** : `on conflict do nothing` ne fait rien si cette
  -- personne a déjà regardé ce produit aujourd'hui, et `found` est alors
  -- faux. Le compteur ne bouge que sur une première fois.
  insert into public.product_view_marks (product_id, user_id)
  values (p_product_id, v_user_id)
  on conflict do nothing;

  if not found then
    return;
  end if;

  perform set_config('app.trusted_product_write', 'on', true);
  update public.products set view_count = view_count + 1 where id = p_product_id;
exception
  -- Produit supprimé entre l'affichage et l'appel : la vue est perdue, le
  -- parcours continue. Même choix que `log_activity_event`.
  when foreign_key_violation then return;
end;
$$;

-- ===========================================================================
-- 2. `order_client_id` rendait un identifiant là où un oui/non suffisait.
-- ===========================================================================
--
-- La fonction est `security definer` et appelable par `anon` : quiconque
-- connaissait un identifiant de commande obtenait l'identifiant du client.
--
--   select order_client_id('222a8eb1-…');
--   -- 04060d99-e34d-520e-8b75-631ff4d3c10c
--
-- L'exposition était faible — un uuid d'utilisateur n'ouvre rien, toutes les
-- tables se cloisonnent sur `auth.uid()` — mais elle était **inutile** : les
-- deux politiques qui l'appelaient écrivaient
--
--   order_client_id(order_id) = auth.uid()
--
-- c'est-à-dire « suis-je le client de cette commande ? ». Une question qui
-- se répond par un booléen. On ne peut pas, en revanche, écrire la
-- sous-requête directement dans la politique : elle lirait `orders`, dont la
-- RLS cache la ligne au fournisseur — c'est précisément pour cela que le
-- `security definer` existe. Il reste donc, en ne rendant plus que l'aveu.

create or replace function public.order_belongs_to_me(p_order_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.orders
     where id = p_order_id and client_id = auth.uid()
  );
$$;

grant execute on function public.order_belongs_to_me(text) to anon, authenticated;

drop policy if exists order_supplier_groups_select_visible on public.order_supplier_groups;
create policy order_supplier_groups_select_visible on public.order_supplier_groups
  for select
  using (
    supplier_id = public.operating_supplier_id()
    or public.order_belongs_to_me(order_id)
    or public.is_admin()
  );

drop policy if exists order_items_select_visible on public.order_items;
create policy order_items_select_visible on public.order_items
  for select
  using (
    exists (
      select 1 from public.order_supplier_groups g
       where g.id = order_items.group_id
         and (
           g.supplier_id = public.operating_supplier_id()
           or public.order_belongs_to_me(g.order_id)
           or public.is_admin()
         )
    )
  );

-- Plus aucun appelant hors `security definer` : on referme. La fonction
-- n'est pas supprimée — une migration qui la rétablirait par mégarde est
-- moins grave qu'une dépendance oubliée qui casse.
revoke all on function public.order_client_id(text) from public, anon, authenticated;

-- ===========================================================================
-- 3. Le concierge des courses était appelable par n'importe qui.
-- ===========================================================================
--
-- `reoffer_expired_deliveries` reproposait les courses dont l'offre a
-- expiré. Son effet est borné par le temps — elle ne touche que des offres
-- déjà périmées, donc l'appeler tôt ne fait rien — et l'app l'appelle
-- elle-même quand un livreur tire sa liste (`courier_home_screen`). Mais
-- elle écrit dans `deliveries` et ajoute des livreurs à
-- `declined_courier_ids` : un client ou un fournisseur n'a aucune raison de
-- pouvoir la déclencher.
create or replace function public.reoffer_expired_deliveries()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delivery record;
  v_count integer := 0;
begin
  -- Ajouté : le concierge est celui qui attend des courses, ou MTC.
  if not (public.is_courier() or public.is_staff()) then
    raise exception 'Réservé aux livreurs et au staff MTC.';
  end if;

  for v_delivery in
    select id, offered_to_courier_id from public.deliveries
     where status = 'offered'
       and (offer_expires_at is null or offer_expires_at < now())
  loop
    if v_delivery.offered_to_courier_id is not null then
      update public.deliveries
         set declined_courier_ids =
               array_append(declined_courier_ids, v_delivery.offered_to_courier_id),
             offered_to_courier_id = null
       where id = v_delivery.id;
    end if;
    perform public.offer_delivery_to_next_courier(v_delivery.id);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- ===========================================================================
-- 4. Le modèle d'empreintes qui sert n'a pas à être public.
-- ===========================================================================
--
-- `serving_embedding_model()` nomme le modèle en service. Ses deux
-- appelantes — `search_products_by_embedding` et
-- `products_needing_embedding` — sont `security definer` : elles s'exécutent
-- sous leur propriétaire et continueront de l'appeler. Aucune session n'en a
-- besoin, et rien dans l'app ni dans les fonctions edge ne la nomme.
revoke all on function public.serving_embedding_model() from public, anon, authenticated;

-- ===========================================================================
-- 5. Deux paramètres que `place_order` ignore : qu'on le sache en la lisant.
-- ===========================================================================
--
-- `p_priority_fee_fcfa` est ignoré depuis longtemps (le supplément est
-- calculé côté serveur), et `p_payment_status` l'est depuis `0106`. Tous
-- deux restent dans la signature pour ne pas casser une version plus ancienne
-- de l'app. Un paramètre ignoré et muet est un piège pour qui lira la
-- fonction dans six mois : il le dit maintenant lui-même.
comment on function public.place_order(
  text, text, jsonb, text, text, text, double precision, double precision,
  text, text, text, timestamp with time zone, text, boolean, integer,
  text, text, text, integer, text, text, text, text
) is
  'Crée une commande. ATTENTION : p_priority_fee_fcfa et p_payment_status '
  'sont acceptés mais IGNORÉS. Le supplément de priorité est calculé ici, et '
  'le statut de paiement est toujours pending_on_delivery — seul '
  'mark_order_paid() (staff) peut dire une commande payée. Voir 0106.';
