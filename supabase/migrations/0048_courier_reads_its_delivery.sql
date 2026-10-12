-- Un livreur doit pouvoir lire la commande qu'il transporte.
--
-- Sans ça, la course lui est bien visible (policy `deliveries_select_participants`,
-- `0046`) mais tout ce qui l'entoure — commande, groupe fournisseur, lignes —
-- lui est fermé. PostgREST ne refuse pas pour autant la requête imbriquée :
-- il renvoie les sous-objets **vides**. La feuille de route arrivait donc
-- sans fournisseur, sans client et sans adresse, sans qu'aucune erreur ne le
-- signale.
--
-- Les trois policies passent par des fonctions `security definer` plutôt que
-- d'interroger `deliveries` directement : la policy de `deliveries` lit déjà
-- `orders` et `order_supplier_groups`, donc une policy de `orders` qui
-- relirait `deliveries` boucle ("infinite recursion detected in policy").
-- Une fonction `security definer` n'est pas soumise au RLS en son sein, ce
-- qui casse le cycle.
--
-- Portée volontairement étroite : seulement la commande d'une course qui
-- **m'est proposée ou confiée**, et seulement en lecture. Un livreur ne voit
-- donc rien du reste du catalogue de commandes, et son accès disparaît avec
-- la course (refus, expiration, réattribution).

create or replace function public.courier_can_see_order(p_order_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.deliveries d
     where d.order_id = p_order_id
       and (d.courier_id = auth.uid() or d.offered_to_courier_id = auth.uid())
  );
$$;

create or replace function public.courier_can_see_group(p_group_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.deliveries d
     where d.supplier_group_id = p_group_id
       and (d.courier_id = auth.uid() or d.offered_to_courier_id = auth.uid())
  );
$$;

create policy "orders_select_courier" on public.orders
  for select using (public.courier_can_see_order(id));

create policy "order_supplier_groups_select_courier" on public.order_supplier_groups
  for select using (public.courier_can_see_group(id));

create policy "order_items_select_courier" on public.order_items
  for select using (public.courier_can_see_group(group_id));

-- `suppliers` est déjà en lecture publique (`suppliers_select_public`) : le
-- point de retrait ne demande aucune ouverture supplémentaire.
