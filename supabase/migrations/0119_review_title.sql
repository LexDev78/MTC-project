-- Un titre d'avis, facultatif (« Set a Title for your review » de la
-- maquette « Add review » du kit FlutterShop) : une ligne qui résume, 100
-- caractères au plus.
alter table public.reviews
  add column if not exists title text;

alter table public.reviews
  drop constraint if exists reviews_title_length;
alter table public.reviews
  add constraint reviews_title_length
  check (title is null or char_length(title) between 1 and 100);

-- `submit_review` (`0063`) gagne un paramètre : l'ancienne signature est
-- retirée, sans quoi PostgREST verrait deux fonctions candidates. Le titre a
-- une valeur par défaut, donc un appel sans lui continue de marcher.
drop function if exists public.submit_review(text, text, integer, text, text[], text);

create or replace function public.submit_review(
  p_order_id text,
  p_supplier_group_id text,
  p_stars integer,
  p_comment text,
  p_image_paths text[] default '{}'::text[],
  p_video_path text default null,
  p_title text default null
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_client uuid := auth.uid();
  v_supplier_id uuid;
  v_group_status public.order_status;
  v_review_id text := gen_random_uuid()::text;
  v_average double precision;
  v_count integer;
  -- Vide ou blanc = pas de titre.
  v_title text := nullif(btrim(coalesce(p_title, '')), '');
begin
  if v_client is null then
    raise exception 'Vous devez être connecté pour laisser un avis.';
  end if;
  if p_stars is null or p_stars < 1 or p_stars > 5 then
    raise exception 'Une note va de 1 à 5 étoiles.';
  end if;
  if coalesce(btrim(p_comment), '') = '' then
    raise exception 'Un avis doit comporter un commentaire.';
  end if;
  if char_length(v_title) > 100 then
    raise exception 'Le titre ne doit pas dépasser 100 caractères.';
  end if;

  select g.supplier_id, g.status into v_supplier_id, v_group_status
    from public.order_supplier_groups g
    join public.orders o on o.id = g.order_id
   where g.id = p_supplier_group_id
     and g.order_id = p_order_id
     and o.client_id = v_client;

  if v_supplier_id is null then
    raise exception 'Commande introuvable, ou elle n''est pas la vôtre.';
  end if;
  if v_group_status <> 'delivered' then
    raise exception 'Vous pourrez noter cette commande une fois livrée.';
  end if;
  if exists (
    select 1 from public.reviews
     where order_id = p_order_id and supplier_group_id = p_supplier_group_id
  ) then
    raise exception 'Vous avez déjà noté cette commande.';
  end if;

  insert into public.reviews (
    id, order_id, supplier_group_id, client_id, supplier_id,
    stars, title, comment, image_paths, video_path
  ) values (
    v_review_id, p_order_id, p_supplier_group_id, v_client, v_supplier_id,
    p_stars, v_title, btrim(p_comment), coalesce(p_image_paths, '{}'),
    p_video_path
  );

  -- Le cumul se fait dans l'instruction : la ligne est verrouillée le temps
  -- du calcul, donc deux avis simultanés comptent tous les deux.
  update public.suppliers
     set rating_average =
           ((rating_average * rating_count) + p_stars) / (rating_count + 1),
         rating_count = rating_count + 1
   where id = v_supplier_id
   returning rating_average, rating_count into v_average, v_count;

  -- Recopie dénormalisée sur les produits, pour que le tri du catalogue
  -- n'ait pas à joindre `suppliers`.
  update public.products
     set rating_average = v_average, rating_count = v_count
   where supplier_id = v_supplier_id;

  -- Le titre, quand il y en a un, résume mieux que le début du texte.
  insert into public.notifications (id, user_id, type, title, body, reference_id)
  values (
    gen_random_uuid()::text, v_supplier_id, 'new_review', 'Nouvel avis',
    p_stars || '★ — ' || coalesce(v_title, btrim(p_comment)), v_review_id
  );

  return v_review_id;
end;
$$;

revoke all on function
  public.submit_review(text, text, integer, text, text[], text, text)
  from public, anon;
grant execute on function
  public.submit_review(text, text, integer, text, text[], text, text)
  to authenticated;

-- Les avis d'un produit (`0114`) rendent aussi le titre.
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
