-- Les tests refusent d'effacer une base dont quelqu'un se sert.
--
-- `test_reset_and_seed()` repart de zéro : `truncate auth.users … cascade`,
-- puis chaque compte du décor recréé avec le mot de passe `password123`. Les
-- tests l'appellent avant chacun d'eux — et cette base locale est aussi celle
-- de l'app qu'on essaie à la main (`bootstrap.dart` vise le même
-- `127.0.0.1:54321`).
--
-- Constaté le 18/10/2026, journaux de Kong et de GoTrue à l'appui : depuis
-- Chrome, chaque changement de mot de passe réussissait (`PUT /auth/v1/user`
-- → 200), puis la réinitialisation d'un test le remettait à `password123` une
-- à deux secondes plus tard. Un collaborateur créé à la main disparaissait de
-- même. Vu de l'app : « le mot de passe ne change pas vraiment ». Le code de
-- l'app n'y était pour rien.
--
-- Cette fonction donne au harnais de test de quoi s'arrêter avant d'effacer :
-- les sessions récentes qui ne sont pas les siennes. GoTrue inscrit le
-- User-Agent de chaque connexion dans `auth.sessions.user_agent`, et le
-- harnais signe les siennes d'un User-Agent à lui (`createTestSupabaseClient`).
-- Toute autre session — Chrome, ou l'app sur un téléphone (`Dart/…
-- (dart:io)`) — est quelqu'un qui se sert de la base.
--
-- « Récente » : ouverte ou rafraîchie depuis moins de 70 minutes. Une app
-- ouverte rafraîchit son jeton avant qu'il n'expire (`jwt_expiry = 3600`) :
-- même au repos, sa session a moins d'une heure. Au-delà, c'est une app
-- fermée sans déconnexion, qui ne doit pas bloquer les tests indéfiniment.
--
-- Inutile de remonter avant la dernière réinitialisation : elle a effacé
-- toutes les sessions avec `auth.users`.
create or replace function public.test_live_app_sessions(p_test_user_agent text)
returns table (email text, user_agent text, last_seen timestamp with time zone)
language sql
stable
security definer
set search_path = ''
as $$
  select u.email::text, s.user_agent, a.last_seen
  from auth.sessions s
  join auth.users u on u.id = s.user_id
  cross join lateral (
    -- `refreshed_at` est sans fuseau ; GoTrue l'écrit en UTC.
    select greatest(
      s.created_at,
      s.updated_at,
      s.refreshed_at at time zone 'UTC'
    ) as last_seen
  ) a
  where s.user_agent is distinct from p_test_user_agent
    and a.last_seen > now() - interval '70 minutes'
  order by a.last_seen desc;
$$;

comment on function public.test_live_app_sessions(text) is
  'Tests seulement : sessions récentes ouvertes hors du harnais de test. resetAndSeed() refuse de réinitialiser tant qu''il y en a.';

revoke all on function public.test_live_app_sessions(text) from public, anon, authenticated;
grant execute on function public.test_live_app_sessions(text) to service_role;
