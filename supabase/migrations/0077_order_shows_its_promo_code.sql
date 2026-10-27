-- Le client doit pouvoir relire le code qu'il a utilisé.
--
-- L'utilisation lui est bien visible (`promo_code_redemptions_visible`),
-- mais elle ne porte qu'un **identifiant** de code — et `promo_codes` lui
-- est fermée, justement pour qu'il ne puisse pas énumérer les codes en
-- vigueur. Il voyait donc une remise sans savoir laquelle.
--
-- Le code est donc figé sur l'utilisation, comme le nom du produit l'est
-- déjà sur ses lignes : le fournisseur peut renommer ou supprimer son code,
-- l'historique d'une commande passée doit rester vrai.
alter table public.promo_code_redemptions
  add column if not exists code_snapshot text;

update public.promo_code_redemptions r
   set code_snapshot = c.code
  from public.promo_codes c
 where c.id = r.promo_code_id and r.code_snapshot is null;

grant select (code_snapshot) on public.promo_code_redemptions to authenticated;

-- Les codes utilisés sur une commande, par groupe fournisseur.
--
-- `security definer` pour une raison précise : la lecture elle-même est déjà
-- permise au client, mais mieux vaut une fonction qui ne renvoie que le
-- code et le montant qu'une requête libre sur une table dont d'autres
-- colonnes pourraient s'ajouter.
create or replace function public.fetch_order_promo_codes(p_order_id text)
returns table (supplier_group_id text, code text, discount_fcfa integer)
language sql
stable
security definer
set search_path = public
as $$
  select r.supplier_group_id, coalesce(r.code_snapshot, '—'), r.discount_fcfa
    from public.promo_code_redemptions r
    join public.orders o on o.id = r.order_id
   where r.order_id = p_order_id
     and (
       o.client_id = auth.uid()
       or exists (
         select 1 from public.order_supplier_groups g
          where g.id = r.supplier_group_id
            and g.supplier_id = public.operating_supplier_id()
       )
     );
$$;

revoke all on function public.fetch_order_promo_codes(text) from public, anon;
grant execute on function public.fetch_order_promo_codes(text) to authenticated;
