-- Deux retraits simultanés pouvaient vider la caisse deux fois.
--
-- `guard_payout_amount` (`0033`) recalcule le solde disponible avant
-- d'accepter une demande — c'était déjà la bonne idée, et elle a fermé la
-- faille d'un montant arbitraire. Mais elle lisait sans verrou.
--
-- Sous READ COMMITTED, deux demandes qui se croisent voient chacune l'état
-- d'avant l'autre : même brut, même total déjà versé, donc même solde
-- disponible. Les deux passent. Un double clic suffit, et deux téléphones
-- encore mieux.
--
-- Mesuré avant correction, dans `security_audit_test.dart` : deux demandes
-- du solde entier, lancées en parallèle, étaient acceptées toutes les deux.
--
-- La fonction est reprise **de la base**, pas récrite : seul le verrou est
-- ajouté.

CREATE OR REPLACE FUNCTION public.guard_payout_amount()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_gross integer;
  v_rate double precision;
  v_commission integer;
  v_net integer;
  v_paid_out integer;
  v_available integer;
begin
  -- `auth.uid() is null` : seed/harnais de test (`0002`/`0020` insèrent des
  -- demandes de retrait de démo indépendantes des commandes seedées) —
  -- même repli que les autres gardes de cet audit.
  if auth.uid() is null then
    return new;
  end if;

  -- Verrou sur la fiche de la boutique, **avant** de calculer le solde.
  --
  -- Sans lui, deux demandes simultanées lisent le même `payout_requests`
  -- (READ COMMITTED : chacune voit l'état d'avant l'autre), calculent le
  -- même disponible, et passent toutes les deux. Mesuré : deux demandes du
  -- solde entier étaient acceptées, et la boutique payée deux fois.
  --
  -- Le verrou sérialise les demandes d'une même boutique. Celles de
  -- boutiques différentes ne se gênent pas : la ligne verrouillée n'est pas
  -- la même.
  --
  -- Même remède que `0080` pour les codes promo et les notes de livreurs.
  perform 1 from public.suppliers where id = new.supplier_id for update;

  if new.amount_fcfa <= 0 then
    raise exception 'Le montant demandé doit être positif.';
  end if;

  select coalesce(sum(subtotal_fcfa), 0) into v_gross
    from public.order_supplier_groups
    where supplier_id = new.supplier_id and status = 'delivered';

  select commission_rate_percent into v_rate
    from public.supplier_finance_settings where supplier_id = new.supplier_id;
  v_rate := coalesce(v_rate, 10.0);

  v_commission := round((v_gross * v_rate / 100)::numeric)::integer;
  v_net := v_gross - v_commission;

  select coalesce(sum(amount_fcfa), 0) into v_paid_out
    from public.payout_requests
    where supplier_id = new.supplier_id and status <> 'rejected';

  v_available := v_net - v_paid_out;

  if new.amount_fcfa > v_available then
    raise exception 'Montant demandé (% FCFA) supérieur au solde disponible (% FCFA).',
      new.amount_fcfa, v_available;
  end if;

  return new;
end;
$function$;
