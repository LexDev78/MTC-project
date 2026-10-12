-- Valeurs d'énumération pour le rôle livreur, isolées dans leur propre
-- migration.
--
-- Postgres refuse d'utiliser une valeur d'enum ajoutée dans la même
-- transaction que son ajout ("unsafe use of new value of enum type") — et
-- chaque fichier de migration en est une. Les policies et la fonction de
-- création de compte de `0046_couriers_and_deliveries.sql` comparent bien
-- `role = 'livreur'` : elles doivent donc vivre dans un fichier séparé,
-- joué après celui-ci.

alter type public.account_role add value if not exists 'livreur';

-- Notification envoyée à un livreur à qui une course est proposée. Les
-- décisions sur son dossier (validation par le staff) réutilisent
-- `kyc_decision`, qui décrit déjà exactement ça.
alter type public.notification_type add value if not exists 'delivery_offer';
alter type public.notification_type add value if not exists 'delivery_status';
