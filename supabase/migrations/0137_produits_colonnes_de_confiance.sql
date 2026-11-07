-- 0137 — Ce que 0136 laissait encore passer sur un produit (audit du
-- 27/10/2026, faille 2, revérifiée le 05/11/2026 sur une base neuve).
--
-- Rejoué avec 0136, le produit forgé par une boutique en attente garde
-- « 5★ sur 999 avis » : le garde-fou de la note (`guard_product_rating`)
-- ne joue qu'à la modification, et l'insertion écrit ce qu'elle veut. Même
-- chose pour `view_count` (le tri « populaires »), `created_at` (le tri
-- « nouveautés ») et les trois agrégats des variantes (`has_variants`,
-- `variant_count`, `max_price_fcfa`), que seul le déclencheur des variantes
-- doit écrire — l'app ne les envoie d'ailleurs jamais
-- (`_stripComputedFields`, `supabase_product_repository.dart`).
--
-- Deux corrections au passage :
--
--  * La note d'un produit n'est pas la sienne : c'est la copie de celle de
--    la boutique (`submit_review` la recopie sur tous ses produits). Un
--    produit neuf naît donc avec la note de sa boutique, pas avec zéro —
--    sinon le premier produit d'une boutique notée 4,6 afficherait 0★
--    jusqu'au prochain avis.
--  * Qui est « de confiance » se lit sur `current_user`, comme le font déjà
--    `guard_product_rating` et `guard_supplier_badges` : une requête de
--    l'API s'exécute sous `authenticated`, une fonction de la base sous son
--    propriétaire. Le test de 0136 (`auth.uid() is null`) laissait la
--    fonction s'exécuter pour `increment_product_view`, qui a un
--    `auth.uid()` : figer `view_count` à la modification aurait cassé le
--    compteur de vues. La fonction devient donc SECURITY INVOKER — c'est
--    la condition pour que `current_user` dise qui écrit — et lit la
--    boutique par une fonction dédiée.
--
-- Le drapeau `is_supplier_verified` naît désormais faux : un produit
-- inséré sans passer par ce déclencheur (service, script) n'est plus public
-- par défaut.

-- ------------------------------------------------- 1. la boutique, vue d'ici
-- Ce qu'un produit recopie de sa boutique. Tout y est déjà public (la
-- vitrine montre le nom, le type, le badge vérifié et la note) : la
-- fonction n'ouvre rien, elle évite seulement au déclencheur de dépendre
-- des droits de colonne de `suppliers`.
create or replace function public.product_trusted_source(p_supplier_id uuid)
returns table (
  business_name text,
  supplier_type public.supplier_type,
  is_verified boolean,
  rating_average double precision,
  rating_count integer
)
language sql
stable
security definer
set search_path = public
as $$
  select s.business_name,
         s.supplier_type,
         -- La boutique officielle n'a pas de dossier : elle est vérifiée
         -- par nature (ses produits le sont déjà dans le semis).
         coalesce(s.verification_status = 'verified', false)
           or s.supplier_type = 'principal',
         s.rating_average,
         s.rating_count
    from public.suppliers s
   where s.id = p_supplier_id
     -- Une boutique supprimée n'a rien à transmettre (contre-vérification
     -- du 06/11/2026 : la fonction la montrait à tout compte connecté).
     and s.deleted_at is null;
$$;

revoke all on function public.product_trusted_source(uuid) from public, anon;
grant execute on function public.product_trusted_source(uuid) to authenticated;

-- ------------------------------------------- 2. les colonnes de confiance
create or replace function public.stamp_product_trusted_columns()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_source record;
begin
  -- Une fonction de la base (place_order, submit_review,
  -- increment_product_view, agrégats des variantes, décision KYC) écrit
  -- sous son propriétaire : elle passe. Le staff, lui, n'est pas exempté :
  -- ses décisions de vérification passent par
  -- `set_products_supplier_verification`, et la boutique officielle qu'il
  -- opère est vérifiée par nature (`product_trusted_source`) — l'app ne
  -- lui fait rien écrire d'autre que ce que ce déclencheur calcule.
  if current_user not in ('anon', 'authenticated') then
    return new;
  end if;

  select * into v_source from public.product_trusted_source(new.supplier_id);

  new.supplier_name := coalesce(v_source.business_name, new.supplier_name);
  new.supplier_type := coalesce(v_source.supplier_type, new.supplier_type);

  if tg_op = 'INSERT' then
    new.is_supplier_verified := coalesce(v_source.is_verified, false);
    new.rating_average := coalesce(v_source.rating_average, 0);
    new.rating_count := coalesce(v_source.rating_count, 0);
    new.view_count := 0;
    new.created_at := now();
    -- Recalculés par `recompute_product_variant_aggregates` dès la
    -- première variante.
    new.has_variants := false;
    new.variant_count := 0;
    new.max_price_fcfa := null;
  else
    if new.id is distinct from old.id then
      raise exception 'L''identifiant d''un produit ne change pas.';
    end if;
    if new.supplier_id is distinct from old.supplier_id then
      -- Un produit qui change de boutique (le staff seul le peut) prend la
      -- vérification de sa nouvelle boutique : sinon le produit d'une
      -- boutique vérifiée, passé à une boutique en attente, restait public.
      new.is_supplier_verified := coalesce(v_source.is_verified, false);
    else
      -- Seul le staff (set_products_supplier_verification,
      -- review_supplier_kyc) change ce drapeau.
      new.is_supplier_verified := old.is_supplier_verified;
    end if;
    new.view_count := old.view_count;
    new.created_at := old.created_at;
    new.has_variants := old.has_variants;
    new.variant_count := old.variant_count;
    new.max_price_fcfa := old.max_price_fcfa;
    -- La note : `guard_product_rating` refuse déjà, plus tôt.
  end if;

  return new;
end;
$$;

revoke all on function public.stamp_product_trusted_columns() from public, anon, authenticated;

-- Le déclencheur est celui de 0136 ; on le repose pour ne pas dépendre de
-- l'ordre d'application si 0136 a été rejouée à part.
drop trigger if exists products_stamp_trusted_columns on public.products;
create trigger products_stamp_trusted_columns
  before insert or update on public.products
  for each row execute function public.stamp_product_trusted_columns();

alter table public.products alter column is_supplier_verified set default false;

-- ------------------------------------------------ 3. les lignes déjà forgées
-- Hors de tout contexte utilisateur (`current_user` = propriétaire) : les
-- garde-fous laissent passer. Tout ce que la base sait recalculer l'est ;
-- `view_count` et `created_at` forgés, eux, ne se devinent pas.
update public.products p
   set supplier_name = s.business_name,
       supplier_type = s.supplier_type,
       is_supplier_verified =
         coalesce(s.verification_status = 'verified', false)
         or s.supplier_type = 'principal',
       rating_average = s.rating_average,
       rating_count = s.rating_count
  from public.suppliers s
 where s.id = p.supplier_id
   and (p.supplier_name is distinct from s.business_name
        or p.supplier_type is distinct from s.supplier_type
        or p.is_supplier_verified is distinct from
             (coalesce(s.verification_status = 'verified', false)
              or s.supplier_type = 'principal')
        or p.rating_average is distinct from s.rating_average
        or p.rating_count is distinct from s.rating_count);

-- Un produit actif sans variante n'existe pas légitimement (contrôle différé
-- `products_active_requires_variants`) : seul un `has_variants` forgé l'a
-- fait passer. Il repasse en brouillon avant la remise d'aplomb de ses
-- agrégats, sans quoi le contrôle refuserait la migration elle-même.
update public.products p
   set status = 'draft'
 where p.status = 'active'
   and not exists (select 1 from public.product_variants v where v.product_id = p.id);

-- Les agrégats des variantes, recalculés depuis les variantes elles-mêmes.
update public.products p
   set has_variants = a.n > 0,
       variant_count = a.n,
       max_price_fcfa = a.max_price
  from (
    select p2.id,
           count(v.id)::int as n,
           max(v.price_fcfa) as max_price
      from public.products p2
      left join public.product_variants v on v.product_id = p2.id
     group by p2.id
  ) a
 where a.id = p.id
   and (p.has_variants is distinct from (a.n > 0)
        or p.variant_count is distinct from a.n
        or p.max_price_fcfa is distinct from a.max_price);
