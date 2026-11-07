-- Une course déjà livrée, posée d'un seul appel, pour les parcours visuels.
--
-- Les tours de captures s'intéressent à ce qui vient **après** la livraison
-- (l'historique du livreur, ses notes, la feuille de notation du client).
-- Y arriver par le vrai chemin demandait quatre sessions Supabase ouvertes
-- en même temps sur l'appareil — livreur, fournisseur, client, plus
-- l'administration — pour lire deux codes QR et les scanner. Cette
-- préparation se bloquait sans raison reproductible, et un parcours visuel
-- bloqué ne produit aucune image, donc ne dit rien.
--
-- Le chemin réel reste couvert là où il doit l'être : `delivery_codes_test`
-- fait les deux scans, vérifie l'ordre, le code déjà consommé et le code
-- faux. Ici on ne vérifie pas comment on arrive à `delivered` — on part de
-- là.
create or replace function public.test_seed_delivered_delivery(
  p_group_id text,
  p_courier_id uuid
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_id text;
  v_delivery_id text := gen_random_uuid()::text;
begin
  select order_id into v_order_id
    from public.order_supplier_groups where id = p_group_id;
  if v_order_id is null then
    raise exception 'Groupe introuvable : %', p_group_id;
  end if;

  -- La course d'abord : `guard_mtc_delivery_completion` (`0054`) refuse un
  -- groupe passé à `delivered` sans course remise.
  insert into public.deliveries (
    id, order_id, supplier_group_id, status, courier_id,
    offered_to_courier_id, offered_at, accepted_at, picked_up_at, delivered_at
  ) values (
    v_delivery_id, v_order_id, p_group_id, 'delivered', p_courier_id,
    p_courier_id, now() - interval '2 hours', now() - interval '110 minutes',
    now() - interval '90 minutes', now() - interval '30 minutes'
  )
  on conflict (supplier_group_id) do update
    set status = 'delivered',
        courier_id = excluded.courier_id,
        accepted_at = excluded.accepted_at,
        picked_up_at = excluded.picked_up_at,
        delivered_at = excluded.delivered_at
  returning id into v_delivery_id;

  update public.order_supplier_groups
     set status = 'delivered' where id = p_group_id;

  return v_delivery_id;
end;
$$;

revoke all on function public.test_seed_delivered_delivery(text, uuid)
  from public, anon, authenticated;
