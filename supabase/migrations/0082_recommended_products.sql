-- Le fil « Pour vous » : des produits choisis d'après l'activité du client.
--
-- Entièrement en base, sans appel d'IA externe. Les signaux utiles sont déjà
-- là — le journal (`0081`), les favoris, les commandes, les notes, les
-- promotions — et un mélange pondéré de ceux-là donne des suggestions
-- défendables, en temps réel, sans coût par requête ni clé à gérer. Un
-- classement par modèle de langage viendrait *après* celui-ci, pour
-- réordonner ses candidats ; il ne le remplace pas.
--
-- Quatre sources, plus un filet :
--
--   40 %  affinité     — les catégories que la personne consulte
--   30 %  co-achat     — « souvent acheté avec » ce qu'elle a déjà commandé
--   20 %  proximité    — bien noté dans sa ville
--   10 %  promotions   — remises en cours
--   reste populaire    — le filet : sans lui, un compte neuf voit un fil vide
--
-- Le filet n'est pas un détail. Un client qui vient de s'inscrire n'a aucune
-- activité, aucune commande et pas d'adresse : les quatre premières sources
-- ne rendent rien. Le mélange doit dégrader proprement vers « les
-- mieux notés » plutôt que vers l'écran vide.
--
-- Pourquoi des identifiants, et pas des lignes de `products` : les vignettes
-- ont besoin des promotions imbriquées (voir `_listSelect` dans
-- `supabase_product_datasource.dart` — « une vignette sans son badge de
-- remise afficherait un prix que le panier démentirait aussitôt »). Un
-- `setof products` les perdrait. L'app relit donc les produits avec sa
-- requête habituelle, qui lui rend aussi la RLS publique gratuitement : un
-- produit devenu invisible entre les deux appels disparaît du fil au lieu
-- d'apparaître à moitié rempli.

-- `security definer` est nécessaire et porte une subtilité : le co-achat lit
-- les lignes de commandes **d'autres clients**. C'est le principe même du
-- « souvent acheté avec ». La fonction ne renvoie jamais que des
-- `product_id` — jamais qui a acheté, ni quand, ni combien — donc rien de
-- ce qui est lu ne ressort. Toute évolution de cette fonction doit préserver
-- cette propriété : si elle se met un jour à renvoyer autre chose que des
-- identifiants de produits visibles, la lecture élargie devient une fuite.
create or replace function public.get_recommended_products(p_limit integer default 24)
returns table (product_id text, reason text, slot integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_city text;
  v_limit integer := least(greatest(coalesce(p_limit, 24), 1), 60);
begin
  if v_user_id is null then
    return;
  end if;

  -- La ville de l'adresse par défaut ; `null` si le client n'en a pas encore
  -- enregistré, ce qui neutralise simplement la source « proximité ».
  select a.city into v_city
    from public.profiles pr
    join public.addresses a on a.id = pr.default_address_id
   where pr.id = v_user_id;

  return query
  with visible as (
    -- Le même périmètre que le catalogue client (`products_select_public`),
    -- répété ici parce qu'une fonction `security definer` contourne la RLS :
    -- sans ce filtre, le fil proposerait des produits retirés ou des
    -- fournisseurs non vérifiés.
    select p.id, p.category, p.city, p.rating_average, p.rating_count, p.created_at
      from public.products p
     where p.status = 'active'
       and p.is_supplier_verified
       -- Déjà dans le panier : la suggestion est acquise, la place est
       -- mieux employée ailleurs.
       and not exists (
         select 1 from public.cart_items ci
          where ci.user_id = v_user_id and ci.product_id = p.id
       )
  ),

  -- Les produits vus ces trois derniers jours sont écartés de l'affinité :
  -- le fil doit prolonger la navigation, pas la rejouer.
  seen_recently as (
    select distinct e.product_id
      from public.user_activity_events e
     where e.user_id = v_user_id
       and e.product_id is not null
       and e.created_at > now() - interval '3 days'
  ),

  -- Une catégorie ouverte explicitement pèse double : c'est une intention
  -- déclarée, là où une fiche consultée peut n'être qu'un détour.
  category_weight as (
    select category, sum(weight) as weight from (
      select e.category, 2 * count(*) as weight
        from public.user_activity_events e
       where e.user_id = v_user_id
         and e.kind = 'category_open'
         and e.created_at > now() - interval '30 days'
       group by e.category
      union all
      select p.category::text, count(*)
        from public.user_activity_events e
        join public.products p on p.id = e.product_id
       where e.user_id = v_user_id
         and e.kind in ('product_view', 'cart_add')
         and e.created_at > now() - interval '30 days'
       group by p.category
      union all
      -- Un favori est un signal plus durable qu'une consultation, et il
      -- survit à la purge des 90 jours.
      select p.category::text, 3 * count(*)
        from public.favorites f
        join public.products p on p.id = f.product_id
       where f.user_id = v_user_id
       group by p.category
    ) s
    group by category
  ),

  -- Toutes les lignes de commande de la plateforme, rattachées à leur
  -- commande et à son client. Sert deux fois : ce que *ce* client a acheté,
  -- et ce que les autres ont acheté en même temps.
  order_lines as (
    select g.order_id, oi.product_id, o.client_id
      from public.order_items oi
      join public.order_supplier_groups g on g.id = oi.group_id
      join public.orders o on o.id = g.order_id
  ),
  my_products as (
    select distinct ol.product_id from order_lines ol where ol.client_id = v_user_id
  ),

  bucket_affinity as (
    select v.id,
           row_number() over (
             order by cw.weight desc, v.rating_average desc, v.rating_count desc
           ) as rn
      from visible v
      join category_weight cw on cw.category = v.category::text
     where not exists (select 1 from seen_recently s where s.product_id = v.id)
  ),

  bucket_copurchase as (
    select v.id,
           row_number() over (order by count(*) desc, v.rating_average desc) as rn
      from order_lines mine
      join order_lines others
        on others.order_id = mine.order_id
       and others.product_id <> mine.product_id
      join visible v on v.id = others.product_id
     where exists (select 1 from my_products m where m.product_id = mine.product_id)
       -- Ne pas re-proposer ce qu'il a déjà commandé lui-même.
       and not exists (select 1 from my_products m where m.product_id = v.id)
     group by v.id, v.rating_average
  ),

  bucket_local as (
    select v.id,
           row_number() over (order by v.rating_average desc, v.rating_count desc) as rn
      from visible v
     where v_city is not null
       and v.city = v_city
       -- Sans aucun avis, « bien noté » ne veut rien dire : `rating_average`
       -- vaut 0 par défaut et trierait ces produits en dernier de toute
       -- façon, mais les exclure garde la raison affichée honnête.
       and v.rating_count > 0
  ),

  bucket_promo as (
    select v.id,
           row_number() over (order by max(pr.value) desc, v.rating_average desc) as rn
      from visible v
      join public.product_promotions pr on pr.product_id = v.id
     where pr.is_active
       and (pr.starts_at is null or pr.starts_at <= now())
       and (pr.ends_at is null or pr.ends_at > now())
     group by v.id, v.rating_average
  ),

  bucket_popular as (
    select v.id,
           row_number() over (
             order by v.rating_average desc, v.rating_count desc, v.created_at desc
           ) as rn
      from visible v
  ),

  -- `prio` encode à la fois l'ordre d'affichage et, en cas de doublon, la
  -- raison qui gagne : un produit à la fois affine et en promotion est
  -- présenté comme affine, parce que c'est l'explication la plus parlante.
  candidates as (
    select id, 'affinity'   as reason, rn, 1 as prio from bucket_affinity
     where rn <= ceil(v_limit * 0.40)
    union all
    select id, 'copurchase', rn, 2 from bucket_copurchase
     where rn <= ceil(v_limit * 0.30)
    union all
    select id, 'local', rn, 3 from bucket_local
     where rn <= ceil(v_limit * 0.20)
    union all
    select id, 'promo', rn, 4 from bucket_promo
     where rn <= ceil(v_limit * 0.10)
    union all
    -- Pas de quota : le filet doit pouvoir combler un fil entièrement vide.
    select id, 'popular', rn, 5 from bucket_popular
  ),
  deduped as (
    select c.id, c.reason, c.rn, c.prio,
           row_number() over (partition by c.id order by c.prio, c.rn) as dup
      from candidates c
  )
  select d.id,
         d.reason,
         (row_number() over (order by d.prio, d.rn))::integer
    from deduped d
   where d.dup = 1
   order by d.prio, d.rn
   limit v_limit;
end;
$$;

revoke all on function public.get_recommended_products(integer) from public, anon;
grant execute on function public.get_recommended_products(integer) to authenticated;
