-- Le contrôle différé doit relire la ligne avec ses propres droits.
--
-- `0056` lui a fait relire `public.products` au lieu de se fier à
-- `new.has_variants`. Mais la fonction était restée **`security invoker`**,
-- ce qui était sans conséquence tant qu'elle ne lisait que `new.*` : aucun
-- accès à une table, donc aucun droit requis.
--
-- Depuis qu'elle lit la table, le rôle sous lequel elle s'exécute compte.
-- Et il n'est pas celui qu'on croit : un déclencheur `DEFERRABLE INITIALLY
-- DEFERRED` ne se déclenche **qu'à la validation**, une fois le contexte
-- `security definer` de la RPC appelante dépilé. La relecture se faisait donc
-- sous le **rôle de session** :
--
--   permission denied for table products (42501)
--
-- — levé à la validation du semis de test (`service_role`, aucun droit de
-- lecture sur les tables : voir la section 6 de `0001`), et non à l'appel.
--
-- Deux raisons de la passer `security definer`, pas seulement celle-là :
--
--  * la garantie ne doit pas dépendre des droits de celui qui écrit ;
--  * en `invoker`, la relecture passe par la **RLS**. Une ligne masquée au
--    rédacteur ferait sortir la fonction par son `not found` — le contrôle
--    s'autoriserait lui-même, silencieusement. Lue par son propriétaire,
--    elle voit l'état réel.
--
-- Le corps ne fait qu'un `select` sur la ligne en cours de validation, sans
-- SQL dynamique et avec un `search_path` figé : rien n'en ressort que
-- l'exception.

create or replace function public.check_active_product_has_variants()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status public.product_status;
  v_has_variants boolean;
begin
  -- Relecture au moment de la validation, et non `new.*` : c'est tout
  -- l'intérêt d'un contrôle différé.
  select status, has_variants into v_status, v_has_variants
    from public.products where id = new.id;

  -- Ligne supprimée entre-temps : plus rien à garantir.
  if not found then return new; end if;

  if v_status = 'active' and not v_has_variants then
    raise exception
      'Un produit actif doit avoir au moins une caractéristique/variante (%).', new.id;
  end if;
  return new;
end;
$$;
