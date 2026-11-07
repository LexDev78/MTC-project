-- Caractéristiques + variantes de produit (couleur/stockage/taille/poids →
-- combinaisons achetables avec leur propre stock/prix/photos), + agrégation
-- automatique sur `products` pour que tout le code existant qui lit
-- `price_fcfa`/`stock_quantity` continue de fonctionner sans changement.
--
-- Voir /Users/solomon/.claude/plans/sunny-splashing-token.md sections 1.2/1.3.

alter table public.products
  add column has_variants boolean not null default false,
  add column max_price_fcfa integer,
  add column variant_count integer not null default 0;

create table public.product_characteristics (
  id text primary key,
  product_id text not null references public.products (id) on delete cascade,
  type_id text not null references public.product_characteristic_types (id),
  display_order integer not null default 0,
  unique (product_id, type_id)
);

-- Défense en profondeur : seul un type approuvé peut être attaché à un
-- produit (le picker fournisseur ne propose déjà que les types approuvés —
-- ceci bloque toute tentative d'écriture directe via l'API).
create or replace function public.check_characteristic_type_approved()
returns trigger
language plpgsql
as $$
begin
  if not exists (
    select 1 from public.product_characteristic_types
    where id = new.type_id and status = 'approved'
  ) then
    raise exception 'Ce type de caractéristique n''est pas encore approuvé.';
  end if;
  return new;
end;
$$;

create trigger product_characteristics_require_approved_type
  before insert or update of type_id on public.product_characteristics
  for each row execute function public.check_characteristic_type_approved();

create table public.product_characteristic_options (
  id text primary key,
  characteristic_id text not null references public.product_characteristics (id) on delete cascade,
  value text not null,
  price_delta_fcfa integer not null default 0,
  display_order integer not null default 0,
  unique (characteristic_id, value)
);

create table public.product_variants (
  id text primary key,
  product_id text not null references public.products (id) on delete cascade,
  name text not null,
  price_fcfa integer not null,
  stock_quantity integer not null default 0 check (stock_quantity >= 0),
  image_urls text[] not null default '{}',
  is_default boolean not null default false,
  display_order integer not null default 0,
  created_at timestamptz not null default now()
);

-- Au plus une variante par défaut par produit.
create unique index product_variants_one_default
  on public.product_variants (product_id) where is_default;

-- `characteristic_id` est dénormalisé depuis `product_characteristic_options`
-- uniquement pour que la clé primaire impose "une seule option par
-- caractéristique par variante" sans trigger dédié — même niveau de
-- confiance que les autres snapshots dénormalisés du schéma
-- (`product_name_snapshot` etc.), la couche applicative
-- (SupplierVariantController) est seule responsable de faire correspondre
-- `characteristic_id` au vrai parent de `option_id`.
create table public.product_variant_options (
  variant_id text not null references public.product_variants (id) on delete cascade,
  characteristic_id text not null references public.product_characteristics (id) on delete cascade,
  option_id text not null references public.product_characteristic_options (id) on delete cascade,
  primary key (variant_id, characteristic_id)
);

create index product_characteristics_product_id_idx on public.product_characteristics (product_id);
create index product_characteristic_options_characteristic_id_idx on public.product_characteristic_options (characteristic_id);
create index product_variants_product_id_idx on public.product_variants (product_id);
create index product_variant_options_option_id_idx on public.product_variant_options (option_id);

alter table public.stock_movements
  add column variant_id text references public.product_variants (id) on delete cascade;

alter table public.cart_items
  add column variant_id text references public.product_variants (id) on delete set null,
  add column variant_name_snapshot text;

alter table public.order_items
  add column variant_id text references public.product_variants (id) on delete set null,
  add column variant_name_snapshot text;

alter table public.chat_messages
  add column product_variant_id text references public.product_variants (id) on delete set null,
  add column product_variant_name_snapshot text;

-- ============================================================================
-- Agrégation automatique : `products.price_fcfa`/`stock_quantity` deviennent
-- calculés dès qu'une variante existe (min prix / somme des stocks) — aucun
-- code existant qui lit ces deux champs n'a besoin d'être modifié. Idem pour
-- `image_urls` : un fournisseur qui ne met des photos que sur ses variantes
-- (le produit de base n'a alors aucune raison d'avoir les siennes propres —
-- la variante par défaut EST sa vitrine) voit quand même le produit afficher
-- une vraie photo partout où seul `product.imageUrls` est lu (grille
-- catalogue, carte produit, panier sans variante résolue, ...) — copiées
-- depuis la variante par défaut, jamais en écrasant des photos que le
-- fournisseur a explicitement mises sur le produit lui-même.
-- ============================================================================
create or replace function public.recompute_product_variant_aggregates()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product_id text := coalesce(new.product_id, old.product_id);
  v_count integer;
  v_min integer;
  v_max integer;
  v_stock integer;
  v_own_images text[];
  v_default_images text[];
begin
  select count(*), min(price_fcfa), max(price_fcfa), coalesce(sum(stock_quantity), 0)
    into v_count, v_min, v_max, v_stock
    from public.product_variants
    where product_id = v_product_id;

  if v_count = 0 then
    -- Dernière variante supprimée : price_fcfa/stock_quantity ne sont PAS
    -- touchés ici (retour au champ géré manuellement par le fournisseur,
    -- jamais remis à 0/null — cela corromprait un vrai chiffre d'inventaire
    -- que le fournisseur n'a pas lui-même modifié).
    update public.products
      set has_variants = false, max_price_fcfa = null, variant_count = 0
      where id = v_product_id;
  else
    select image_urls into v_own_images from public.products where id = v_product_id;
    select image_urls into v_default_images
      from public.product_variants
      where product_id = v_product_id and is_default
      limit 1;

    update public.products
      set has_variants = true, price_fcfa = v_min, max_price_fcfa = v_max,
          stock_quantity = v_stock, variant_count = v_count,
          image_urls = case
            when coalesce(cardinality(v_own_images), 0) = 0
                 and coalesce(cardinality(v_default_images), 0) > 0
            then v_default_images
            else image_urls
          end
      where id = v_product_id;
  end if;

  return coalesce(new, old);
end;
$$;

create trigger product_variants_aggregate_products
  after insert or delete or update of price_fcfa, stock_quantity, image_urls, is_default
  on public.product_variants
  for each row execute function public.recompute_product_variant_aggregates();

-- ============================================================================
-- RLS — même forme que products_select_public/products_write_own, jointes
-- au produit parent (comme stock_movements_all_own_product).
-- ============================================================================
alter table public.product_characteristics enable row level security;
alter table public.product_characteristic_options enable row level security;
alter table public.product_variants enable row level security;
alter table public.product_variant_options enable row level security;

create policy "product_characteristics_select_public" on public.product_characteristics
  for select using (
    exists (
      select 1 from public.products p where p.id = product_id
        and ((p.status = 'active' and p.is_supplier_verified = true)
             or p.supplier_id = public.operating_supplier_id())
    )
  );
create policy "product_characteristics_write_own" on public.product_characteristics
  for all using (
    exists (select 1 from public.products p where p.id = product_id and p.supplier_id = public.operating_supplier_id())
  )
  with check (
    exists (select 1 from public.products p where p.id = product_id and p.supplier_id = public.operating_supplier_id())
  );

create policy "product_characteristic_options_select_public" on public.product_characteristic_options
  for select using (
    exists (
      select 1 from public.product_characteristics c join public.products p on p.id = c.product_id
      where c.id = characteristic_id
        and ((p.status = 'active' and p.is_supplier_verified = true) or p.supplier_id = public.operating_supplier_id())
    )
  );
create policy "product_characteristic_options_write_own" on public.product_characteristic_options
  for all using (
    exists (
      select 1 from public.product_characteristics c join public.products p on p.id = c.product_id
      where c.id = characteristic_id and p.supplier_id = public.operating_supplier_id()
    )
  )
  with check (
    exists (
      select 1 from public.product_characteristics c join public.products p on p.id = c.product_id
      where c.id = characteristic_id and p.supplier_id = public.operating_supplier_id()
    )
  );

create policy "product_variants_select_public" on public.product_variants
  for select using (
    exists (
      select 1 from public.products p where p.id = product_id
        and ((p.status = 'active' and p.is_supplier_verified = true) or p.supplier_id = public.operating_supplier_id())
    )
  );
create policy "product_variants_write_own" on public.product_variants
  for all using (
    exists (select 1 from public.products p where p.id = product_id and p.supplier_id = public.operating_supplier_id())
  )
  with check (
    exists (select 1 from public.products p where p.id = product_id and p.supplier_id = public.operating_supplier_id())
  );

create policy "product_variant_options_select_public" on public.product_variant_options
  for select using (
    exists (
      select 1 from public.product_variants v join public.products p on p.id = v.product_id
      where v.id = variant_id
        and ((p.status = 'active' and p.is_supplier_verified = true) or p.supplier_id = public.operating_supplier_id())
    )
  );
create policy "product_variant_options_write_own" on public.product_variant_options
  for all using (
    exists (
      select 1 from public.product_variants v join public.products p on p.id = v.product_id
      where v.id = variant_id and p.supplier_id = public.operating_supplier_id()
    )
  )
  with check (
    exists (
      select 1 from public.product_variants v join public.products p on p.id = v.product_id
      where v.id = variant_id and p.supplier_id = public.operating_supplier_id()
    )
  );

grant select on
  public.product_characteristics, public.product_characteristic_options,
  public.product_variants, public.product_variant_options
  to anon;
grant select, insert, update, delete on
  public.product_characteristics, public.product_characteristic_options,
  public.product_variants, public.product_variant_options
  to authenticated;
