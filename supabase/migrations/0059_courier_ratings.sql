-- Notation des livreurs, par le client et par le fournisseur.
--
-- Les deux côtés d'une course jugent deux choses différentes : le
-- fournisseur a vu le retrait (ponctualité, soin du colis), le client a vu
-- la remise. Les confondre dans une note unique perdrait précisément ce qui
-- distingue un livreur qui arrive en retard chez le fournisseur d'un
-- livreur désagréable chez le client. D'où `rater_role` et une note par
-- côté, pas une par personne.
--
-- Rien n'est écrit en direct : comme pour les courses (`0046`), la table
-- n'a aucune policy d'écriture et tout passe par `rate_courier`. Les
-- conditions à vérifier ne sont pas exprimables dans un `with check`
-- raisonnable — il faut remonter la course à la commande pour savoir si
-- l'appelant est bien le client, ou au groupe pour savoir s'il est bien le
-- fournisseur, et refuser une note avant la livraison.

create type public.courier_rater_role as enum ('client', 'supplier');

create table public.courier_ratings (
  id text primary key default gen_random_uuid()::text,
  delivery_id text not null references public.deliveries(id) on delete cascade,
  -- Dénormalisé depuis la course : la moyenne se recalcule par livreur, et
  -- la course peut disparaître (cascade) sans qu'on perde de quoi la
  -- recalculer.
  courier_id uuid not null references public.couriers(id) on delete cascade,
  rater_id uuid not null references public.profiles(id) on delete cascade,
  rater_role public.courier_rater_role not null,
  stars integer not null check (stars between 1 and 5),
  comment text,
  created_at timestamptz not null default now(),
  updated_at timestamptz,

  -- Une note par côté et par course. Sur `rater_role` et non sur
  -- `rater_id` : si le fournisseur change de gérant entre-temps, c'est
  -- toujours une seule note fournisseur.
  unique (delivery_id, rater_role)
);

create index courier_ratings_courier_idx
  on public.courier_ratings (courier_id, created_at desc);

-- La moyenne vit sur la fiche du livreur, comme `suppliers.rating_average` :
-- elle est lue à chaque affichage et recalculée à chaque note, soit
-- infiniment moins souvent.
alter table public.couriers
  add column if not exists rating_average numeric(3, 2) not null default 0,
  add column if not exists rating_count integer not null default 0;

-- Sans ce grant, le livreur ne peut plus lire **sa propre fiche** : les
-- privilèges de `couriers` sont accordés colonne par colonne (`0046`), et
-- un `select()` PostgREST demande tout. Une colonne ajoutée sans son grant
-- casse donc la connexion du livreur, pas seulement l'affichage de la note.
grant select (rating_average, rating_count) on public.couriers to authenticated;
-- Pas de `grant update` : la note n'est pas une colonne de libre-service.
-- Seul le trigger ci-dessous y touche, et il s'exécute en `definer`.

create or replace function public.sync_courier_rating_aggregate()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_courier_id uuid := coalesce(new.courier_id, old.courier_id);
begin
  update public.couriers c
     set rating_count = agg.count,
         rating_average = agg.average
    from (
      select count(*) as count,
             coalesce(round(avg(stars)::numeric, 2), 0) as average
        from public.courier_ratings
       where courier_id = v_courier_id
    ) agg
   where c.id = v_courier_id;
  return null;
end;
$$;

create trigger courier_ratings_sync_aggregate
  after insert or update or delete on public.courier_ratings
  for each row execute function public.sync_courier_rating_aggregate();

alter table public.courier_ratings enable row level security;

-- Celui qui note relit sa note (pour la corriger, et pour que l'écran sache
-- qu'elle existe déjà). Le staff voit tout.
--
-- Le livreur, lui, n'est **pas** dans cette policy, volontairement : la
-- ligne porte `rater_id`, et il n'a pas à savoir qui l'a noté. Il lit ses
-- notes par `fetch_my_courier_ratings`, qui ne renvoie pas cette colonne.
create policy "courier_ratings_select_own_or_staff" on public.courier_ratings
  for select using (rater_id = auth.uid() or public.is_staff());

grant select on public.courier_ratings to authenticated;

-- Noter une course livrée.
--
-- Le rôle n'est pas un paramètre : il est **déduit** de l'appelant. Le
-- laisser passer par l'app permettrait au client de déposer une note
-- « fournisseur » et d'en poser deux.
create or replace function public.rate_courier(
  p_delivery_id text,
  p_stars integer,
  p_comment text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
  v_courier_id uuid;
  v_status public.delivery_status;
  v_client_id uuid;
  v_group_supplier_id uuid;
  v_role public.courier_rater_role;
  v_comment text := nullif(trim(coalesce(p_comment, '')), '');
begin
  if v_caller is null then
    raise exception 'Vous devez être connecté pour noter une livraison.';
  end if;
  if p_stars is null or p_stars < 1 or p_stars > 5 then
    raise exception 'Une note va de 1 à 5 étoiles.';
  end if;

  select d.courier_id, d.status, o.client_id, g.supplier_id
    into v_courier_id, v_status, v_client_id, v_group_supplier_id
    from public.deliveries d
    join public.orders o on o.id = d.order_id
    join public.order_supplier_groups g on g.id = d.supplier_group_id
   where d.id = p_delivery_id;

  if v_courier_id is null then
    raise exception 'Course introuvable ou sans livreur attribué.';
  end if;
  if v_status <> 'delivered' then
    raise exception 'Une course se note une fois livrée.';
  end if;

  if v_caller = v_client_id then
    v_role := 'client';
  elsif v_group_supplier_id = public.operating_supplier_id() then
    v_role := 'supplier';
  else
    raise exception 'Seuls le client et le fournisseur de cette course peuvent la noter.';
  end if;

  -- Corriger sa note est permis ; en ajouter une seconde ne l'est pas.
  -- `updated_at` garde la trace du changement plutôt que de le taire.
  insert into public.courier_ratings
    (delivery_id, courier_id, rater_id, rater_role, stars, comment)
  values
    (p_delivery_id, v_courier_id, v_caller, v_role, p_stars, v_comment)
  on conflict (delivery_id, rater_role) do update
    set stars = excluded.stars,
        comment = excluded.comment,
        rater_id = excluded.rater_id,
        updated_at = now();
end;
$$;

revoke all on function public.rate_courier(text, integer, text) from public, anon;
grant execute on function public.rate_courier(text, integer, text) to authenticated;

-- Ses propres notes, telles que le livreur les voit : les étoiles, le mot
-- laissé, de quel côté il vient — jamais qui l'a écrit.
create or replace function public.fetch_my_courier_ratings(
  p_limit integer default 30,
  p_offset integer default 0
) returns table (
  stars integer,
  comment text,
  rater_role public.courier_rater_role,
  created_at timestamptz,
  delivery_id text
)
language sql
security definer
set search_path = public
as $$
  select r.stars, r.comment, r.rater_role, r.created_at, r.delivery_id
    from public.courier_ratings r
   where r.courier_id = auth.uid()
   order by r.created_at desc
   limit least(coalesce(p_limit, 30), 100)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

revoke all on function public.fetch_my_courier_ratings(integer, integer) from public, anon;
grant execute on function public.fetch_my_courier_ratings(integer, integer) to authenticated;

-- La note déjà donnée par l'appelant sur une course, s'il en a donné une :
-- l'écran doit pouvoir afficher « vous avez mis 4 étoiles » plutôt que
-- reproposer un formulaire vierge.
create or replace function public.fetch_my_rating_for_delivery(p_delivery_id text)
returns table (stars integer, comment text)
language sql
security definer
set search_path = public
as $$
  select r.stars, r.comment
    from public.courier_ratings r
   where r.delivery_id = p_delivery_id
     and r.rater_id = auth.uid();
$$;

revoke all on function public.fetch_my_rating_for_delivery(text) from public, anon;
grant execute on function public.fetch_my_rating_for_delivery(text) to authenticated;
