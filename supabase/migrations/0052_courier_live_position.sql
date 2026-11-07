-- Position du livreur en direct, pour que le client suive sa livraison.
--
-- La position est écrite **sur la course**, pas lue depuis `couriers` :
--
--  * la fiche d'un livreur n'est visible que de lui-même et du staff
--    (`couriers_select_self_or_staff`, `0046`), et l'ouvrir au client
--    reviendrait à lui montrer la position de livreurs qui ne lui livrent
--    rien ;
--  * portée sur la course, la position n'est visible que des participants de
--    cette course (`deliveries_select_participants`), c'est-à-dire ce client
--    précis, le fournisseur concerné et le staff ;
--  * elle disparaît à la livraison (voir plus bas) : le client suit son
--    colis, il ne suit pas une personne.
--
-- `deliveries` est déjà publiée en Realtime (`0046`), donc chaque position
-- poussée arrive seule sur la carte du client, sans qu'il rafraîchisse.

alter table public.deliveries
  add column if not exists courier_latitude double precision,
  add column if not exists courier_longitude double precision,
  add column if not exists courier_position_at timestamptz;

-- ============================================================================
-- Pousser sa position
-- ============================================================================
-- Un seul appel met à jour les deux usages : la fiche du livreur (qui sert à
-- l'attribution au plus proche) et sa course en cours (qui sert au suivi
-- client). Les séparer obligerait l'app à faire deux écritures à chaque pas.
create or replace function public.push_courier_position(
  p_latitude double precision,
  p_longitude double precision
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_courier() then
    raise exception 'Réservé aux livreurs.';
  end if;

  update public.couriers
     set last_latitude = p_latitude,
         last_longitude = p_longitude,
         last_position_at = now()
   where id = auth.uid();

  -- Seulement la course réellement en cours : une course terminée ou refusée
  -- ne doit plus rien apprendre de l'endroit où se trouve le livreur.
  update public.deliveries
     set courier_latitude = p_latitude,
         courier_longitude = p_longitude,
         courier_position_at = now()
   where courier_id = auth.uid()
     and status in ('accepted', 'picked_up');
end;
$$;

revoke all on function public.push_courier_position(double precision, double precision)
  from public, anon;
grant execute on function public.push_courier_position(double precision, double precision)
  to authenticated;

-- ============================================================================
-- Effacer la position à la livraison
-- ============================================================================
-- Reprend `scan_delivery_code` (`0051`) en ajoutant l'oubli de la position
-- une fois la remise accusée. Sans ça, la dernière position connue du livreur
-- — c'est-à-dire **le domicile du client** — resterait lisible par le
-- fournisseur sur une course terminée.
create or replace function public.scan_delivery_code(
  p_delivery_id text,
  p_code text
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delivery public.deliveries;
  v_kind public.delivery_code_kind;
  v_new_status public.delivery_status;
begin
  select * into v_delivery from public.deliveries where id = p_delivery_id for update;
  if v_delivery is null or v_delivery.courier_id is distinct from auth.uid() then
    raise exception 'Cette course ne vous est pas confiée.';
  end if;

  v_kind := case v_delivery.status
    when 'accepted' then 'pickup'::public.delivery_code_kind
    when 'picked_up' then 'delivery'::public.delivery_code_kind
    else null
  end;
  if v_kind is null then
    raise exception 'Cette course n''attend aucun scan.';
  end if;

  update public.delivery_codes
     set consumed_at = now(), consumed_by = auth.uid()
   where delivery_id = p_delivery_id
     and kind = v_kind
     and code = p_code
     and consumed_at is null;

  if not found then
    raise exception 'Code invalide ou déjà utilisé.';
  end if;

  v_new_status := case v_kind
    when 'pickup' then 'picked_up'::public.delivery_status
    else 'delivered'::public.delivery_status
  end;

  update public.deliveries
     set status = v_new_status,
         picked_up_at = case when v_kind = 'pickup' then now() else picked_up_at end,
         delivered_at = case when v_kind = 'delivery' then now() else delivered_at end,
         courier_latitude = case when v_kind = 'delivery' then null else courier_latitude end,
         courier_longitude = case when v_kind = 'delivery' then null else courier_longitude end,
         courier_position_at = case when v_kind = 'delivery' then null else courier_position_at end
   where id = p_delivery_id;

  if v_kind = 'delivery' then
    update public.order_supplier_groups
       set status = 'delivered'
     where id = v_delivery.supplier_group_id;
  end if;

  return v_new_status::text;
end;
$$;
