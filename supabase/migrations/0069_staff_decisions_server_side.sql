-- Les trois décisions du staff rejoignent le serveur, et plus personne
-- n'insère de notification.
--
-- `0064` a fait produire par la base toutes les notifications issues d'une
-- action de client ou de fournisseur. Restaient les trois décisions du
-- staff — dossier de vérification, versement, type de caractéristique —
-- encore écrites par l'app, et la policy d'insertion restait donc ouverte à
-- `is_staff()`. Le risque était moindre (compte de confiance) mais la
-- surface restait : un titre et un texte arbitraires, à n'importe quel
-- destinataire, dès qu'un compte staff est compromis ou qu'un écran se
-- trompe de destinataire.
--
-- Le gain n'est pas que là. La validation d'un dossier faisait **cinq**
-- écritures depuis l'app : le dossier, la fiche fournisseur, ses produits,
-- et la notification. Un échec au milieu laissait un dossier approuvé dont
-- les produits restaient invisibles — exactement l'état qu'aucun écran ne
-- sait rattraper. Les cinq tiennent maintenant dans une transaction.
--
-- Après cette migration, `notifications` n'a plus **aucune** policy
-- d'insertion : seules les fonctions `security definer` écrivent, puisque
-- RLS ne s'applique pas à leur propriétaire.

create or replace function public.review_supplier_kyc(
  p_kyc_id text,
  p_approve boolean,
  p_reason text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supplier_id uuid;
begin
  if not public.is_staff() then
    raise exception 'Réservé au staff MTC.';
  end if;
  if not p_approve and coalesce(btrim(coalesce(p_reason, '')), '') = '' then
    raise exception 'Un refus doit être motivé.';
  end if;

  update public.supplier_kyc
     set status = (case when p_approve then 'approved' else 'rejected' end)
                  ::public.kyc_review_status,
         reviewed_at = now(),
         reviewed_by_staff_id = auth.uid(),
         rejection_reason = case when p_approve then null else p_reason end
   where id = p_kyc_id
   returning supplier_id into v_supplier_id;

  if v_supplier_id is null then
    raise exception 'Dossier introuvable : %', p_kyc_id;
  end if;

  -- La fiche et les produits suivent la décision dans la même transaction.
  -- `is_supplier_verified` est recopié sur les produits pour que les
  -- requêtes du catalogue n'aient pas à joindre `suppliers`.
  update public.suppliers
     set verification_status = (
           case when p_approve then 'verified' else 'rejected' end
         )::public.verification_status
   where id = v_supplier_id;

  update public.products
     set is_supplier_verified = p_approve
   where supplier_id = v_supplier_id;

  insert into public.notifications (id, user_id, type, title, body, reference_id)
  values (
    gen_random_uuid()::text,
    v_supplier_id,
    'kyc_decision',
    case when p_approve then 'Dossier approuvé' else 'Dossier refusé' end,
    case
      when p_approve then 'Votre vérification a été validée.'
      else p_reason
    end,
    p_kyc_id
  );
end;
$$;

revoke all on function public.review_supplier_kyc(text, boolean, text)
  from public, anon;
grant execute on function public.review_supplier_kyc(text, boolean, text)
  to authenticated;

create or replace function public.review_characteristic_type(
  p_id text,
  p_approve boolean,
  p_reason text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_proposed_by uuid;
begin
  if not public.is_staff() then
    raise exception 'Réservé au staff MTC.';
  end if;
  if not p_approve and coalesce(btrim(coalesce(p_reason, '')), '') = '' then
    raise exception 'Un refus doit être motivé.';
  end if;

  update public.product_characteristic_types
     set status = (case when p_approve then 'approved' else 'rejected' end)
                  ::public.characteristic_type_status,
         reviewed_at = now(),
         reviewed_by_staff_id = auth.uid(),
         rejection_reason = case when p_approve then null else p_reason end
   where id = p_id
   returning proposed_by_supplier_id into v_proposed_by;

  if not found then
    raise exception 'Type de caractéristique introuvable : %', p_id;
  end if;

  -- Un type pré-approuvé n'a pas d'auteur à prévenir (`0017`).
  if v_proposed_by is null then return; end if;

  insert into public.notifications (id, user_id, type, title, body, reference_id)
  values (
    gen_random_uuid()::text,
    v_proposed_by,
    'characteristic_type_decision',
    case
      when p_approve then 'Caractéristique approuvée'
      else 'Caractéristique refusée'
    end,
    case
      when p_approve then 'Votre proposition de caractéristique a été validée.'
      else p_reason
    end,
    p_id
  );
end;
$$;

revoke all on function public.review_characteristic_type(text, boolean, text)
  from public, anon;
grant execute on function public.review_characteristic_type(text, boolean, text)
  to authenticated;

-- Reprise de `update_payout_status` (`0005`) : mêmes contrôles de
-- transition, la notification en plus. Elle part donc avec l'écriture
-- qu'elle annonce, et non dans un second appel qui pouvait échouer après
-- qu'un versement a été marqué payé.
create or replace function public.update_payout_status(
  p_payout_id text,
  p_status text,
  p_rejection_reason text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current public.payout_status;
  v_supplier_id uuid;
  v_amount integer;
begin
  if not public.is_admin() then
    raise exception 'Non autorisé à modifier ce retrait.';
  end if;

  select status, supplier_id, amount_fcfa
    into v_current, v_supplier_id, v_amount
    from public.payout_requests where id = p_payout_id;
  if v_current is null then
    raise exception 'Retrait introuvable.';
  end if;

  if (v_current = 'requested' and p_status not in ('processing', 'rejected'))
    or (v_current = 'processing' and p_status not in ('paid', 'rejected'))
    or v_current in ('paid', 'rejected')
  then
    raise exception 'Transition invalide : % → %.', v_current, p_status;
  end if;

  update public.payout_requests set
    status = p_status::public.payout_status,
    processed_at = now(),
    rejection_reason = case when p_status = 'rejected' then p_rejection_reason else null end
  where id = p_payout_id;

  -- Mêmes libellés que ceux que le fournisseur lit dans ses versements
  -- (`PayoutStatus.label`).
  insert into public.notifications (id, user_id, type, title, body, reference_id)
  values (
    gen_random_uuid()::text,
    v_supplier_id,
    'payout_decision',
    'Retrait ' || lower(case p_status
      when 'requested' then 'Demandé'
      when 'processing' then 'En traitement'
      when 'paid' then 'Payé'
      when 'rejected' then 'Rejeté'
    end),
    case
      when p_status = 'rejected' and coalesce(p_rejection_reason, '') <> ''
        then p_rejection_reason
      else v_amount || ' FCFA'
    end,
    p_payout_id
  );
end;
$$;

-- Plus aucune policy d'insertion sur `notifications`. Les fonctions
-- `security definer` ci-dessus et celles de `0064`/`0065` écrivent en tant
-- que propriétaire, donc sans passer par la RLS ; une session, même staff,
-- n'insère plus rien.
drop policy if exists "notifications_insert_staff_only" on public.notifications;
