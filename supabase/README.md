# Pile Supabase locale — les pannes qui ne ressemblent pas à ce qu'elles sont

Deux pannes de l'environnement local se sont présentées comme des bugs de
l'application. Les voici, avec ce qui les distingue et ce qui les répare.

Pour les fonctions edge (une fonction nouvelle qui rend `404`), voir
[`functions/README.md`](functions/README.md). Pour la mise en production,
voir [`production/MISE_EN_PRODUCTION.md`](production/MISE_EN_PRODUCTION.md).

## Trois règles depuis l'audit d'avant lancement (`0128`–`0135`)

**Les fonctions de test vivent dans `seeds/test_helpers.sql`**, plus dans
les migrations (`0130`). Seul `supabase db reset` les joue — jamais
`db push`. Pour les recharger sur une base locale sans la réinitialiser :

```bash
docker exec -i supabase_db_MTC_project psql -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -1 -q < supabase/seeds/test_helpers.sql
```

Une migration qui créerait un helper de test le réinstallerait en
production.

**La suite d'intégration se lance contre une pile à part**, pour ne pas
vider celle où l'on essaie l'app :

```bash
tool/pile_de_verification.sh demarrer   # rejoue toutes les migrations depuis zéro
tool/pile_de_verification.sh tester
tool/pile_de_verification.sh arreter
```

**Le staff exige la double authentification** (`0135`), sauf en local où
le jeu de démonstration l'éteint : les tests connectent le staff par mot
de passe. Pour l'essayer dans l'app (la TOTP est activée dans
`config.toml`) :

```sql
update public.app_settings set value = 'true' where key = 'staff_mfa_required';
```

et `'false'` pour revenir en arrière. Les vérifications de chaque
migration sont dans `snippets/verif_0128.sql` … `verif_0135.sql`, plus
`verif_0128_api.sh` et `verif_0135_api.sh` par la vraie API.

## Plus aucun téléversement ne passe : `DatabaseError`, code `42P10`

**Le symptôme.** Joindre une photo échoue partout dans l'app — pièce du
dossier livreur, document KYC, image de produit, pièce jointe de
conversation. L'écran ne dit rien de précis, et la base paraît saine : les
politiques sont bonnes, le bucket existe, la session est valide.

**Ce qu'on voit vraiment**, dans les journaux du service :

```bash
docker logs supabase_storage_MTC_project 2>&1 | grep -o '"code":"42P10"' | head -1
```

`42P10` est `invalid_column_reference` : *« aucune contrainte unique ne
correspond à la spécification ON CONFLICT »*.

**La cause.** Le service de stockage écrit son `upsert` ainsi :

```sql
insert into storage.objects (...) values (...)
on conflict (name, bucket_id) do update set ...
```

Or une de ses propres migrations, `drop-bucketid-objname-index`, supprime
l'index unique **total** sur `(bucket_id, name)` et le remplace par des index
**partiels** (`... where archived_at is null`, `... where not is_versioned`).
Postgres ne sait pas inférer un index partiel depuis un `on conflict` qui ne
répète pas sa condition — donc l'insertion échoue, pour tout fichier.

Autrement dit : le schéma de `storage` a avancé plus loin que le code du
service qui l'utilise. Cela se produit après un `supabase stop && supabase
start` qui restaure une sauvegarde plus récente que l'image lancée.

**Le remède**, tant que l'image du service et le schéma ne sont pas
réaccordés. L'index doit être créé par le **propriétaire** de la table, et
`postgres` ne l'est pas ici :

```bash
docker exec -i supabase_db_MTC_project \
  psql -U supabase_admin -d postgres \
  -c "create unique index if not exists bucketid_objname
        on storage.objects (bucket_id, name);"
```

C'est sans effet de bord tant qu'aucun objet n'est versionné — ce qui est le
cas en local :

```sql
select count(*) filter (where is_versioned) from storage.objects;  -- 0
```

**Pourquoi ce n'est pas dans une migration.** `supabase/migrations/` est joué
en production, où le schéma de `storage` appartient à Supabase et où le
versionnement d'objets peut être actif : y poser cet index pourrait empêcher
deux versions d'un même fichier de coexister. Et `seed.sql`, qui serait le
bon endroit puisqu'il ne tourne qu'en local, s'exécute sous `postgres`, qui
n'a pas le droit de créer cet index.

La vraie résolution est de remettre l'image du service et le schéma d'accord
— mise à jour du CLI Supabase, ou `supabase stop --no-backup && supabase
start` pour repartir d'un schéma neuf (au prix des données locales, que
`test_reset_and_seed()` régénère de toute façon).

## Le conteneur des fonctions edge meurt et ne redémarre plus

**Le symptôme.** Un appel de fonction rend `503 {"message":"name resolution
failed"}` — personne n'écoute. `docker ps -a` le confirme :

```
supabase_edge_runtime_MTC_project   Exited (255)
```

`docker start` ne le relève pas : son fichier de montage
(`supabase/.temp/start-secrets/.../main/index.ts`) a disparu entre-temps, et
Docker refuse de monter un chemin absent.

**Le remède** est le même que pour une fonction nouvelle — la liste des
fonctions servies est figée au démarrage de la pile :

```bash
supabase stop && supabase start
```

**Ce qu'on ne sait pas encore** : pourquoi il s'arrête. Ses dernières lignes
de journal sont souvent des `JWT format error: Invalid Token or Protected
Header formatting`, et une première version de ce document en concluait
qu'une rafale de jetons mal formés l'abattait. Les horodatages le démentent :
lors d'un arrêt mesuré, le dernier message JWT date de 12 h 07 et l'arrêt de
12 h 28, vingt et une minutes plus tard, sans aucune ligne au moment de la
sortie (code 255, pas d'OOM). Corrélation, pas cause.

Pour mesurer plutôt que deviner, au prochain arrêt :

```bash
docker inspect supabase_edge_runtime_MTC_project \
  --format '{{.State.FinishedAt}} code={{.State.ExitCode}} OOM={{.State.OOMKilled}}'
df -h /System/Volumes/Data   # un disque plein a été constaté dans la même période
```

En pratique : si une fonction edge « ne marche plus », regarder ce conteneur
**avant** de suspecter le code.
