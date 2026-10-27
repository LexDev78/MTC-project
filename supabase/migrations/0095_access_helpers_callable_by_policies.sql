-- `supplier_can` doit être appelable par qui déclenche la policy, pas
-- seulement par qui a le droit d'écrire.
--
-- `0094` a branché `supplier_can()` sur des policies déclarées `for all` :
-- leur clause `using` est donc évaluée aussi **à la lecture**, y compris
-- pour un visiteur anonyme qui consulte le catalogue. Or j'avais révoqué
-- l'exécution à `anon`, par réflexe de fermeture.
--
-- Résultat : « permission denied for function supplier_can » sur vingt-cinq
-- tests, dont la simple lecture d'une fiche produit par quelqu'un qui n'est
-- pas connecté. Une fonction appelée depuis une policy doit être exécutable
-- par tous les rôles que cette policy peut concerner — sinon ce n'est pas
-- un refus d'accès, c'est une erreur.
--
-- Les deux fonctions voisines qui servent aux mêmes policies depuis
-- l'origine (`operating_supplier_id`, `is_staff`) sont, elles, laissées
-- ouvertes. On s'aligne : elles sont `security definer`, en lecture seule,
-- et ne répondent que sur l'identité de l'appelant — à un visiteur anonyme,
-- elles rendent `null` et `false`.

grant execute on function public.supplier_can(text) to public;
grant execute on function public.is_supplier_owner() to public;
