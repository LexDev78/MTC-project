-- Une remise créée une fois, posée sur plusieurs produits.
--
-- `product_promotions` (`0062`) porte `product_id not null` : une remise y
-- est, par construction, le fait d'**un** produit. C'est juste pour le
-- calcul du prix — chaque ligne de panier regarde les remises de son
-- article — mais faux pour le fournisseur, qui pense « -20 % sur tout le
-- bogolan » et non « -20 % sur le pagne, puis -20 % sur le boubou, puis
-- -20 % sur le sac ».
--
-- Conséquence avant ce fichier : poser la même remise sur trente articles
-- demandait trente passages dans la feuille d'un produit, et l'arrêter
-- demandait les trente mêmes. Personne ne le fait ; la remise reste en
-- vigueur bien après la fin prévue.
--
-- ## Pourquoi une colonne et non une table
--
-- La tentation était de créer `promotions` + `promotion_products`, comme
-- pour les codes promo (`0071`). Ç'aurait été plus élégant, et ç'aurait
-- demandé de réécrire `effective_unit_price_fcfa` — c'est-à-dire le calcul
-- du prix, que `place_order` rejoue pour facturer. Changer cette fonction
-- pour une commodité d'affichage met en jeu ce que les clients paient.
--
-- `batch_id` ne touche à rien de tout cela. Les lignes restent ce qu'elles
-- sont, le prix se calcule comme avant, et la colonne ne sert qu'à
-- retrouver ensemble celles qui ont été créées ensemble : les regrouper à
-- l'écran, les arrêter d'un geste, les supprimer d'un geste. Du
-- bookkeeping, pas de la tarification.

alter table public.product_promotions
  add column if not exists batch_id text;

-- Les lignes antérieures restent sans lot : ce sont de vraies remises
-- posées produit par produit, et leur en inventer un grouperait des
-- décisions qui n'ont jamais été prises ensemble.

-- Sert la seule lecture qui existe sur cette colonne : « toutes les lignes
-- de ce lot », pour l'écran de gestion et pour l'arrêt groupé.
create index if not exists product_promotions_batch_idx
  on public.product_promotions (batch_id) where batch_id is not null;

-- ---- arrêt et suppression groupés ----------------------------------------

-- `security definer` pour une raison précise : la policy d'écriture passe
-- par le produit (`product_promotions_write_own` vérifie que le produit
-- appartient au fournisseur). Un `update ... where batch_id = ...` côté
-- client fonctionnerait, mais ne dirait pas combien de lignes il a touchées
-- — et surtout, rien n'empêcherait de viser le lot d'un autre fournisseur :
-- la policy filtrerait silencieusement, l'appel réussirait, et l'écran
-- annoncerait un arrêt qui n'a pas eu lieu.
--
-- Ici, le lot est vérifié d'abord, et le nombre de lignes est rendu.
create or replace function public.set_promotion_batch_active(
  p_batch_id text,
  p_is_active boolean
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supplier_id uuid := public.operating_supplier_id();
  v_count integer;
begin
  if v_supplier_id is null then
    raise exception 'Réservé à un compte fournisseur.';
  end if;

  update public.product_promotions
     set is_active = p_is_active
   where batch_id = p_batch_id
     and supplier_id = v_supplier_id;

  get diagnostics v_count = row_count;
  if v_count = 0 then
    raise exception 'Remise introuvable : %', p_batch_id;
  end if;
  return v_count;
end;
$$;

revoke all on function public.set_promotion_batch_active(text, boolean)
  from public, anon;
grant execute on function public.set_promotion_batch_active(text, boolean)
  to authenticated;

create or replace function public.delete_promotion_batch(p_batch_id text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supplier_id uuid := public.operating_supplier_id();
  v_count integer;
begin
  if v_supplier_id is null then
    raise exception 'Réservé à un compte fournisseur.';
  end if;

  delete from public.product_promotions
   where batch_id = p_batch_id
     and supplier_id = v_supplier_id;

  get diagnostics v_count = row_count;
  if v_count = 0 then
    raise exception 'Remise introuvable : %', p_batch_id;
  end if;
  return v_count;
end;
$$;

revoke all on function public.delete_promotion_batch(text) from public, anon;
grant execute on function public.delete_promotion_batch(text) to authenticated;

-- ---- les remises du fournisseur, regroupées ------------------------------

-- Une ligne par lot, avec ce qu'il couvre. Lue par l'écran « Remises ».
--
-- Les lignes sans lot (celles d'avant, et celles posées depuis la feuille
-- d'un produit) sont rendues aussi, chacune comme un lot d'un produit :
-- l'écran doit montrer **toutes** les remises en vigueur, sinon il ment par
-- omission.
create or replace function public.fetch_my_promotion_batches()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(row order by created_at desc), '[]'::jsonb)
    from (
      select
        min(p.created_at) as created_at,
        jsonb_build_object(
          'batch_id', min(p.batch_id),
          -- Sans lot, l'identifiant de la ligne tient lieu de clé : l'écran
          -- la traite alors comme un lot d'un seul produit.
          'key', coalesce(min(p.batch_id), min(p.id)),
          'kind', min(p.kind::text),
          'value', min(p.value),
          'min_quantity', min(p.min_quantity),
          'starts_at', min(p.starts_at),
          'ends_at', min(p.ends_at),
          'label', min(p.label),
          'created_at', min(p.created_at),
          -- Un lot dont une partie serait arrêtée n'a pas de sens : l'arrêt
          -- est groupé. `bool_and` le dit quand même, plutôt que de
          -- supposer.
          'is_active', bool_and(p.is_active),
          'product_count', count(*),
          'product_names', jsonb_agg(pr.name order by pr.name),
          -- Les identifiants, pour que l'écran puisse rouvrir la remise
          -- avec ses produits déjà cochés. Sans eux, « modifier » obligerait
          -- à re-sélectionner la couverture de mémoire.
          'product_ids', jsonb_agg(pr.id order by pr.name)
        ) as row
        from public.product_promotions p
        join public.products pr on pr.id = p.product_id
       where p.supplier_id = public.operating_supplier_id()
       group by coalesce(p.batch_id, p.id)
    ) s;
$$;

revoke all on function public.fetch_my_promotion_batches() from public, anon;
grant execute on function public.fetch_my_promotion_batches() to authenticated;
