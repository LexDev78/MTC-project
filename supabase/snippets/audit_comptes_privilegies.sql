-- Qui a un rôle privilégié, et d'où lui vient-il ?
--
-- À jouer sur toute base qui a vécu avant `0128` — en particulier une base
-- de production : jusque-là, n'importe qui pouvait se faire administrateur
-- MTC ou collaborateur d'une boutique par l'inscription publique. Lecture
-- seule : rien n'est modifié.
--
--   psql "$DATABASE_URL" -f supabase/snippets/audit_comptes_privilegies.sql
--   (en local : docker exec -i supabase_db_MTC_project psql -U postgres -d postgres < …)
--
-- Depuis `0128`, un rôle privilégié vient de `app_metadata`, que seule la
-- clé de service écrit. Un compte staff dont `app_metadata` ne dit rien a
-- donc été fait par l'ancien chemin — légitimement par l'équipe, ou par un
-- attaquant. `is_staff()` ne le reconnaît déjà plus : il ne voit plus rien,
-- mais il faut décider de son sort.

\echo '== Comptes staff MTC =='
select p.username_or_phone as identifiant,
       p.display_name as nom,
       p.staff_role as role_profil,
       u.raw_app_meta_data ->> 'staff_role' as role_app_metadata,
       u.created_at as cree_le,
       u.last_sign_in_at as derniere_connexion,
       case
         when (u.raw_app_meta_data ->> 'staff_role') = p.staff_role::text then 'confirmé (app_metadata)'
         when u.raw_app_meta_data ? 'staff_role' then 'INCOHÉRENT : app_metadata dit autre chose'
         when u.raw_user_meta_data ? 'staff_role' then 'À VÉRIFIER : rôle pris à l''inscription publique'
         else 'À VÉRIFIER : origine inconnue'
       end as verdict
  from public.profiles p
  join auth.users u on u.id = p.id
 where p.role = 'supplier_principal' or p.staff_role is not null
 order by verdict, u.created_at;

\echo '== Collaborateurs de boutiques =='
select s.business_name as boutique,
       p.username_or_phone as identifiant,
       c.permissions,
       c.created_at as rattache_le,
       c.deactivated_at as retire_le,
       case
         when (u.raw_app_meta_data ->> 'collaborator_of') = c.supplier_id::text then 'confirmé (app_metadata)'
         when u.raw_app_meta_data ? 'collaborator_of' then 'INCOHÉRENT : créé pour une autre boutique'
         when (u.raw_user_meta_data ->> 'collaborator_of') = c.supplier_id::text then 'À VÉRIFIER avec le patron : créé avant 0128'
         else 'À VÉRIFIER : origine inconnue'
       end as verdict
  from public.supplier_collaborators c
  join public.suppliers s on s.id = c.supplier_id
  join public.profiles p on p.id = c.user_id
  join auth.users u on u.id = c.user_id
 order by verdict, s.business_name, c.created_at;

-- Les inscriptions qui ont essayé. Depuis `0128` elles échouent, et rien ne
-- reste en base : celles-ci datent d'avant.
\echo '== Comptes dont l''inscription réclamait un rôle privilégié =='
select u.email, u.created_at, u.raw_user_meta_data ->> 'role' as role_demande,
       u.raw_user_meta_data ->> 'staff_role' as staff_role_demande,
       u.raw_user_meta_data ->> 'collaborator_of' as boutique_demandee,
       p.role as role_obtenu
  from auth.users u
  left join public.profiles p on p.id = u.id
 where u.raw_user_meta_data ?| array['staff_role', 'collaborator_of', 'permissions']
    or u.raw_user_meta_data ->> 'role' = 'supplier_principal'
 order by u.created_at;

-- Que faire de chaque ligne « À VÉRIFIER » :
--
-- * Un vrai membre de l'équipe : lui donner son `app_metadata` par l'API
--   d'administration, puis lui demander de se reconnecter.
--
--     curl -X PUT "$SUPABASE_URL/auth/v1/admin/users/<id>" \
--       -H "apikey: $SERVICE_ROLE_KEY" -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
--       -H "Content-Type: application/json" \
--       -d '{"app_metadata":{"staff_role":"agent"}}'      # ou "admin"
--
-- * Un compte que personne ne reconnaît : le supprimer (Dashboard →
--   Authentication → Users, ou `auth.admin.deleteUser(<id>)`), puis lire
--   ce qu'il a fait dans les journaux d'API autour de sa date de création.
--
-- * Un collaborateur créé avant `0128` : le patron le connaît ou non. S'il
--   ne le connaît pas, il retire l'accès depuis son écran « Équipe ».
