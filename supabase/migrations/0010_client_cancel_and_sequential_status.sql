-- Remplace `update_order_group_status` (0003_orders_rpc.sql) pour deux
-- règles métier nouvelles :
--   1. Le client peut désormais annuler lui-même SON groupe tant qu'il est
--      encore `pending` (avant acceptation par le fournisseur) — jusqu'ici
--      la fonction n'autorisait que le fournisseur propriétaire du groupe
--      (`operating_supplier_id()`), le client n'avait aucun chemin d'écriture.
--   2. Un fournisseur ne peut plus sauter d'étape : chaque transition vers
--      l'avant doit désormais viser l'étape immédiatement suivante dans
--      `v_forward_order` (fini le saut direct `pending` → `in_transit`).
-- Mirroir exact de `isValidTransition`/`canClientCancel`
-- (order_status_transitions.dart).
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

  -- Le fournisseur propriétaire du groupe peut le faire avancer ou
  -- l'annuler (les règles de transition ci-dessous s'appliquent ensuite
  -- aux deux). Si l'appelant n'est pas ce fournisseur, le seul autre cas
  -- légitime est le client de la commande qui annule SON groupe encore
  -- `pending` — tout le reste est refusé.
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
  -- Chaque étape doit être confirmée dans l'ordre — plus de saut direct
  -- d'une étape à une autre non consécutive.
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
      when bool_and(status = 'delivered') then 'delivered'
      when bool_or(status = 'cancelled') then 'cancelled'
      when bool_or(status = 'in_transit') then 'in_transit'
      when bool_or(status = 'preparing') then 'preparing'
      when bool_or(status = 'confirmed') then 'confirmed'
      else 'pending'
    end::public.order_status into v_overall
    from public.order_supplier_groups where order_id = p_order_id;

  update public.orders set status = v_overall where id = p_order_id;
end;
$$;
