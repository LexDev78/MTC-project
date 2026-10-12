-- Bug réel : sur une commande multi-fournisseurs, `update_order_group_status`
-- (0010) calculait le statut global de la commande avec
-- `bool_or(status = 'cancelled') then 'cancelled'` avant même de regarder
-- si les AUTRES groupes progressaient — un seul fournisseur qui refuse sa
-- part fait donc passer TOUTE la commande à "Annulée" côté client
-- (`OrderStatusStepper` remplace carrément le stepper par "Commande
-- annulée" dès que `order.status == cancelled`, `order_list_tile.dart`
-- pareil sur le badge), alors que les autres fournisseurs peuvent être
-- encore en train de préparer/livrer leur groupe. Le client voit sa
-- commande comme morte/bloquée alors qu'elle continue réellement.
--
-- Fix : un groupe annulé ne compte plus comme "annulé globalement" à moins
-- que TOUS les groupes le soient. Un mélange livré/annulé (tout ce qui
-- pouvait être livré l'a été, le reste a été refusé) compte comme livré —
-- il n'y a plus rien à attendre. Le reste de la cascade (statut le plus
-- avancé parmi les groupes non-annulés) est inchangé.
create or replace function public.update_order_group_status(
  p_order_id text,
  p_group_id text,
  p_status text,
  p_cancellation_reason text default null,
  p_cancelled_by text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_status public.order_status;
  v_group_supplier_id uuid;
  v_order_client_id uuid;
  v_new_status public.order_status := p_status::public.order_status;
  v_overall public.order_status;
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

  select
    case
      when bool_and(status = 'cancelled') then 'cancelled'
      when bool_and(status = 'delivered' or status = 'cancelled') then 'delivered'
      when bool_or(status = 'in_transit') then 'in_transit'
      when bool_or(status = 'preparing') then 'preparing'
      when bool_or(status = 'confirmed') then 'confirmed'
      else 'pending'
    end::public.order_status into v_overall
    from public.order_supplier_groups where order_id = p_order_id;

  update public.orders set status = v_overall where id = p_order_id;
end;
$$;
