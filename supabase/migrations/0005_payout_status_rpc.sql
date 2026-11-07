-- `updatePayoutStatus` (SupplierFinanceRepository) impose une machine à
-- états (`requested -> processing/rejected`, `processing -> paid/rejected`,
-- `paid`/`rejected` terminaux) — jusqu'ici uniquement vérifiée côté Dart
-- (`InMemorySupplierFinanceDatasource._isValidTransition`). La policy RLS
-- `payout_requests_update_admin` (0001_initial_schema.sql) n'autorisait
-- qu'`is_admin()` mais ne validait aucune transition : un admin aurait pu
-- envoyer un PATCH REST direct et faire régresser un virement déjà `paid`.
-- Même classe de faille que celle fermée pour les commandes au Lot 5
-- (`update_order_group_status`) — même remède : une RPC `security definer`
-- qui valide la transition avant d'écrire, et la policy UPDATE en moins
-- pour qu'un PATCH direct ne puisse plus jamais la contourner.

drop policy if exists "payout_requests_update_admin" on public.payout_requests;

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
begin
  if not public.is_admin() then
    raise exception 'Non autorisé à modifier ce retrait.';
  end if;

  select status into v_current from public.payout_requests where id = p_payout_id;
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
end;
$$;

revoke all on function public.update_payout_status(text, text, text) from public, anon, authenticated;
grant execute on function public.update_payout_status(text, text, text) to authenticated;
