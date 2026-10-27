-- Le rapprochement d'une photo avec le catalogue.
--
-- `0081` a posé la table des empreintes, son index cosinus et le plafond
-- d'appels ; il manquait la seule chose qui s'en sert : comparer un vecteur
-- de requête au catalogue, et écrire les empreintes.
--
-- C'est volontairement la base qui compare, et non la fonction edge : les
-- vecteurs ne sortent pas (`product_embeddings` n'est lisible ni par `anon`
-- ni par `authenticated`), et comparer ailleurs voudrait dire les
-- transférer.
--
-- Tout est réservé à `service_role`. Le client n'a pas de vecteur à
-- présenter — il envoie une photo à la fonction edge, qui calcule
-- l'empreinte et appelle ceci. Lui ouvrir la recherche reviendrait à lui
-- laisser sonder l'espace vectoriel point par point, c'est-à-dire
-- reconstituer les empreintes qu'on refuse de lui montrer.

create or replace function public.search_products_by_embedding(
  p_embedding extensions.vector(1024),
  p_limit integer default 24,
  p_min_similarity double precision default 0.25
) returns table (product_id text, similarity double precision)
language sql
stable
security definer
set search_path = public, extensions
as $$
  select e.product_id, 1 - (e.embedding <=> p_embedding) as similarity
    from public.product_embeddings e
    join public.products p on p.id = e.product_id
   -- Mêmes conditions de visibilité que le catalogue : une recherche par
   -- photo ne doit pas faire apparaître un brouillon, ni le produit d'un
   -- fournisseur non vérifié.
   where p.status = 'active'
     and p.is_supplier_verified
   -- Un seuil, parce qu'une photo de quelque chose d'absent du catalogue
   -- rend sinon les 24 produits les « moins éloignés » — c'est-à-dire du
   -- hasard présenté comme un résultat. Mieux vaut ne rien proposer.
     and 1 - (e.embedding <=> p_embedding) >= p_min_similarity
   order by e.embedding <=> p_embedding
   limit least(coalesce(p_limit, 24), 50);
$$;

revoke all on function public.search_products_by_embedding(extensions.vector, integer, double precision)
  from public, anon, authenticated;
grant execute on function public.search_products_by_embedding(extensions.vector, integer, double precision)
  to service_role;

-- Enregistre l'empreinte d'un produit. Appelée par la fonction edge
-- d'indexation, jamais par l'app.
--
-- `on conflict` plutôt qu'un `delete` suivi d'un `insert` : réindexer un
-- produit ne doit pas le faire disparaître des résultats entre les deux.
create or replace function public.upsert_product_embedding(
  p_product_id text,
  p_embedding extensions.vector(1024),
  p_model text,
  p_source_image_url text
) returns void
language sql
security definer
set search_path = public, extensions
as $$
  insert into public.product_embeddings
    (product_id, embedding, model, source_image_url, updated_at)
  values (p_product_id, p_embedding, p_model, p_source_image_url, now())
  on conflict (product_id) do update
     set embedding = excluded.embedding,
         model = excluded.model,
         source_image_url = excluded.source_image_url,
         updated_at = now();
$$;

revoke all on function public.upsert_product_embedding(text, extensions.vector, text, text)
  from public, anon, authenticated;
grant execute on function public.upsert_product_embedding(text, extensions.vector, text, text)
  to service_role;

-- Les produits qui attendent une empreinte : jamais indexés, ou dont la
-- photo retenue n'est plus celle d'aujourd'hui.
--
-- `products` ne porte pas de date de modification, et en ajouter une pour
-- ce seul besoin obligerait à la maintenir partout. On compare donc ce qui
-- décide vraiment du vecteur : l'image source. Un produit renommé sans
-- changer de photo n'est pas réindexé — son empreinte est multimodale, mais
-- c'est l'image qui la domine, et le coût d'un appel ne se justifie pas
-- pour un mot changé.
create or replace function public.products_needing_embedding(p_limit integer default 50)
returns table (product_id text, name text, description text, image_url text)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.name, p.description, p.image_urls[1]
    from public.products p
    left join public.product_embeddings e on e.product_id = p.id
   where p.status = 'active'
     and p.is_supplier_verified
     and coalesce(array_length(p.image_urls, 1), 0) > 0
     and (e.product_id is null or e.source_image_url is distinct from p.image_urls[1])
   order by p.created_at desc
   limit least(coalesce(p_limit, 50), 200);
$$;

revoke all on function public.products_needing_embedding(integer)
  from public, anon, authenticated;
grant execute on function public.products_needing_embedding(integer) to service_role;
