-- Une commande livrée par le livreur restait « en cours de livraison ».
--
-- `orders.status` résume les groupes de la commande, un par fournisseur :
-- livrée quand tous le sont, en cours de livraison dès qu'un l'est, etc.
-- Ce résumé n'était recalculé que dans `update_order_group_status`, le
-- chemin du fournisseur. Or c'est le scan du livreur (`scan_delivery_code`,
-- `0051`) qui clôt un groupe livré par MTC : il passait le groupe à
-- `delivered` sans toucher la commande. Constaté le 18/10/2026 : commande
-- `b84bf036…`, groupe et course livrés à 08:00:18, commande restée
-- `in_transit` — et côté client, « en cours de livraison » pour une commande
-- reçue.
--
-- Le résumé est désormais tenu par un déclencheur sur les groupes : tout
-- chemin qui change le statut d'un groupe — fournisseur, livreur,
-- annulation, et ceux à venir — recalcule la commande. La règle n'existe
-- plus qu'à un endroit, `order_overall_status`.

create or replace function public.order_overall_status(p_order_id text)
returns public.order_status
language sql
stable
set search_path = ''
as $$
  select case
    when bool_and(status = 'cancelled') then 'cancelled'
    when bool_and(status = 'delivered' or status = 'cancelled') then 'delivered'
    when bool_or(status = 'in_transit') then 'in_transit'
    when bool_or(status = 'preparing') then 'preparing'
    when bool_or(status = 'confirmed') then 'confirmed'
    else 'pending'
  end::public.order_status
  from public.order_supplier_groups
  where order_id = p_order_id;
$$;

create or replace function public.sync_order_status_from_groups()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Écrit même quand le résumé ne change pas : la ligne de la commande est
  -- ce qu'écoute le flux Realtime du client (`watchOrderById`). C'est ainsi
  -- qu'il voit aussi avancer un groupe dans une commande à plusieurs
  -- fournisseurs, quand le résumé, lui, reste « en cours de livraison ».
  update public.orders
     set status = public.order_overall_status(new.order_id)
   where id = new.order_id;
  return null;
end;
$$;

drop trigger if exists order_supplier_groups_sync_order_status
  on public.order_supplier_groups;
create trigger order_supplier_groups_sync_order_status
  after update of status on public.order_supplier_groups
  for each row
  when (old.status is distinct from new.status)
  execute function public.sync_order_status_from_groups();

revoke all on function public.order_overall_status(text) from public, anon, authenticated;
revoke all on function public.sync_order_status_from_groups() from public, anon, authenticated;

-- La fonction du fournisseur, sans son propre calcul du résumé : le
-- déclencheur s'en charge. Reprise de sa définition en base, ce bloc seul
-- retiré.
CREATE OR REPLACE FUNCTION public.update_order_group_status(p_order_id text, p_group_id text, p_status text, p_cancellation_reason text DEFAULT NULL::text, p_cancelled_by text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_current_status public.order_status;
  v_group_supplier_id uuid;
  v_order_client_id uuid;
  v_new_status public.order_status := p_status::public.order_status;
  v_forward_order constant public.order_status[] :=
    array['pending', 'confirmed', 'preparing', 'in_transit', 'delivered']::public.order_status[];
begin
  select g.status, g.supplier_id, o.client_id
    into v_current_status, v_group_supplier_id, v_order_client_id
    from public.order_supplier_groups g
    join public.orders o on o.id = g.order_id
    where g.id = p_group_id and g.order_id = p_order_id;

  if v_current_status is null then
    raise exception 'Groupe fournisseur introuvable : %', p_group_id;
  end if;

  if v_group_supplier_id is distinct from public.operating_supplier_id() then
    if v_order_client_id is distinct from auth.uid()
       or v_new_status != 'cancelled'
       or v_current_status != 'pending' then
      raise exception 'Non autorisé à modifier ce groupe.';
    end if;
  end if;

  if v_current_status = v_new_status
     or v_current_status = 'delivered' or v_current_status = 'cancelled' then
    raise exception 'Transition invalide : % → %.', v_current_status, v_new_status;
  end if;
  if v_new_status != 'cancelled'
     and array_position(v_forward_order, v_new_status)
         != array_position(v_forward_order, v_current_status) + 1 then
    raise exception 'Transition invalide : % → %.', v_current_status, v_new_status;
  end if;

  update public.order_supplier_groups set
    status = v_new_status,
    cancellation_reason = case when v_new_status = 'cancelled' then p_cancellation_reason else null end,
    cancelled_by = case when v_new_status = 'cancelled' then p_cancelled_by::public.cancelled_by else null end
  where id = p_group_id;

  -- Le résumé de la commande (`orders.status`) suit : le déclencheur
  -- `order_supplier_groups_sync_order_status` le recalcule (`0112`).
end;
$function$;

-- Les commandes déjà bloquées : livrées par le livreur avant ce correctif.
update public.orders o
   set status = public.order_overall_status(o.id)
 where exists (select 1 from public.order_supplier_groups g where g.order_id = o.id)
   and o.status is distinct from public.order_overall_status(o.id);
