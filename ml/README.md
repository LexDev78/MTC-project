# Entraîner notre propre modèle de recherche par photo

Aujourd'hui la recherche par photo appelle un modèle externe (Voyage AI).
Ce dossier contient la chaîne qui permettra de le remplacer par un modèle à
nous — et, avant cela, de **mesurer** s'il est réellement meilleur.

Rien ici n'est à lancer tout de suite. La structure existe pour que la
donnée s'accumule dès maintenant : c'est la seule partie qui ne se rattrape
pas.

## Pourquoi un modèle maison, et pourquoi pas tout de suite

La raison n'est pas le coût. Une recherche coûte environ 0,4 FCFA, et le
palier gratuit couvre les premiers mois.

La raison est le **domaine**. Ces modèles sont entraînés sur des photos de
commerce occidental : produit détaché, fond neutre, lumière d'atelier. Une
photo prise dans un étal de Bamako n'a aucun de ces caractères — plein
soleil, ombres dures, fond chargé, tissu froissé, cadrage de travers, et un
vocabulaire visuel (pagnes, bogolan, bazin, ustensiles émaillés) que ces
corpus représentent mal. C'est cet écart qu'un affinage sur nos propres
photos comble, et qu'aucun fournisseur ne comblera pour nous.

Pourquoi pas tout de suite : il n'y a pas de données. Un affinage sur moins
de ~500 paires étiquetées sur-apprend et **dégrade** le modèle de départ.
Vers 2 000 paires, il commence à le battre sur le domaine. Le chiffre à
regarder avant d'allumer un GPU :

```sql
select public.ai_training_readiness();
```

## Ce que la base retient déjà

| Table | Contenu | Rôle |
|---|---|---|
| `visual_search_queries` | photo, empreinte, candidats proposés | l'entrée du modèle |
| `visual_search_clicks` | le produit réellement ouvert | **l'étiquette** |
| `user_activity_events` | mises au panier | étiquette forte |
| `ai_eval_examples` | photos figées + réponse attendue | l'étalon de mesure |
| `ai_models` | quel modèle sert, lequel est candidat | la bascule |
| `product_embeddings` | une empreinte par (produit, **modèle**) | cohabitation |

L'étiquette est la donnée rare. Elle ne dit pas « le modèle a trouvé ce
produit » mais « la personne cherchait ce produit » — c'est ce qui
distingue un entraînement d'une imitation du modèle actuel, erreurs
comprises.

Les produits proposés et **non** retenus sont conservés comme négatifs. Ils
valent plus que des négatifs tirés au hasard : un modèle apprend en
séparant ce qui se ressemble, pas en distinguant un pagne d'une brouette.

## Le modèle de départ

`open_clip` comme cadre : la boucle contrastive, le chargement des paires,
les points de reprise et l'évaluation en retrieval existent déjà et sont
éprouvés. Rien à réécrire.

Pour les poids, le point de départ par défaut est **SigLIP** plutôt que CLIP
d'origine. La raison est pratique : la perte sigmoïde de SigLIP se passe de
la normalisation globale sur le lot, donc elle tient avec de petits lots.
CLIP tire sa qualité du nombre de négatifs présents dans le lot et souffre
sur un seul GPU loué — ce que sera notre matériel.

Ce choix n'est pas figé dans le code. `MTC_BASE_MODEL` le change, et
`evaluate.py` est là pour trancher par la mesure plutôt que par l'opinion —
exactement comme pour le seuil de similarité.

## La chaîne, dans l'ordre

```bash
cd ml
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env     # puis renseigner SUPABASE_URL et la clé de service
```

**1. Exporter le jeu d'entraînement**

```bash
python export_dataset.py --out data/train
```

Télécharge les photos de requête et écrit `pairs.jsonl` : une ligne par
requête, avec ses positifs pondérés et ses négatifs difficiles. Les photos
promues au jeu d'évaluation sont exclues — sans quoi la mesure annoncerait
un succès qui ne se reproduirait pas.

**2. Figer un étalon** (une seule fois, puis on n'y touche plus)

```sql
select public.promote_queries_to_eval(100);
```

**3. Entraîner**

```bash
python train.py --data data/train/pairs.jsonl --out checkpoints/mtc-v1
```

**4. Déclarer le modèle, puis indexer le catalogue avec lui**

```sql
insert into public.ai_models (name, kind, dim, provider, role)
values ('mtc-v1', 'embedding', 768, 'self_hosted', 'candidate');
```

```bash
python index_catalogue.py --checkpoint checkpoints/mtc-v1 --model mtc-v1
```

Le modèle servant continue de répondre aux clients pendant ce temps. Les
deux jeux de vecteurs cohabitent — c'est tout l'objet de la clé
`(produit, modèle)` de `0085`.

**5. Mesurer, et seulement alors décider**

```bash
python evaluate.py --checkpoint checkpoints/mtc-v1 --model mtc-v1 --compare voyage-multimodal-3.5
```

Sort un `recall@1`, `recall@5` et un `MRR` par modèle, sur les mêmes photos.
Si le modèle maison ne gagne pas, il n'y a rien à déployer : on garde
l'externe et on attend d'avoir plus de données. C'est une conclusion
acceptable, et la plus fréquente au premier essai.

**6. Servir**

```bash
# Depuis `ml/` : l'image a besoin de common.py, donc le contexte est le
# dossier parent du Dockerfile.
docker build -f serve/Dockerfile -t mtc-embeddings .
docker run -p 8080:8080 -v "$PWD/checkpoints:/models" \
  -e MTC_CHECKPOINT=/models/mtc-v1 -e MTC_SERVE_TOKEN="$TOKEN" mtc-embeddings
```

Puis côté Supabase :

```bash
supabase secrets set SELF_HOSTED_EMBEDDINGS_URL="https://..."
supabase secrets set SELF_HOSTED_EMBEDDINGS_TOKEN="$(openssl rand -hex 32)"
```

**7. Basculer** — une ligne, réversible en une ligne :

```sql
update public.ai_models set role = 'retired' where name = 'voyage-multimodal-3.5';
update public.ai_models set role = 'serving' where name = 'mtc-v1';
```

Les anciens vecteurs restent en base. Revenir en arrière n'exige donc pas de
réindexer, seulement d'inverser ces deux lignes.

## Ce que la bascule implique vraiment

Deux encodeurs différents produisent des espaces **incomparables**. Changer
de modèle veut dire réindexer tout le catalogue avec le nouveau, et les
similarités ne se transposent pas — en particulier le seuil de 0,25 devra
être réglé à nouveau pour le modèle maison. `evaluate_model_recall` le mesure
à seuil nul justement pour que le réglage du seuil et la qualité du modèle
ne soient pas confondus.

## Vie privée

Les photos de requête sont de vraies photos prises par de vraies personnes.
Elles vivent dans un bucket privé, s'effacent au bout de 180 jours, et
chacun peut effacer les siennes (`delete_my_visual_search_history`). Ce
dossier les télécharge en clair sur la machine qui entraîne : `data/` est
ignoré par git, et doit l'être par toute sauvegarde.

`purge_queries.py` fait la purge réellement complète, via l'API Storage —
supprimer la ligne `storage.objects` en SQL rend le fichier inaccessible
mais peut laisser le blob dans le stockage objet.
