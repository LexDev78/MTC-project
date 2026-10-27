-- Modifier une remise déjà posée, sans la supprimer pour la refaire.
--
-- `0090` savait créer un lot, l'arrêter, le supprimer. Pas le corriger. Un
-- fournisseur qui s'était trompé de pourcentage, ou qui voulait ajouter
-- deux articles à sa remise, n'avait qu'un chemin : tout supprimer et tout
-- ressaisir. Entre les deux, les prix repassaient au plein tarif — pendant
-- quelques secondes si tout va bien, indéfiniment si le téléphone perd le
-- réseau au milieu.
--
-- D'où une RPC qui fait les deux en une transaction : la valeur change, la
-- couverture se réconcilie, et à aucun moment la remise n'a disparu.
--
-- La réconciliation ne détruit pas ce qui doit rester : les produits
-- toujours couverts gardent **leur ligne**, avec son `created_at`. Seuls
-- les retirés disparaissent et les ajoutés naissent. Supprimer puis tout
-- réinsérer aurait été plus court à écrire et aurait réécrit l'historique
-- de chaque ligne.
create or replace function public.update_promotion_batch(
  p_batch_id text,
  p_kind text,
  p_value integer,
  p_min_quantity integer,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_label text,
  p_product_ids text[]
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supplier_id uuid := public.operating_supplier_id();
  v_existing integer;
  v_count integer;
begin
  if v_supplier_id is null then
    raise exception 'Réservé à un compte fournisseur.';
  end if;
  if coalesce(array_length(p_product_ids, 1), 0) = 0 then
    raise exception 'Une remise doit couvrir au moins un produit.';
  end if;

  select count(*) into v_existing
    from public.product_promotions
   where batch_id = p_batch_id and supplier_id = v_supplier_id;
  if v_existing = 0 then
    raise exception 'Remise introuvable : %', p_batch_id;
  end if;

  -- Un produit qui n'est pas à lui : refusé avant toute écriture plutôt que
  -- filtré en silence par le trigger, qui laisserait croire que la remise
  -- couvre un article qu'elle ne couvre pas.
  if exists (
    select 1 from unnest(p_product_ids) pid
     where not exists (
       select 1 from public.products p
        where p.id = pid and p.supplier_id = v_supplier_id
     )
  ) then
    raise exception 'Un des produits ne vous appartient pas.';
  end if;

  -- Les retirés.
  delete from public.product_promotions
   where batch_id = p_batch_id
     and supplier_id = v_supplier_id
     and product_id <> all (p_product_ids);

  -- Les conservés : mis à jour sur place.
  update public.product_promotions
     set kind = p_kind::public.promotion_kind,
         value = p_value,
         min_quantity = p_min_quantity,
         starts_at = p_starts_at,
         ends_at = p_ends_at,
         label = p_label
   where batch_id = p_batch_id
     and supplier_id = v_supplier_id;

  -- Les ajoutés. `supplier_id` est posé par le trigger de `0062`, comme
  -- partout ailleurs : l'écrire ici laisserait croire que l'appelant décide
  -- à qui appartient la remise.
  insert into public.product_promotions
    (batch_id, product_id, kind, value, min_quantity, starts_at, ends_at, label)
  select p_batch_id, pid, p_kind::public.promotion_kind, p_value,
         p_min_quantity, p_starts_at, p_ends_at, p_label
    from unnest(p_product_ids) pid
   where not exists (
     select 1 from public.product_promotions e
      where e.batch_id = p_batch_id and e.product_id = pid
   );

  select count(*) into v_count
    from public.product_promotions
   where batch_id = p_batch_id and supplier_id = v_supplier_id;
  return v_count;
end;
$$;

revoke all on function public.update_promotion_batch(
  text, text, integer, integer, timestamptz, timestamptz, text, text[]
) from public, anon;
grant execute on function public.update_promotion_batch(
  text, text, integer, integer, timestamptz, timestamptz, text, text[]
) to authenticated;
