-- Une livraison MTC se clôt par le scan du client, pas par un bouton du
-- fournisseur.
--
-- Le fournisseur gardait la main sur tout le cycle, y compris « Livrée » —
-- hérité de l'époque où il livrait lui-même. Depuis que MTC prend en charge
-- ces courses, c'est faux : il ne sait pas quand le colis arrive chez le
-- client, et la preuve existe ailleurs (le QR scanné à la remise,
-- `0051_delivery_codes.sql`).
--
-- Le laisser cliquer, c'était :
--
--  * lui faire déclarer un fait qu'il ne constate pas — et qu'il a intérêt à
--    déclarer tôt, le paiement du groupe en dépendant ;
--  * permettre de clore une commande que le livreur n'a jamais remise, donc
--    de contourner l'accusé de réception du client.
--
-- La garde est côté base : l'écran retire le bouton, mais un appel direct à
-- l'API est refusé de la même façon.

create or replace function public.guard_mtc_delivery_completion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status <> 'delivered' or old.status = 'delivered' then
    return new;
  end if;
  if new.delivery_mode <> 'mtc_delivery' then
    return new;
  end if;

  -- La course elle-même passe par ici : `scan_delivery_code` met la course à
  -- `delivered` puis le groupe. On autorise donc le passage quand la course
  -- est déjà close — c'est-à-dire quand le client a bien scanné.
  if exists (
    select 1 from public.deliveries d
     where d.supplier_group_id = new.id and d.status = 'delivered'
  ) then
    return new;
  end if;

  -- Aucune course : commande confiée à MTC mais jamais remise à un livreur.
  -- Rien à clore.
  raise exception
    'Cette commande est livrée par MTC : elle se clôt quand le client scanne son code de remise.';
end;
$$;

create trigger order_supplier_groups_guard_mtc_completion
  before update of status on public.order_supplier_groups
  for each row execute function public.guard_mtc_delivery_completion();
