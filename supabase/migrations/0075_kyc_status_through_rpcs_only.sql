-- Le statut d'un dossier de vérification ne s'écrit plus à la main.
--
-- `supplier_kyc_all_owner_or_staff` ouvre la ligne entière à son
-- propriétaire **et** au staff, colonnes de décision comprises. Deux
-- conséquences, l'une plus sérieuse que l'autre :
--
--  * un **fournisseur** pouvait passer son propre dossier à `approved`. Sa
--    boutique ne devenait pas vérifiée pour autant (le garde-fou de
--    `suppliers.verification_status` tient, `0029`), mais son dossier
--    sortait de la file du staff : personne ne l'examinait plus, et l'écran
--    lui annonçait une validation qui n'avait pas eu lieu ;
--  * un **agent** pouvait écrire `approved` directement, sans que la fiche
--    fournisseur ni la visibilité de ses produits suivent — exactement
--    l'état à moitié validé que `review_supplier_kyc` (`0069`) existe pour
--    empêcher.
--
-- Les quatre colonnes de décision sortent donc des droits d'écriture, et les
-- trois gestes légitimes passent par des fonctions qui savent ce qu'elles
-- entraînent. Le fournisseur garde l'écriture de **son dossier** : numéro
-- RCCM, identifiant fiscal, adresse, consentement.
revoke update (status, submitted_at, reviewed_at, reviewed_by_staff_id, rejection_reason)
  on public.supplier_kyc from authenticated;

-- Soumettre son dossier. Le fournisseur ne choisit pas le statut : il
-- demande un examen, et c'est tout ce que cette fonction accorde.
create or replace function public.submit_supplier_kyc()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supplier_id uuid := public.operating_supplier_id();
  v_status public.kyc_review_status;
begin
  if v_supplier_id is null then
    raise exception 'Réservé à un compte fournisseur.';
  end if;

  select status into v_status
    from public.supplier_kyc where supplier_id = v_supplier_id;
  if v_status is null then
    raise exception 'Aucun dossier à soumettre.';
  end if;
  -- Un dossier déjà soumis ou en cours d'examen ne se resoumet pas : cela
  -- remettrait le compteur à zéro dans la file du staff.
  if v_status not in ('draft', 'rejected') then
    raise exception 'Ce dossier est déjà soumis.';
  end if;

  update public.supplier_kyc
     set status = 'submitted',
         submitted_at = now(),
         rejection_reason = null
   where supplier_id = v_supplier_id;
end;
$$;

revoke all on function public.submit_supplier_kyc() from public, anon;
grant execute on function public.submit_supplier_kyc() to authenticated;

-- Prendre un dossier en examen. Réservé au staff, et l'agent est celui de
-- la session : un agent ne s'attribue pas le dossier d'un collègue.
create or replace function public.start_kyc_review(p_kyc_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_staff() then
    raise exception 'Réservé au staff MTC.';
  end if;

  update public.supplier_kyc
     set status = 'under_review',
         reviewed_by_staff_id = auth.uid()
   where id = p_kyc_id
     and status = 'submitted';

  if not found then
    raise exception 'Ce dossier n''attend pas d''examen.';
  end if;
end;
$$;

revoke all on function public.start_kyc_review(text) from public, anon;
grant execute on function public.start_kyc_review(text) to authenticated;
