-- `review_courier` échouait systématiquement : aucun livreur ne pouvait être
-- validé.
--
--   column "status" is of type courier_status but expression is of type text
--
-- Le `case ... then 'approved' else 'rejected' end` produit du **texte**, et
-- Postgres ne convertit pas implicitement vers une énumération dans une
-- affectation. Ailleurs dans ce schéma le littéral est écrit directement
-- (`set status = 'approved'`), ce qui marche — c'est le passage par un
-- `case` qui change le type de l'expression, et le piège ne se voit pas à la
-- lecture.
--
-- Trouvé en exécutant la décision dans un test, pas en relisant la fonction :
-- la file des livreurs en attente s'affichait, le bouton existait, et le
-- refus n'apparaissait qu'au moment du clic.

create or replace function public.review_courier(
  p_courier_id uuid,
  p_approve boolean,
  p_reason text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_staff() then
    raise exception 'Réservé au staff MTC.';
  end if;
  if not p_approve and coalesce(trim(p_reason), '') = '' then
    raise exception 'Un refus doit être motivé.';
  end if;

  update public.couriers
     set status = (
           case when p_approve then 'approved' else 'rejected' end
         )::public.courier_status,
         rejection_reason = case when p_approve then null else p_reason end,
         reviewed_at = now(),
         reviewed_by_staff_id = auth.uid()
   where id = p_courier_id;

  if not found then
    raise exception 'Livreur introuvable : %', p_courier_id;
  end if;

  insert into public.notifications (id, user_id, type, title, body, reference_id)
  values (
    gen_random_uuid()::text,
    p_courier_id,
    'kyc_decision',
    case when p_approve then 'Inscription validée' else 'Inscription refusée' end,
    case
      when p_approve then 'Vous pouvez prendre des courses dès maintenant.'
      else p_reason
    end,
    p_courier_id::text
  );
end;
$$;

-- Bascule le mode de livraison d'un groupe, pour les tests.
--
-- Le jeu de démonstration fige ses deux groupes « livraison MTC » en
-- `in_transit` sans course associée — un état que la production ne produit
-- plus (le trigger crée la course à cette transition). Un test qui porte sur
-- les transitions de statut du **fournisseur** doit donc pouvoir remettre le
-- groupe en livraison par ses soins.
create or replace function public.test_set_group_delivery_mode(
  p_group_id text,
  p_mode text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.order_supplier_groups
     set delivery_mode = p_mode::public.delivery_mode
   where id = p_group_id;
end;
$$;

revoke all on function public.test_set_group_delivery_mode(text, text) from public, anon, authenticated;
