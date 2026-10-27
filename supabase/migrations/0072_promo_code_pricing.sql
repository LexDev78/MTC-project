-- Ce qu'un code promo vaut sur un panier, et pourquoi il ne vaut rien.
--
-- Deux usages de la même règle : l'écran de paiement montre l'effet avant de
-- commander (`preview_promo_code`), et `place_order` l'applique
-- (`0073`). La validation ne consomme rien — elle peut donc être rejouée
-- autant de fois que le client retape son code.
--
-- Le prix retenu ligne par ligne est **le plus bas entre le code et la
-- promotion automatique**, jamais les deux. Conséquence assumée : sur un
-- article déjà remisé plus fort, le code n'apporte rien, et l'écran le dit
-- plutôt que de laisser croire à une panne.

-- Un code couvre un produit s'il le nomme, ou s'il ne nomme rien du tout
-- (« -10% sur ma boutique »).
create or replace function public.promo_code_covers_product(
  p_code_id text,
  p_product_id text
) returns boolean
language sql
stable
set search_path = public
as $$
  select not exists (
    select 1 from public.promo_code_products where promo_code_id = p_code_id
  ) or exists (
    select 1 from public.promo_code_products
     where promo_code_id = p_code_id and product_id = p_product_id
  );
$$;


-- Le prix unitaire sous le code, ou `null` si le produit n'est pas couvert.
create or replace function public.promo_code_unit_price_fcfa(
  p_code_id text,
  p_product_id text,
  p_base_price_fcfa integer
) returns integer
language plpgsql
stable
set search_path = public
as $$
declare
  v_percent integer;
begin
  if not public.promo_code_covers_product(p_code_id, p_product_id) then
    return null;
  end if;
  select percent into v_percent from public.promo_codes where id = p_code_id;
  if v_percent is null then return null; end if;
  -- Même plancher qu'ailleurs : un prix nul traverserait les contrôles de
  -- stock et de paiement sans que personne ne l'ait décidé.
  return greatest(p_base_price_fcfa - (p_base_price_fcfa * v_percent) / 100, 1);
end;
$$;

-- Retrouve le code utilisable parmi les fournisseurs présents au panier.
--
-- Deux fournisseurs peuvent avoir choisi le même intitulé : un code est
-- unique **par fournisseur**, pas sur la plateforme — personne n'a à se
-- battre pour « RENTREE ». On retient alors le plus avantageux, et c'est le
-- seul cas où ce choix se pose.
create or replace function public.resolve_promo_code(
  p_code text,
  p_supplier_ids uuid[]
) returns text
language sql
stable
set search_path = public
as $$
  select c.id
    from public.promo_codes c
   where c.code = upper(btrim(p_code))
     and c.supplier_id = any(p_supplier_ids)
     and c.is_active
     and (c.starts_at is null or c.starts_at <= now())
     and (c.ends_at is null or c.ends_at > now())
   order by c.percent desc
   limit 1;
$$;

-- L'effet d'un code sur un panier, sans rien consommer.
--
-- `p_lines` : `[{"product_id": ..., "variant_id": ..., "quantity": n}, ...]`
--
-- Renvoie toujours un objet, jamais une erreur : un code faux ou expiré est
-- une réponse normale de l'écran de paiement, pas un incident. `reason`
-- porte de quoi l'expliquer au client.
create or replace function public.preview_promo_code(
  p_code text,
  p_lines jsonb
) returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_client uuid := auth.uid();
  v_code_id text;
  v_code public.promo_codes%rowtype;
  v_supplier_ids uuid[];
  v_line jsonb;
  v_product_id text;
  v_variant_id text;
  v_quantity integer;
  v_base integer;
  v_effective integer;
  v_with_code integer;
  v_best integer;
  v_group_subtotal integer := 0;
  v_discount integer := 0;
  v_lines jsonb := '[]'::jsonb;
  v_used_by_client integer;
begin
  if v_client is null then
    return jsonb_build_object('valid', false, 'reason', 'Connectez-vous pour utiliser un code.');
  end if;

  select array_agg(distinct p.supplier_id) into v_supplier_ids
    from jsonb_array_elements(p_lines) l
    join public.products p on p.id = (l ->> 'product_id');

  v_code_id := public.resolve_promo_code(p_code, coalesce(v_supplier_ids, '{}'));
  if v_code_id is null then
    return jsonb_build_object(
      'valid', false,
      'reason', 'Code inconnu, expiré, ou sans effet sur les articles de ce panier.'
    );
  end if;
  select * into v_code from public.promo_codes where id = v_code_id;

  if v_code.max_uses is not null and v_code.uses_count >= v_code.max_uses then
    return jsonb_build_object('valid', false, 'reason', 'Ce code a atteint sa limite d''utilisation.');
  end if;

  select count(*) into v_used_by_client
    from public.promo_code_redemptions
   where promo_code_id = v_code_id and client_id = v_client;
  if v_used_by_client >= v_code.max_uses_per_client then
    return jsonb_build_object('valid', false, 'reason', 'Vous avez déjà utilisé ce code.');
  end if;

  -- Le panier de **ce** fournisseur : le minimum de commande s'entend chez
  -- lui, pas sur l'ensemble d'un panier multi-boutiques.
  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    v_product_id := v_line ->> 'product_id';
    v_variant_id := v_line ->> 'variant_id';
    v_quantity := coalesce((v_line ->> 'quantity')::integer, 1);

    if (select supplier_id from public.products where id = v_product_id)
       is distinct from v_code.supplier_id then
      continue;
    end if;

    if v_variant_id is null then
      select price_fcfa into v_base from public.products where id = v_product_id;
    else
      select price_fcfa into v_base from public.product_variants
       where id = v_variant_id and product_id = v_product_id;
    end if;
    if v_base is null then continue; end if;

    v_effective := public.effective_unit_price_fcfa(v_product_id, v_variant_id, v_quantity);
    v_group_subtotal := v_group_subtotal + v_effective * v_quantity;

    v_with_code := public.promo_code_unit_price_fcfa(v_code_id, v_product_id, v_base);
    if v_with_code is null then continue; end if;

    -- Pas de cumul : la meilleure des deux remises, pas leur somme.
    v_best := least(v_effective, v_with_code);
    if v_best >= v_effective then continue; end if;

    v_discount := v_discount + (v_effective - v_best) * v_quantity;
    v_lines := v_lines || jsonb_build_object(
      'product_id', v_product_id,
      'quantity', v_quantity,
      'unit_discount_fcfa', v_effective - v_best
    );
  end loop;

  if v_code.min_order_fcfa is not null and v_group_subtotal < v_code.min_order_fcfa then
    return jsonb_build_object(
      'valid', false,
      'reason', 'Ce code demande une commande d''au moins '
                || v_code.min_order_fcfa || ' FCFA chez ce vendeur.'
    );
  end if;

  if v_discount = 0 then
    return jsonb_build_object(
      'valid', false,
      'reason', 'Ce code n''améliore pas les remises déjà en cours sur ces articles.'
    );
  end if;

  return jsonb_build_object(
    'valid', true,
    'code', v_code.code,
    'percent', v_code.percent,
    'supplier_id', v_code.supplier_id,
    'discount_fcfa', v_discount,
    'lines', v_lines
  );
end;
$$;

revoke all on function public.preview_promo_code(text, jsonb) from public, anon;
grant execute on function public.preview_promo_code(text, jsonb) to authenticated;

-- La gestion côté fournisseur : ses codes, et ce qu'ils ont remisé.
--
-- `security definer` pour une raison précise : la policy de `promo_codes`
-- ouvre déjà ses propres codes au fournisseur, mais l'agrégat ci-dessous
-- joint les utilisations et leurs lignes, et il vaut mieux une seule lecture
-- taillée que trois requêtes imbriquées depuis l'app.
create or replace function public.fetch_my_promo_codes()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(row order by created_at desc), '[]'::jsonb) from (
    select c.created_at, jsonb_build_object(
             'id', c.id,
             'code', c.code,
             'percent', c.percent,
             'label', c.label,
             'is_active', c.is_active,
             'starts_at', c.starts_at,
             'ends_at', c.ends_at,
             'max_uses', c.max_uses,
             'max_uses_per_client', c.max_uses_per_client,
             'min_order_fcfa', c.min_order_fcfa,
             'uses_count', c.uses_count,
             'product_ids', coalesce((
               select jsonb_agg(pp.product_id)
                 from public.promo_code_products pp
                where pp.promo_code_id = c.id
             ), '[]'::jsonb),
             'redemptions', coalesce((
               select jsonb_agg(jsonb_build_object(
                        'id', r.id,
                        'created_at', r.created_at,
                        'discount_fcfa', r.discount_fcfa,
                        'client_name', coalesce(r.client_display_name_snapshot, 'Client MTC'),
                        'items', coalesce((
                          select jsonb_agg(jsonb_build_object(
                                   'product_name', i.product_name_snapshot,
                                   'quantity', i.quantity,
                                   'unit_discount_fcfa', i.unit_discount_fcfa
                                 ))
                            from public.promo_code_redemption_items i
                           where i.redemption_id = r.id
                        ), '[]'::jsonb)
                      ) order by r.created_at desc)
                 from public.promo_code_redemptions r
                where r.promo_code_id = c.id
             ), '[]'::jsonb)
           ) as row
      from public.promo_codes c
     where c.supplier_id = public.operating_supplier_id()
  ) t;
$$;

revoke all on function public.fetch_my_promo_codes() from public, anon;
grant execute on function public.fetch_my_promo_codes() to authenticated;
