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
| Longueur minimale du mot de passe | Authentication → Settings | 6 au moins (le staff : 10, imposé par l'app et `reset_password_with_code`) ; 8 conseillé pour tous, à décider |
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

- La longueur minimale du mot de passe pour tous les comptes (6 aujourd'hui).
- Une adresse exacte publique, sur option, pour une boutique **vérifiée** qui
  reçoit des clients (`0133` ne montre que la ville).
- Les commentaires de produits (`product_comments_with_likes`) montrent
  encore l'identifiant de leur auteur et de ceux qui les ont aimés.
