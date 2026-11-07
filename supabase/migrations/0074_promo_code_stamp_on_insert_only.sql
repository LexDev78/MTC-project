-- Le propriétaire d'un code se pose à sa création, pas à chaque écriture.
--
-- `stamp_promo_code_supplier` (`0071`) s'exécutait aussi sur `UPDATE`, et
-- réclamait donc un compte fournisseur à **toute** modification de la ligne.
-- Or `place_order` incrémente `uses_count` sous la session du **client** :
-- la commande échouait sur « Réservé à un compte fournisseur », au moment
-- précis où le code devait servir.
--
-- Le défaut ne se voyait pas côté fournisseur, où tout fonctionnait. Il a
-- fallu une commande réelle pour le faire apparaître.
create or replace function public.stamp_promo_code_supplier()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    new.supplier_id := public.operating_supplier_id();
    if new.supplier_id is null then
      raise exception 'Réservé à un compte fournisseur.';
    end if;
  else
    -- Une mise à jour ne change jamais de propriétaire : ni le fournisseur
    -- qui arrête son code, ni la commande qui consomme une utilisation.
    new.supplier_id := old.supplier_id;
  end if;

  new.code := upper(btrim(new.code));
  return new;
end;
$$;
