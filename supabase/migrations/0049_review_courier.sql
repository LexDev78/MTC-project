-- Validation d'un livreur par le staff.
--
-- Passe par une RPC et non par un `update` direct, pour la même raison que
-- les courses (`0046`) : `couriers` n'accorde à `authenticated` que les
-- quatre colonnes de libre-service (être en ligne, pousser sa position). Le
-- statut n'en fait pas partie — sinon un livreur s'approuverait lui-même,
-- sa propre policy `couriers_update_self` l'y autorisant.
--
-- Le `security definer` écrit donc ce que l'appelant ne peut pas écrire, et
-- vérifie lui-même que c'est bien un agent MTC qui demande.
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
     set status = case when p_approve then 'approved' else 'rejected' end,
         rejection_reason = case when p_approve then null else p_reason end,
         reviewed_at = now(),
         reviewed_by_staff_id = auth.uid()
   where id = p_courier_id;

  if not found then
    raise exception 'Livreur introuvable : %', p_courier_id;
  end if;

  -- Le livreur est prévenu de la décision. `kyc_decision` décrit déjà
  -- exactement ça (une inscription validée ou refusée par le staff) : lui
  -- inventer un type à part obligerait à traiter le nouveau cas partout où
  -- les notifications sont routées, pour le même message.
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

revoke all on function public.review_courier(uuid, boolean, text) from public, anon;
grant execute on function public.review_courier(uuid, boolean, text) to authenticated;
