-- Les tables de `0081` n'étaient pas accessibles — même leurs policies de
-- lecture ne servaient à rien.
--
-- Une policy RLS *restreint* un privilège, elle ne l'accorde pas. Et ce
-- projet n'auto-expose pas les nouvelles tables (`auto_expose_new_tables`
-- est laissé commenté dans `config.toml`, donc au défaut cloud actuel :
-- rien n'est exposé sans `grant` explicite). `activity_select_own` et
-- `ai_usage_select_own` étaient donc posées sur des tables que le rôle
-- `authenticated` ne pouvait pas lire du tout — le test l'a montré sur la
-- première requête : « permission denied for table user_activity_events ».
-- Même oubli, même remède que `0017`, `0034`, `0062`, `0071`.

-- Lecture seule, volontairement : aucun `grant insert`. L'écriture reste la
-- propriété exclusive de `log_activity_event`, qui s'exécute en tant que
-- propriétaire et estampille `user_id` depuis `auth.uid()`. Accorder
-- l'insertion ici rendrait la fonction contournable et permettrait d'écrire
-- des événements au nom d'un autre compte — exactement ce que `0081`
-- cherchait à empêcher.
grant select on public.user_activity_events to authenticated;

-- Idem : le compteur se lit (pour afficher le quota restant) mais ne
-- s'écrit que par `consume_ai_quota`, dont l'incrément conditionnel est ce
-- qui rend le plafond infranchissable.
grant select on public.ai_usage_counters to authenticated;

-- `product_embeddings` reste fermé aux clients — ni `anon` ni
-- `authenticated`, pas même en lecture : les vecteurs du catalogue n'ont
-- aucune raison de quitter la base, et la comparaison se fera dans une
-- fonction `security definer`.
--
-- En revanche `service_role` doit pouvoir écrire : c'est la fonction edge
-- d'indexation qui remplit cette table, et contourner la RLS ne dispense
-- pas des privilèges de table. Sans ce `grant`, l'indexation échouerait au
-- premier produit.
grant select, insert, update, delete on public.product_embeddings to service_role;
