"""Note un modèle sur l'étalon, et le compare aux autres.

Trois chiffres, sur les **mêmes** photos pour tous les modèles :

  recall@1  le premier résultat était le bon
  recall@5  le bon produit était visible sans faire défiler
  MRR       moyenne des inverses du rang — distingue une 1re place d'une 5e,
            ce que recall@5 confond

Le seuil de similarité est écarté de la mesure (`evaluate_model_recall`
travaille à seuil nul) : on mesure la capacité à **classer**, pas le réglage
du seuil. Les deux se règlent séparément, et les confondre fait attribuer au
modèle un défaut de réglage.
"""

from __future__ import annotations

import argparse
import json
import tempfile
from pathlib import Path

from common import (
    download_query_image,
    embed_with_voyage,
    load_encoder,
    supabase,
)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", required=True, help="le modèle à noter")
    parser.add_argument("--checkpoint", default=None,
                        help="requis si le modèle est auto-hébergé")
    parser.add_argument("--compare", nargs="*", default=[],
                        help="autres modèles à noter sur le même étalon")
    parser.add_argument("--text-weight", type=float, default=None)
    parser.add_argument("--k", type=int, nargs="*", default=[1, 5])
    args = parser.parse_args()

    client = supabase()

    examples = client.table("ai_eval_examples").select(
        "id, image_path, expected_product_id"
    ).execute().data or []
    if not examples:
        raise SystemExit(
            "L'étalon est vide. Le constituer depuis de vraies recherches :\n\n"
            "  select public.promote_queries_to_eval(100);"
        )
    print(f"{len(examples)} photos d'évaluation\n")

    for name in [args.model, *args.compare]:
        ensure_embeddings(client, name, examples, args)

    rows = []
    for name in [args.model, *args.compare]:
        measures = {}
        for k in args.k:
            result = client.rpc(
                "evaluate_model_recall", {"p_model": name, "p_k": k}
            ).execute().data
            measures[k] = result[0] if isinstance(result, list) else result
        rows.append((name, measures))

    report(rows, args.k)


def ensure_embeddings(client, model: str, examples, args) -> None:
    """Calcule les empreintes manquantes de l'étalon pour ce modèle.

    Une fois calculées, elles restent en base : rejouer la mesure avec un
    autre `k` ne coûte plus rien, et comparer deux modèles ne demande pas de
    recalculer celui qui l'a déjà été.
    """
    registered = client.table("ai_models").select("name, provider, dim").eq(
        "name", model
    ).maybe_single().execute().data
    if not registered:
        raise SystemExit(f"« {model} » n'est pas dans ai_models.")

    existing = {
        row["example_id"]
        for row in client.table("ai_eval_embeddings").select("example_id").eq(
            "model", model
        ).execute().data or []
    }
    missing = [row for row in examples if row["id"] not in existing]
    if not missing:
        return

    print(f"{model} : {len(missing)} empreintes à calculer…")
    cache = Path(tempfile.mkdtemp(prefix="mtc-eval-"))

    encoder = None
    if registered["provider"] == "self_hosted":
        if not args.checkpoint:
            raise SystemExit(
                f"« {model} » est auto-hébergé : --checkpoint est requis pour le noter."
            )
        encoder = load_encoder(args.checkpoint)

    for example in missing:
        local = download_query_image(
            client, example["image_path"], cache / example["image_path"].replace("/", "_")
        )
        # Une photo de requête est une image **seule** : c'est ce que le
        # client envoie, et la mesure doit reproduire exactement cela.
        vector = (
            encoder.embed_image(local) if encoder
            else embed_with_voyage(local, model=model)
        )
        client.table("ai_eval_embeddings").upsert({
            "example_id": example["id"],
            "model": model,
            "embedding": "[" + ",".join(str(float(v)) for v in vector) + "]",
            "dim": len(vector),
        }).execute()


def report(rows, ks) -> None:
    header = f"{'modèle':<28} {'photos':>7}" + "".join(
        f"{'recall@' + str(k):>11}" for k in ks
    ) + f"{'MRR':>8}"
    print("\n" + header)
    print("-" * len(header))
    for name, measures in rows:
        first = measures[ks[0]]
        line = f"{name:<28} {first['examples']:>7}"
        for k in ks:
            value = measures[k]["recall_at_k"]
            line += f"{(value if value is not None else 0):>11.3f}"
        mrr = first["mrr"]
        line += f"{(mrr if mrr is not None else 0):>8.3f}"
        print(line)

    print(
        "\nUn modèle maison qui ne dépasse pas le modèle externe n'a rien à\n"
        "déployer : on garde l'externe et on attend plus de données. C'est la\n"
        "conclusion la plus fréquente au premier essai, et elle est bonne."
    )


if __name__ == "__main__":
    main()
