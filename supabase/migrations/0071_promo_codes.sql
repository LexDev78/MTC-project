-- Codes promo : le fournisseur distribue un code, le client le saisit.
--
-- Différent des promotions (`0062`), qui s'appliquent toutes seules à qui
-- regarde la fiche. Un code est **remis à quelqu'un** — un client fidèle, un
-- groupe WhatsApp, un flyer — et ne vaut que pour celui qui le connaît.
-- D'où trois exigences que les promotions n'ont pas :
--
--  * il ne doit pas être **énumérable**. Aucune policy de lecture pour les
--    clients : un code ne se découvre pas, il se présente. Tout passe par
--    les fonctions ci-dessous, qui répondent sur un code **donné**.
--  * il s'épuise. Un plafond global et un plafond par client, et le
--    compteur doit tenir sous des paiements simultanés — sinon deux clients
--    consomment la dernière utilisation en même temps.
--  * il laisse une trace. Le fournisseur doit pouvoir lire quel code a été
--    appliqué, sur quels articles, pour combien.
--
-- **Pas de cumul**, comme entre promotions : sur chaque ligne, le client
-- garde la remise la plus avantageuse — le code ou la promotion
-- automatique, jamais les deux. Empiler produirait des prix que personne n'a
-- voulus, et un fournisseur qui laisse tourner un -20% puis distribue un
-- code -20% ne pense pas vendre à -36%.

create table public.promo_codes (
  id text primary key default gen_random_uuid()::text,

  -- Posé par le trigger depuis l'appelant : un code appartient au
  -- fournisseur qui le crée, et ne s'applique qu'à ses produits.
  supplier_id uuid not null references public.suppliers(id) on delete cascade,

  -- Normalisé en majuscules sans espaces : « rentree », « Rentrée  » et
  -- « RENTREE » sont le même code pour qui le tape sur un téléphone.
  code text not null check (code = upper(btrim(code)) and length(code) between 3 and 24),

  percent integer not null check (percent between 1 and 90),

  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean not null default true,

  -- `null` = sans plafond. Le plafond par client vaut 1 par défaut : c'est
  -- l'attente la plus courante, et la plus facile à relâcher ensuite.
  max_uses integer check (max_uses is null or max_uses > 0),
  max_uses_per_client integer not null default 1 check (max_uses_per_client > 0),

  -- Montant minimum du panier **chez ce fournisseur**, hors livraison.
  min_order_fcfa integer check (min_order_fcfa is null or min_order_fcfa >= 0),

  -- Maintenu par `place_order`, jamais par l'app.
  uses_count integer not null default 0,

  label text,
  created_at timestamptz not null default now(),

  unique (supplier_id, code),
  constraint promo_code_window_ordered
    check (ends_at is null or starts_at is null or ends_at > starts_at)
);

create index promo_codes_lookup_idx on public.promo_codes (code) where is_active;

-- Les produits couverts. **Vide = tous les produits du fournisseur** : c'est
-- le cas le plus courant (« -10% sur ma boutique »), et l'écran le dit.
create table public.promo_code_products (
  promo_code_id text not null references public.promo_codes(id) on delete cascade,
  product_id text not null references public.products(id) on delete cascade,
  primary key (promo_code_id, product_id)
);

-- Une utilisation, et le détail de ce qu'elle a remisé.
create table public.promo_code_redemptions (
  id text primary key default gen_random_uuid()::text,
  promo_code_id text not null references public.promo_codes(id) on delete cascade,
  order_id text not null references public.orders(id) on delete cascade,
  supplier_group_id text not null references public.order_supplier_groups(id) on delete cascade,
  client_id uuid not null references public.profiles(id) on delete cascade,
  client_display_name_snapshot text,
  discount_fcfa integer not null,
  created_at timestamptz not null default now(),

  -- Un code ne se consomme qu'une fois par groupe fournisseur.
  unique (promo_code_id, supplier_group_id)
);

create index promo_code_redemptions_code_idx
  on public.promo_code_redemptions (promo_code_id, created_at desc);

create table public.promo_code_redemption_items (
  id text primary key default gen_random_uuid()::text,
  redemption_id text not null
    references public.promo_code_redemptions(id) on delete cascade,
  product_id text not null,

  -- Figé : le produit peut être renommé ou retiré, l'historique du
  -- fournisseur doit rester lisible des mois après.
  product_name_snapshot text not null,
  quantity integer not null,
  unit_discount_fcfa integer not null
);

create index promo_code_redemption_items_redemption_idx
  on public.promo_code_redemption_items (redemption_id);

create or replace function public.stamp_promo_code_supplier()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.supplier_id := public.operating_supplier_id();
  if new.supplier_id is null then
    raise exception 'Réservé à un compte fournisseur.';
  end if;
  new.code := upper(btrim(new.code));
  return new;
end;
$$;

create trigger promo_codes_stamp_supplier
  before insert or update on public.promo_codes
  for each row execute function public.stamp_promo_code_supplier();

-- Un produit couvert doit appartenir au fournisseur du code. Vérifié ici et
-- pas seulement dans la policy : c'est la condition qui donne son sens à
-- « les codes d'un fournisseur ne valent que sur ses produits ».
create or replace function public.check_promo_code_product_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code_owner uuid;
  v_product_owner uuid;
begin
  select supplier_id into v_code_owner
    from public.promo_codes where id = new.promo_code_id;
  select supplier_id into v_product_owner
    from public.products where id = new.product_id;

  if v_code_owner is null or v_product_owner is null
     or v_code_owner is distinct from v_product_owner then
    raise exception 'Un code promo ne peut couvrir que les produits de son fournisseur.';
  end if;
  return new;
end;
$$;

create trigger promo_code_products_check_owner
  before insert or update on public.promo_code_products
  for each row execute function public.check_promo_code_product_owner();

alter table public.promo_codes enable row level security;
alter table public.promo_code_products enable row level security;
alter table public.promo_code_redemptions enable row level security;
alter table public.promo_code_redemption_items enable row level security;

-- Le fournisseur gère les siens. **Aucune policy de lecture pour les
-- clients** : sans cela, n'importe qui listerait tous les codes en vigueur.
create policy "promo_codes_owner" on public.promo_codes
  for all using (supplier_id = public.operating_supplier_id())
  with check (supplier_id = public.operating_supplier_id());

create policy "promo_code_products_owner" on public.promo_code_products
  for all using (
    exists (
      select 1 from public.promo_codes c
       where c.id = promo_code_id
         and c.supplier_id = public.operating_supplier_id()
    )
  ) with check (
    exists (
      select 1 from public.promo_codes c
       where c.id = promo_code_id
         and c.supplier_id = public.operating_supplier_id()
    )
  );

-- L'utilisation est lisible du fournisseur (sa gestion) et du client (sa
-- commande). Écrite uniquement par `place_order`.
create policy "promo_code_redemptions_visible" on public.promo_code_redemptions
  for select using (
    client_id = auth.uid()
    or exists (
      select 1 from public.promo_codes c
       where c.id = promo_code_id
         and c.supplier_id = public.operating_supplier_id()
    )
  );

create policy "promo_code_redemption_items_visible"
  on public.promo_code_redemption_items
  for select using (
    exists (
      select 1 from public.promo_code_redemptions r
       where r.id = redemption_id
         and (
           r.client_id = auth.uid()
           or exists (
             select 1 from public.promo_codes c
              where c.id = r.promo_code_id
                and c.supplier_id = public.operating_supplier_id()
           )
         )
    )
  );

grant select, insert, update, delete on public.promo_codes to authenticated;
grant select, insert, update, delete on public.promo_code_products to authenticated;
grant select on public.promo_code_redemptions to authenticated;
grant select on public.promo_code_redemption_items to authenticated;
