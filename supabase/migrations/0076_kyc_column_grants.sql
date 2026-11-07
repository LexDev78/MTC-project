-- Le revoke de `0075` n'avait aucun effet.
--
-- `supplier_kyc` porte un `grant update` au **niveau table**, et en
-- PostgreSQL un privilège de table couvre toutes ses colonnes : révoquer
-- quatre colonnes par-dessus ne retire rien. Le statut restait donc
-- écrivable à la main, et le test l'a montré — un agent passait un dossier
-- à `approved` sans que la fiche fournisseur ni ses produits suivent.
--
-- Il faut retirer le privilège de table, puis n'accorder que les colonnes
-- du dossier lui-même. Les colonnes de décision (statut, dates et agent
-- d'examen, motif de refus) ne sont plus accessibles qu'aux fonctions
-- `security definer`, qui s'exécutent en tant que propriétaire.
revoke update on public.supplier_kyc from authenticated;

grant update (
  legal_type,
  rccm_number,
  tax_id,
  legal_representative_name,
  registered_address,
  consent_accepted,
  consent_accepted_at,
  consent_policy_version
) on public.supplier_kyc to authenticated;
