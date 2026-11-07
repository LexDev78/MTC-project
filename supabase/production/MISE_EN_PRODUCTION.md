# Mise en production — ce que le dépôt ne fait pas tout seul

`config.toml` ne sert qu'à la pile locale. Sur le projet Supabase hébergé,
les réglages d'authentification se font dans le tableau de bord, et
plusieurs gestes de sécurité demandent une main humaine. Cette fiche les
liste dans l'ordre où les faire. Elle suit l'audit d'avant lancement du
25/10/2026 (migrations `0128` à `0135`).

## 1. Avant de pousser les migrations

**Activer la TOTP** : Authentication → Multi-Factor → App Authenticator
(TOTP), enrôlement **et** vérification. Gratuite sur tous les plans ; seule
la MFA par téléphone est payante.

Sans elle, `0135` coupe tout le staff : un compte MTC n'a plus de droits
sans code d'application d'authentification, et personne ne pourrait en
relier une.

## 2. Pousser, puis redéployer aussitôt

```bash
supabase db push
supabase functions deploy create-collaborator
```

Dans cet ordre, et sans attendre entre les deux : depuis `0128`, l'ancienne
version de `create-collaborator` (qui mettait le rattachement dans
`user_metadata`) voit ses créations refusées. Un patron qui ajoute un
vendeur entre les deux gestes reçoit « Impossible de créer ce compte ».

`db push` ne joue jamais `supabase/seeds/` : les fonctions de test ne sont
plus installées en production (`0130`). Après le push, cette requête doit
rendre zéro :

```sql
select count(*) from pg_proc
 where pronamespace = 'public'::regnamespace and proname like 'test\_%';
```

## 3. Réglages d'authentification du projet hébergé

| Réglage | Où | Valeur |
|---|---|---|
| Inscription par e-mail | Authentication → Providers → Email | activée |
| Confirmer l'e-mail | même écran | **désactivé** — les comptes portent une pseudo-adresse `…@mtc.local` qui ne reçoit rien |
| Connexions anonymes | Authentication → Settings | désactivées |
| Longueur minimale du mot de passe | Authentication → Settings | **8** (décidé le 05/11/2026, `0151` ; le staff : 10, imposé par l'app et `reset_password_with_code`) |
| Protection des mots de passe divulgués | Authentication → Settings | à activer si votre plan la propose |
| Durée du jeton | Authentication → Settings | 3600 s |
| Limites de débit | Authentication → Rate Limits | inscriptions et connexions : 30 / 5 min par IP ; vérifications de jeton : 30 |
| TOTP | Authentication → Multi-Factor | enrôlement et vérification activés (voir §1) |

Les e-mails de l'app (codes, alertes) ne passent pas par le SMTP de
Supabase Auth mais par `send_mail` (`0124`, `0125`) : configurer le service
d'envoi dans le Vault du projet avec `supabase/snippets/configurer_envoi_mail.sql`.
**Changer la clé Brevo** utilisée en local : elle est apparue en clair
pendant la mise en place.

## 4. Les secrets des fonctions edge

Voir `supabase/functions/.env.example` : `FCM_SERVICE_ACCOUNT_JSON_B64`,
`PUSH_WEBHOOK_SECRET` (aussi dans le Vault, `push_function_secret`),
`VOYAGE_API_KEY`, `INDEXING_SECRET`. Chacun se génère pour la production,
jamais repris du local.

## 5. Les comptes du staff

Uniquement par le serveur :

```bash
SUPABASE_URL=https://<projet>.supabase.co SERVICE_ROLE_KEY=<clé de service> \
  supabase/production/creer_compte_staff.sh <identifiant> "<Nom>" <téléphone> <agent|admin>
```

Le script engendre un mot de passe de 20 caractères, affiché une fois. À sa
première connexion, la personne relie son compte à une application
d'authentification. Téléphone perdu : retirer la liaison par Authentication
→ Users → le compte → Factors, ou

```sql
delete from auth.mfa_factors where user_id = '<id>';
```

puis la personne en relie une neuve à la connexion suivante.

## 6. Contrôler la base après le push

Sur toute base qui a vécu avant `0128` :

```bash
psql "$DATABASE_URL" -f supabase/snippets/audit_comptes_privilegies.sql
psql "$DATABASE_URL" -f supabase/snippets/audit_commandes_negatives.sql
```

Le premier liste les comptes staff et les collaborateurs dont le rôle ne
vient pas de `app_metadata` : un compte staff « À VÉRIFIER » a été fait par
l'ancienne faille ou à la main ; il ne voit déjà plus rien, mais il faut
décider de son sort. Le second liste les commandes à quantité négative et
les mouvements de stock qu'elles ont gonflés.

Un vendeur a pu demander un versement sur une vente qu'il avait encaissée
lui-même (`0131`) : relire les versements payés avant le lancement.

## 7. L'application

- Construire avec `tool/build_release.sh` : il refuse une URL qui n'est pas
  en https, une adresse locale, une clé de service à la place de la clé
  anonyme, et une release Android sans clé de signature.
- Créer la clé de signature Android une fois (`android/key.properties.example`),
  la garder hors du dépôt, la sauvegarder deux fois, et activer « Play App
  Signing » sur Google Play.

## 8. La clé Firebase

La clé de `android/app/google-services.json` (et de `firebase_options.dart`)
est publique par nature : elle part dans chaque APK. Ce qui la protège, ce
sont ses restrictions, dans Google Cloud Console → APIs & Services →
Credentials → la clé « Android key » du projet :

- **Restrictions d'application** : applications Android, nom de paquet
  `com.mtc.mtc_app`, avec l'empreinte SHA-1 du certificat de signature —
  celle de la clé d'importation (`keytool -list -v -keystore …`) **et**
  celle de Play App Signing (Play Console → Configuration → Intégrité de
  l'application).
- **Restrictions d'API** : seulement celles dont l'app a besoin pour les
  notifications — Firebase Installations API et FCM Registration API.

Même chose pour la clé iOS, restreinte au bundle identifier, si l'app sort
sur iOS.

## 9. Ce qui reste à décider

- Une adresse exacte publique, sur option, pour une boutique **vérifiée** qui
  reçoit des clients (`0133` ne montre que la ville).

Réglé depuis : la longueur minimale (8, `0151`), et les identifiants des
commentaires de produits, que la vue ne montre plus (`0140`).

## 10. Après l'audit du 27/10/2026 (`0136`–`0152`)

À faire une fois, sur le projet hébergé, après `supabase db push` :

- **Avis forgés** (faille 1) : la requête de
  `supabase/snippets/audit_avis_forges.sql` liste les avis qui ne
  correspondent pas à une vraie commande livrée du client chez cette boutique.
  Les supprimer est une décision humaine ; la même requête dit ensuite comment
  recalculer la note des boutiques touchées.
- **Edge Functions** : redéployer `send-push-notification`, `visual-search`
  et `index-product-embeddings` (`supabase functions deploy …`). La première
  refuse désormais de tourner avec le secret de développement
  (`local-dev-push-secret`) ou un secret de moins de 32 caractères : vérifier
  `PUSH_WEBHOOK_SECRET` et, dans le Vault, `push_function_url` **et**
  `push_function_secret` (sans le second, les notifications push ne partent
  plus — c'est voulu).
- **Modèle auto-hébergé** (`ml/serve`), s'il sert : il ne démarre plus sans
  `MTC_SERVE_TOKEN` (32 caractères au moins) et ne télécharge que depuis
  `MTC_IMAGE_HOSTS` (à défaut l'hôte de `SUPABASE_URL`).
- **Noms réservés** : la migration `0144` signale (sans les changer) les
  boutiques et les comptes qui portent déjà un nom contenant « MTC » ; les
  traiter à la main.
- **Photos de produit en URL** : `0145` signale celles qui en sont ; une
  boutique concernée doit renvoyer ses photos depuis l'app.
- **Commandes livrées par la boutique en cours** au moment du déploiement :
  elles se terminent désormais par le code du client ou sa confirmation
  (`0139`), une fois la commande « en cours de livraison ». Prévenir les
  boutiques que le bouton « Marquer livrée » est remplacé par « Scanner le
  code du client ».
- **Droits du schéma `storage`** : `0150` retire TRUNCATE, TRIGGER,
  REFERENCES et MAINTAIN à `anon`/`authenticated` sur le schéma `public`
  seulement. Les tables `storage.objects` et `storage.buckets` appartiennent
  à `supabase_storage_admin`, qu'une migration ne peut pas réviser : à faire
  depuis l'éditeur SQL du tableau de bord, en tant que ce rôle, si Supabase
  le permet (`revoke truncate, maintain on storage.objects, storage.buckets
  from anon, authenticated;`).
- **Ville d'une boutique vérifiée** : elle ne se change plus depuis l'app
  (`0152`) — c'est d'elle que part le prix d'une course MTC. Une boutique qui
  déménage écrit à MTC ; le staff fait le changement en SQL après
  vérification.
- **« Payer maintenant »** : aucune passerelle de paiement réelle n'est
  branchée. Tant que le staff n'a pas constaté le paiement
  (`mark_order_paid`), une telle commande s'encaisse à la remise : le
  livreur MTC le voit désormais (`courier_order`, `0146`). Une boutique qui
  livre elle-même doit faire de même — son écran n'affiche pas encore l'état
  du paiement.

## 11. Après le rapport du 06/11/2026 (`0153`)

- **Tâches planifiées** : `0153` active `pg_cron` et planifie
  `mtc-commandes-non-confirmees` (tous les quarts d'heure) et
  `mtc-purge-activite` (chaque nuit). Après `db push`, vérifier qu'elles
  tournent sous `postgres` :

  ```sql
  select jobname, schedule, username, active from cron.job;
  select jobid, status, return_message, start_time
    from cron.job_run_details order by start_time desc limit 5;
  ```

  Un `username` autre que `postgres` (le rôle temporaire d'une connexion de
  la CLI, par exemple) : refaire les deux `cron.schedule` de la migration
  depuis l'éditeur SQL du tableau de bord.
- **Commandes en attente au moment du déploiement** : au premier passage de
  la tâche, toute commande non payée que sa boutique n'a pas confirmée depuis
  plus de 24 h est annulée (« Annulée par MTC »), son stock remis en vente,
  le client et la boutique prévenus. Prévenir les boutiques qu'une commande
  se confirme désormais sous 24 h.
- **Plafonds d'une commande non payée** — toutes le sont tant que le staff
  n'a pas constaté le paiement : 10 exemplaires d'un même article, 3
  commandes en cours par boutique, 200 000 FCFA d'articles en cours (un
  article seul passe toujours), 10 commandes par heure. Un grossiste qui
  commande davantage à la livraison sera refusé avec un message clair ; les
  seuils se règlent sans migration dans `app_settings` (la liste des clés est
  en tête de `0153`) :

  ```sql
  insert into public.app_settings (key, value)
  values ('unpaid_units_per_item_max', '20')
  on conflict (key) do update set value = excluded.value, updated_at = now();
  ```

- **Le jour où une vraie passerelle de paiement arrive** : une commande
  « Payer maintenant » sera payée dans les minutes qui suivent ; lui donner
  alors un court délai de paiement (une commande non payée au bout d'une
  heure s'annule) plutôt que ces plafonds, pensés pour le paiement à la
  livraison.
- **Messages et commentaires** : 20 messages par minute et 300 par heure par
  expéditeur ; 10 commentaires par minute et 60 par heure par auteur. Une
  conversation, ou les commentaires d'un produit, ne font plus qu'une
  notification push toutes les 10 minutes tant que la précédente n'est pas
  lue. Même table de réglages (`messages_per_minute_max`, …).
- **Codes promo** : une commande annulée — par le client, la boutique ou
  l'annulation automatique — rend désormais son code : il redevient
  utilisable par ce client, et le compteur d'utilisations du code baisse
  d'autant. Les historiques d'utilisation ne montrent plus les commandes
  annulées.
- **Vérifier la course annulation / confirmation** sur une pile de
  vérification : `supabase/snippets/verif_0153_course.sh` (deux sessions ;
  il enregistre une commande, ne jamais le lancer ailleurs).
