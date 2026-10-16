-- « Y a-t-il un code promo à saisir ? », sans dire lequel.
--
-- L'écran de paiement affichait son champ « Code promo » à tout le monde,
-- tout le temps. Sur la quasi-totalité des paniers il n'existe aucun code
-- applicable : le champ ne sert alors qu'à faire croire qu'on rate quelque
-- chose, et à faire perdre du temps à qui essaie des codes au hasard.
--
-- L'app ne peut pas répondre seule à la question. `promo_codes` n'a aucune
-- policy de lecture pour les clients (`0071`), et c'est délibéré : l'ouvrir
-- reviendrait à publier la liste des codes en vigueur de toutes les
-- boutiques, c'est-à-dire à offrir les remises à ceux qui ne les ont pas
-- reçues.
--
-- D'où cette fonction : elle répond **un booléen**. Jamais le code, jamais
-- son pourcentage, jamais combien il en existe. Ce qu'elle divulgue —
-- « quelque chose existe pour ce panier » — est le strict minimum sans quoi
-- la fonctionnalité n'existe pas, et c'est une information que le client
-- obtiendrait de toute façon en essayant un code.
--
-- Les conditions reprennent **exactement** celles de `resolve_promo_code` et
-- de `promo_code_covers_product`, plus l'épuisement. Un écart ici se verrait
-- de la pire façon : un champ affiché que rien ne peut satisfaire, ou — pire
-- — un champ masqué alors que le client tient un code valable dans la main.
create or replace function public.cart_has_promo_code(p_product_ids text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.promo_codes c
      join public.products p
        on p.supplier_id = c.supplier_id
       and p.id = any (p_product_ids)
     where c.is_active
       and (c.starts_at is null or c.starts_at <= now())
       and (c.ends_at is null or c.ends_at > now())
       -- Épuisé pour tout le monde.
       and (c.max_uses is null or c.uses_count < c.max_uses)
       -- Épuisé pour **ce** client : un code à usage unique déjà consommé
       -- ne doit pas faire réapparaître le champ à la commande suivante.
       and (
         select count(*) from public.promo_code_redemptions r
          where r.promo_code_id = c.id and r.client_id = auth.uid()
       ) < c.max_uses_per_client
       and public.promo_code_covers_product(c.id, p.id)
  );
$$;

-- Le montant minimum de commande n'est volontairement **pas** testé ici.
-- Un code qui demande 50 000 FCFA sur un panier de 30 000 reste un code
-- qu'on peut saisir : `preview_promo_code` répond alors « achat minimum non
-- atteint », ce qui dit au client qu'il existe et ce qu'il faut pour
-- l'obtenir. Masquer le champ dans ce cas cacherait une remise accessible.

revoke all on function public.cart_has_promo_code(text[]) from public, anon;
grant execute on function public.cart_has_promo_code(text[]) to authenticated;
