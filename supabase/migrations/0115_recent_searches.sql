-- Les recherches récentes d'un client, et le droit de les effacer.
--
-- L'écran de recherche du kit FlutterShop ouvre sur « Recherches récentes »,
-- chacune avec sa croix, et « Tout voir » mène à l'historique, avec « Tout
-- effacer ». Ces recherches sont déjà notées : `log_activity_event` (`0081`)
-- les verse au journal d'activité qui nourrit « Pour vous ». L'historique
-- les relit là plutôt que d'en tenir un second sur le téléphone — sinon,
-- effacer une recherche à l'écran la laisserait influencer les suggestions,
-- et le client croirait l'avoir retirée.
--
-- Effacer passe par une fonction : le journal n'a aucune policy d'écriture
-- (voir `0081`), et n'en reçoit pas ici. La fonction ne touche que les
-- recherches de l'appelant, jamais ses autres signaux (fiches vues, ajouts
-- au panier), qui ne figurent pas dans cet historique.

-- Une recherche par texte : la casse, les accents et les espaces au bord ne
-- font pas deux recherches (« Bogolan », « bògòlan »). C'est la date de la
-- plus récente qui compte.
create or replace function public.fetch_recent_searches(p_limit integer default 30)
returns table (query text, searched_at timestamptz)
language sql
stable
security invoker
set search_path = public
as $$
  select r.query, r.searched_at
    from (
      select distinct on (extensions.unaccent(lower(btrim(e.query))))
             btrim(e.query) as query,
             e.created_at as searched_at
        from public.user_activity_events e
       where e.user_id = auth.uid()
         and e.kind = 'search'
       order by extensions.unaccent(lower(btrim(e.query))), e.created_at desc
    ) r
   order by r.searched_at desc
   limit least(greatest(coalesce(p_limit, 30), 1), 100);
$$;

revoke all on function public.fetch_recent_searches(integer) from public, anon;
grant execute on function public.fetch_recent_searches(integer) to authenticated;

-- Efface une recherche (toutes ses occurrences, au même sens que ci-dessus),
-- ou toutes quand `p_query` est nul. Rend le nombre de lignes effacées.
create or replace function public.forget_searches(p_query text default null)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_effacees integer;
begin
  if v_user_id is null then
    return 0;
  end if;

  delete from public.user_activity_events e
   where e.user_id = v_user_id
     and e.kind = 'search'
     and (
       p_query is null
       or extensions.unaccent(lower(btrim(e.query)))
          = extensions.unaccent(lower(btrim(p_query)))
     );
  get diagnostics v_effacees = row_count;
  return v_effacees;
end;
$$;

revoke all on function public.forget_searches(text) from public, anon;
grant execute on function public.forget_searches(text) to authenticated;
