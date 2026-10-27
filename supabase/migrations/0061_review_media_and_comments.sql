-- Les avis deviennent lisibles sur la fiche produit, avec photos, vidéo et
-- commentaires.
--
-- Jusqu'ici un avis n'était vu que du fournisseur noté : il n'existait aucun
-- chemin entre un avis et un produit, parce qu'un avis porte sur un
-- **groupe fournisseur** (une commande chez un vendeur), pas sur un article.
-- Le lien se reconstruit par les lignes de commande : les avis affichés sur
-- une fiche sont ceux de commandes qui contenaient ce produit. C'est le seul
-- rattachement honnête — et l'écran le dit ainsi (« acheteurs de ce
-- produit ») plutôt que de faire croire à une note article par article.
--
-- Trois ajouts :
--
--  1. médias sur l'avis — c'est la photo d'un acheteur, pas celle du
--     vendeur, qui fait la valeur d'un avis ;
--  2. commentaires sur l'avis, eux aussi avec médias : un autre client peut
--     demander un détail, montrer le même produit reçu autrement, et le
--     fournisseur peut répondre publiquement ;
--  3. une lecture publique qui assemble tout ça pour une fiche produit.
--
-- Rien de ce qui identifie l'auteur n'est pris sur parole : `profiles` n'est
-- lisible que par son propriétaire, donc le nom affiché doit être figé à
-- l'écriture — et figé **par la base**, sinon n'importe qui publierait un
-- avis signé du nom d'un autre.

alter table public.reviews
  add column if not exists image_paths text[] not null default '{}',
  add column if not exists video_path text,
  add column if not exists client_display_name_snapshot text;

grant select (image_paths, video_path, client_display_name_snapshot)
  on public.reviews to anon, authenticated;
grant insert (image_paths, video_path) on public.reviews to authenticated;
-- Pas de `grant` sur `client_display_name_snapshot` : il est posé par le
-- trigger ci-dessous, pas par l'auteur.

create table public.review_comments (
  id text primary key default gen_random_uuid()::text,
  review_id text not null references public.reviews(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  author_display_name_snapshot text,

  -- Un commentaire du vendeur ne se lit pas comme celui d'un acheteur : la
  -- distinction est calculée à l'écriture, pas déclarée par l'auteur.
  author_is_supplier boolean not null default false,

  body text not null check (length(btrim(body)) > 0),
  image_paths text[] not null default '{}',
  video_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create index review_comments_review_idx
  on public.review_comments (review_id, created_at);

-- Garde-fou commun aux avis et à leurs commentaires.
--
-- Deux choses à vérifier sur des chemins de médias venus du client :
--
--  * le premier segment doit être l'auteur. C'est la convention de tous les
--    buckets du projet (`0001`, section 7) et c'est ce que la policy Storage
--    impose à l'envoi ; sans ce contrôle ici, on pourrait publier un avis
--    qui **affiche** le fichier d'un autre compte en le désignant ;
--  * le nombre. Une galerie sans plafond laisse un seul avis occuper la
--    fiche entière.
create or replace function public.validate_media_paths(
  p_paths text[],
  p_owner uuid,
  p_max integer
) returns void
language plpgsql
immutable
set search_path = public
as $$
declare
  v_path text;
begin
  if coalesce(array_length(p_paths, 1), 0) > p_max then
    raise exception 'Pas plus de % fichiers.', p_max;
  end if;
  foreach v_path in array coalesce(p_paths, '{}')
  loop
    if split_part(v_path, '/', 1) <> p_owner::text then
      raise exception 'Chemin de fichier invalide : %', v_path;
    end if;
  end loop;
end;
$$;

create or replace function public.stamp_review_author()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Pris sur `client_id` et non sur `auth.uid()` : le fournisseur écrit
  -- aussi dans cette ligne (sa réponse publique), et le nom affiché doit
  -- rester celui de l'auteur de l'avis dans les deux cas.
  select p.display_name into new.client_display_name_snapshot
    from public.profiles p where p.id = new.client_id;

  perform public.validate_media_paths(new.image_paths, new.client_id, 6);
  if new.video_path is not null then
    perform public.validate_media_paths(
      array[new.video_path], new.client_id, 1
    );
  end if;
  return new;
end;
$$;

create trigger reviews_stamp_author
  before insert or update on public.reviews
  for each row execute function public.stamp_review_author();

-- Reprise des avis déjà déposés : sans cela, les anciens s'afficheraient
-- sans nom sur les fiches produit.
update public.reviews r
   set client_display_name_snapshot = p.display_name
  from public.profiles p
 where p.id = r.client_id
   and r.client_display_name_snapshot is null;

create or replace function public.stamp_review_comment_author()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supplier_id uuid;
begin
  -- L'auteur est l'appelant, quoi qu'en dise la requête.
  new.author_id := auth.uid();
  if new.author_id is null then
    raise exception 'Vous devez être connecté pour commenter un avis.';
  end if;

  select p.display_name into new.author_display_name_snapshot
    from public.profiles p where p.id = new.author_id;

  select r.supplier_id into v_supplier_id
    from public.reviews r where r.id = new.review_id;
  if v_supplier_id is null then
    raise exception 'Avis introuvable : %', new.review_id;
  end if;
  new.author_is_supplier :=
    v_supplier_id is not distinct from public.operating_supplier_id();

  perform public.validate_media_paths(new.image_paths, new.author_id, 4);
  if new.video_path is not null then
    perform public.validate_media_paths(
      array[new.video_path], new.author_id, 1
    );
  end if;

  if tg_op = 'UPDATE' then
    new.created_at := old.created_at;
    new.updated_at := now();
  end if;
  return new;
end;
$$;

create trigger review_comments_stamp_author
  before insert or update on public.review_comments
  for each row execute function public.stamp_review_comment_author();

alter table public.review_comments enable row level security;

-- Lecture publique, comme les avis eux-mêmes (`reviews_select_public`) :
-- c'est le point de la fonctionnalité, un visiteur sans compte doit pouvoir
-- les lire avant d'acheter.
create policy "review_comments_select_public" on public.review_comments
  for select using (true);

create policy "review_comments_insert_self" on public.review_comments
  for insert with check (author_id = auth.uid());

-- Corriger ou retirer son propre commentaire. Le staff peut retirer celui
-- d'un autre : une lecture publique sans aucune modération laisserait le
-- premier venu afficher n'importe quoi sous une fiche produit.
create policy "review_comments_update_own" on public.review_comments
  for update using (author_id = auth.uid()) with check (author_id = auth.uid());

create policy "review_comments_delete_own_or_staff" on public.review_comments
  for delete using (author_id = auth.uid() or public.is_staff());

grant select on public.review_comments to anon, authenticated;
grant insert, update, delete on public.review_comments to authenticated;

-- Médias d'avis : publics en lecture (ils accompagnent un avis public),
-- rangés par auteur comme partout ailleurs.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'review-media', 'review-media', true, 26214400,
  array['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/quicktime']
) on conflict (id) do nothing;

create policy "review_media_public_read" on storage.objects
  for select using (bucket_id = 'review-media');

create policy "review_media_author_write" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'review-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "review_media_author_delete" on storage.objects
  for delete to authenticated using (
    bucket_id = 'review-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Les avis des acheteurs d'un produit, avec leurs commentaires.
--
-- `security definer` par nécessité, pas par confort : le rattachement passe
-- par `order_items`, que ni `anon` ni un autre client ne peut lire. La
-- fonction ne renvoie pour autant rien de la commande — ni montants, ni
-- adresse, ni acheteur autre que le prénom déjà public de l'avis.
create or replace function public.fetch_product_reviews(
  p_product_id text,
  p_limit integer default 20,
  p_offset integer default 0
) returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(row), '[]'::jsonb) from (
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
           ) as row
      from public.reviews r
     where exists (
       select 1
         from public.order_items i
         join public.order_supplier_groups g on g.id = i.group_id
        where i.group_id = r.supplier_group_id
          and i.product_id = p_product_id
          and g.status = 'delivered'
     )
     order by r.created_at desc
     limit least(coalesce(p_limit, 20), 50)
    offset greatest(coalesce(p_offset, 0), 0)
  ) t;
$$;

grant execute on function public.fetch_product_reviews(text, integer, integer)
  to anon, authenticated;

-- Le résumé affiché en tête de section. Distinct de `products.rating_average`,
-- qui recopie la note du **fournisseur** sur tous ses produits : ici c'est la
-- note des acheteurs de ce produit-là.
create or replace function public.fetch_product_review_summary(p_product_id text)
returns table (review_count integer, rating_average numeric)
language sql
security definer
set search_path = public
as $$
  select count(*)::integer,
         coalesce(round(avg(r.stars)::numeric, 2), 0)
    from public.reviews r
   where exists (
     select 1
       from public.order_items i
       join public.order_supplier_groups g on g.id = i.group_id
      where i.group_id = r.supplier_group_id
        and i.product_id = p_product_id
        and g.status = 'delivered'
   );
$$;

grant execute on function public.fetch_product_review_summary(text)
  to anon, authenticated;
