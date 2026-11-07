-- Un avis public ne dit plus qui l'a écrit, ni pour quelle commande.
--
-- Signalé par l'audit : `reviews_select_public` (`using (true)`) ouvrait la
-- ligne entière à tout le monde, sans connexion — `client_id`, `order_id`,
-- `supplier_group_id` compris. L'écran public d'une boutique les lisait en
-- `select *` (`watchForSupplier`), sans jamais les afficher.
--
-- Un identifiant de compte n'ouvre plus grand-chose depuis `0128` (on ne
-- rattache plus un compte à sa boutique en le connaissant), mais il relie
-- les avis d'une même personne entre eux, et la commande à son auteur.
--
-- Désormais :
--
--   * la ligne entière ne se lit que par son auteur, la boutique concernée
--     (pour y répondre) et le staff ;
--   * le public lit les avis d'une boutique par `fetch_supplier_reviews`,
--     qui ne rend que ce qui s'affiche — exactement comme
--     `fetch_product_reviews` (`0061`) le fait déjà sur une fiche produit.
--
-- Aucune autre politique ni fonction ne s'appuyait sur la lecture publique
-- de `reviews` : celles qui la consultent sont `security definer`
-- (`has_reviewed_supplier`, `stamp_review_comment_author`, les résumés).

drop policy if exists reviews_select_public on public.reviews;
drop policy if exists reviews_select_parties on public.reviews;
create policy reviews_select_parties on public.reviews
  for select using (
    client_id = auth.uid()
    or supplier_id = public.operating_supplier_id()
    or public.is_staff()
  );

-- Les avis d'une boutique, du plus récent au plus ancien, avec leurs
-- commentaires. La forme de `fetch_product_reviews`, pour que l'app les
-- lise avec la même entité (`ProductReview`).
create or replace function public.fetch_supplier_reviews(
  p_supplier_id uuid,
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(t.row order by t.rang), '[]'::jsonb) from (
    select jsonb_build_object(
             'id', r.id,
             'stars', r.stars,
             'title', r.title,
             'comment', r.comment,
             'created_at', r.created_at,
             'author_name', coalesce(r.client_display_name_snapshot, 'Client MTC'),
             'image_paths', to_jsonb(r.image_paths),
             'video_path', r.video_path,
             'supplier_reply', r.supplier_reply,
             'supplier_replied_at', r.supplier_replied_at,
             'comments', coalesce((
               select jsonb_agg(jsonb_build_object(
                        'id', c.id,
                        'body', c.body,
                        'created_at', c.created_at,
                        'author_name', coalesce(c.author_display_name_snapshot, 'Client MTC'),
                        'author_is_supplier', c.author_is_supplier,
                        'image_paths', to_jsonb(c.image_paths),
                        'video_path', c.video_path
                      ) order by c.created_at)
                 from public.review_comments c
                where c.review_id = r.id
             ), '[]'::jsonb)
           ) as row,
           row_number() over (order by r.created_at desc, r.id) as rang
      from public.reviews r
      -- Une boutique supprimée n'a plus de vitrine, donc plus d'avis à
      -- montrer — comme ses produits (`products_select_public`).
      join public.suppliers s on s.id = r.supplier_id and s.deleted_at is null
     where r.supplier_id = p_supplier_id
     order by rang
     limit least(coalesce(p_limit, 20), 50)
    offset greatest(coalesce(p_offset, 0), 0)
  ) t;
$$;

revoke all on function public.fetch_supplier_reviews(uuid, integer, integer) from public;
grant execute on function public.fetch_supplier_reviews(uuid, integer, integer) to anon, authenticated;

notify pgrst, 'reload schema';
