# Fonctions edge

## Une fonction nouvelle n'est pas servie tant que la pile n'a pas redémarré

C'est le piège le plus coûteux de ce dossier, et il ne ressemble pas à ce
qu'il est.

La liste des fonctions servies en local est **figée au démarrage de la
pile**. Le CLI la transmet au conteneur une fois, à `supabase start`.
Créer un dossier ici n'y change rien, et redémarrer le conteneur n'y change
rien non plus — la liste ne vient pas de lui.

Le symptôme : l'app reçoit une erreur, et tout semble en cause **sauf** la
bonne chose. Le code de la fonction est là, le dossier est monté dans le
conteneur, les autres fonctions répondent. Seule celle qu'on vient d'écrire
rend `404 Function not found`.

Le remède :

```bash
supabase stop && supabase start
```

Pour vérifier ce qui est réellement servi, sans deviner :

```bash
docker logs supabase_edge_runtime_MTC_project 2>&1 | grep functions/v1
```

La liste y est affichée au démarrage, une ligne par fonction. Si la vôtre
n'y figure pas, aucun appel ne l'atteindra, quoi que fasse l'application.

## Essayer une fonction sans passer par l'app

Plus rapide que de recompiler pour le simulateur, et le message d'erreur
arrive entier plutôt que réduit à ce que l'écran veut bien montrer.

```bash
ANON=$(supabase status -o json | jq -r .ANON_KEY)
TOKEN=$(curl -s -X POST "http://127.0.0.1:54321/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON" -H "Content-Type: application/json" \
  -d '{"email":"fournisseur1@mtc.local","password":"password123"}' | jq -r .access_token)

curl -s -X POST "http://127.0.0.1:54321/functions/v1/create-collaborator" \
  -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"displayName":"Fatou","usernameOrPhone":"fatou","password":"password123","permissions":["products"]}'
```

Les comptes de démonstration utilisent tous `password123`, et leur adresse
est leur nom d'utilisateur suivi de `@mtc.local` (`pseudo_email.dart`).

## En production

Chaque fonction se déploie séparément, et ses secrets se posent à part :

```bash
supabase functions deploy create-collaborator
supabase secrets set VOYAGE_API_KEY="..."
```

Voir `.env.example` pour la liste des secrets attendus et ce qui arrive
quand ils manquent.
