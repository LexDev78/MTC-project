-- Les avis d'un produit, dans l'ordre que le lecteur choisit.
--
-- L'écran « Avis » du kit FlutterShop porte un menu de tri au-dessus de la
-- liste. Trier côté app ne vaudrait que pour la page déjà chargée : la liste
-- est paginée par 20, et « les mieux notés » parmi les vingt plus récents
-- n'est pas « les mieux notés ». Le tri se fait donc ici, avant la
-- pagination.
--
-- Quatre ordres, le premier restant celui de `0061` :
--   'recent' — les plus récents d'abord ;
--   'best'   — les meilleures notes d'abord ;
--   'worst'  — les moins bonnes d'abord ;
--   'media'  — ceux qui ont des photos ou une vidéo d'abord.
-- À égalité, le plus récent passe devant, puis l'identifiant : sans ce
-- dernier départage, deux avis de la même seconde pourraient changer de page
-- d'une lecture à l'autre, et l'un s'afficher deux fois pendant que l'autre
-- disparaît. Une valeur inconnue retombe sur 'recent'.
--
-- La signature change (un paramètre de plus) : l'ancienne est retirée, sans
-- quoi PostgREST verrait deux fonctions candidates pour un même appel à trois
-- paramètres nommés. Le nouveau paramètre a une valeur par défaut, donc les
-- appels existants continuent de marcher tels quels.
drop function if exists public.fetch_product_reviews(text, integer, integer);

create or replace function public.fetch_product_reviews(
  p_product_id text,
  p_limit integer default 20,
  p_offset integer default 0,
  p_sort text default 'recent'
) returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(t.row order by t.rang), '[]'::jsonb) from (
    select jsonb_build_object(
             'id', r.id,
             'stars', r.stars,
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
           row_number() over (
             order by
               case when p_sort = 'best' then r.stars end desc nulls last,
               case when p_sort = 'worst' then r.stars end asc nulls last,
               case when p_sort = 'media'
                    then cardinality(r.image_paths) > 0 or r.video_path is not null
               end desc nulls last,
               r.created_at desc,
               r.id
           ) as rang
      from public.reviews r
     where exists (
       select 1
         from public.order_items i
         join public.order_supplier_groups g on g.id = i.group_id
        where i.group_id = r.supplier_group_id
          and i.product_id = p_product_id
          and g.status = 'delivered'
     )
     order by rang
     limit least(coalesce(p_limit, 20), 50)
    offset greatest(coalesce(p_offset, 0), 0)
  ) t;
$$;

grant execute on function public.fetch_product_reviews(text, integer, integer, text)
  to anon, authenticated;
