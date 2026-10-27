-- Corrige les findings moyens/faibles restants de l'audit :
--
-- 1) MOYEN — `notifications_insert_authenticated` (0006) autorisait
--    n'importe quel compte authentifié à créer une notification pour
--    N'IMPORTE QUEL `user_id`, avec un titre/corps entièrement libres —
--    testé et confirmé : un client peut injecter dans le fil d'un autre
--    compte un message imitant une notification système officielle
--    ("Compte suspendu, contactez-nous avec votre mot de passe"). Les 3
--    types qui prétendent à une décision officielle de la plateforme
--    (`kyc_decision`, `payout_decision`, `characteristic_type_decision`)
--    sont les seuls réellement dangereux pour l'ingénierie sociale — et
--    dans l'app réelle, ils ne sont déjà créés QUE par du staff
--    (`KycReviewController`, `SupplierFinanceController.reviewPayout`,
--    `CharacteristicTypeReviewController`). Les 6 autres types restent
--    ouverts (spam possible mais pas d'usurpation d'autorité plateforme) —
--    même arbitrage que 0006, resserré seulement là où il comptait.
--
-- 2) MOYEN — `payout_requests_insert_own` ne validait que la propriété
--    (`supplier_id = operating_supplier_id()`), jamais le montant demandé
--    contre le solde réellement disponible — seul `SupplierFinanceController`
--    (Dart, contournable) le faisait. Remède : un trigger qui rejoue le
--    calcul de `computeFinancialSummary`
--    (`lib/features/supplier_finance/domain/compute_financial_summary.dart`)
--    côté serveur avant d'accepter la demande.
--
-- 3) FAIBLE — aucun bucket Storage n'avait de `file_size_limit`/
--    `allowed_mime_types` : upload de fichiers arbitraires (taille, type)
--    possible sur des buckets publics, avec risque d'abus de stockage et
--    d'hébergement de contenu arbitraire sous le domaine de confiance de
--    l'app. Limites alignées sur les seuls types réellement produits par
--    l'app (`image_picker`, notes vocales `audio/mp4` via `record`).

drop policy if exists "notifications_insert_authenticated" on public.notifications;
create policy "notifications_insert_authenticated" on public.notifications
  for insert with check (
    type not in ('kyc_decision', 'payout_decision', 'characteristic_type_decision')
    or public.is_staff()
  );

-- ----------------------------------------------------------------------------
-- Garde montant `payout_requests` : ne jamais dépasser le solde disponible,
-- recalculé côté serveur (miroir de `computeFinancialSummary`).
-- ----------------------------------------------------------------------------
create or replace function public.guard_payout_amount()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
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
$$;

drop trigger if exists payout_requests_guard_amount on public.payout_requests;
create trigger payout_requests_guard_amount
  before insert on public.payout_requests
  for each row
  execute function public.guard_payout_amount();

-- ----------------------------------------------------------------------------
-- Limites Storage : taille + type MIME par bucket.
-- ----------------------------------------------------------------------------
update storage.buckets set
  file_size_limit = 10 * 1024 * 1024,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id = 'kyc-documents';

update storage.buckets set
  file_size_limit = 5 * 1024 * 1024,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id in ('product-images', 'supplier-branding', 'comment-attachments');

update storage.buckets set
  file_size_limit = 10 * 1024 * 1024,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'audio/mp4']
where id = 'chat-attachments';

update storage.buckets set
  file_size_limit = 5 * 1024 * 1024,
  allowed_mime_types = array['audio/mp4']
where id = 'order-messages';
