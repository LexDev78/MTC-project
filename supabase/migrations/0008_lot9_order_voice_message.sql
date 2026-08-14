-- Lot 9 : le chemin objet du message vocal fournisseur ne peut pas être
-- connu au moment de `place_order()` — le bucket `order-messages` (déjà
-- provisionné au Lot 1) exige qu'une ligne `orders` existe déjà pour
-- autoriser l'upload dans son dossier (`order_messages_visible`, clé =
-- order_id), et l'id de la commande n'existe qu'après le retour de la RPC.
-- Donc : `place_order()` crée la commande sans chemin vocal, puis
-- `CheckoutController` uploade le fichier local vers
-- `order-messages/<orderId>/...` (la ligne existe désormais, l'upload est
-- autorisé), puis attache le chemin via cette seconde RPC — même
-- raisonnement en deux temps que les commandes elles-mêmes (Lot 5),
-- appliqué ici au stockage plutôt qu'au stock.
create or replace function public.set_order_voice_message(
  p_order_id text,
  p_voice_path text,
  p_duration_seconds int
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.orders
  set
    supplier_message_voice_path = p_voice_path,
    supplier_message_voice_duration_seconds = p_duration_seconds
  where id = p_order_id and client_id = auth.uid();
end;
$$;

revoke all on function public.set_order_voice_message(text, text, int) from public, anon, authenticated;
grant execute on function public.set_order_voice_message(text, text, int) to authenticated;
