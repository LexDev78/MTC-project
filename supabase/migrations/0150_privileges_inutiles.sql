-- 0150 — Les droits que l'app n'utilise jamais (trouvé en corrigeant l'audit
-- du 27/10/2026, le 05/11/2026).
--
-- `anon` et `authenticated` tenaient encore, sur 48 tables, les droits que
-- Supabase accorde par défaut à la création : TRUNCATE, TRIGGER et
-- REFERENCES. Aucun ne sert à l'app, et TRUNCATE ignore les policies RLS :
-- une seule fonction qui exécuterait du SQL dynamique au nom de l'appelant
-- suffirait à vider une table. On les retire, et des tables à venir aussi.
--
-- Les droits utiles (SELECT, INSERT, UPDATE, DELETE, filtrés par RLS) ne
-- changent pas.

revoke truncate, trigger, references, maintain on all tables in schema public from anon, authenticated;
-- `setval` sur une séquence n'a pas d'usage non plus.
revoke update on all sequences in schema public from anon, authenticated;

alter default privileges for role postgres in schema public
  revoke truncate, trigger, references, maintain on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke update on sequences from anon, authenticated;

-- MAINTAIN (PostgreSQL 17) permet `LOCK TABLE … ACCESS EXCLUSIVE` : de
-- quoi bloquer une table entière (contre-vérification du 06/11/2026). Les
-- tables du schéma `storage` appartiennent à `supabase_storage_admin`, que
-- cette migration ne peut pas réviser : voir `MISE_EN_PRODUCTION.md`.
