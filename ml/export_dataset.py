"""Sort de la base ce qu'un entraînement consomme.

Deux fichiers dans le dossier de sortie :

  pairs.jsonl     une ligne par recherche étiquetée — la photo, le ou les
                  produits retenus, et les candidats écartés
  products.jsonl  les produits cités, avec leur photo et leur texte

Et les images à côté, parce qu'un entraînement les relit à chaque époque :
les retélécharger chaque fois coûterait plus que l'entraînement lui-même.

Les photos promues au jeu d'évaluation sont absentes : `export_training_pairs`
les exclut en base. C'est ce qui empêche de mesurer un modèle sur ce qu'il a
déjà vu — l'erreur qui fait croire au succès.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from common import (
    UnreachableImage,
    download_product_image,
    download_query_image,
    supabase,
)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default="data/train", help="dossier de sortie")
    parser.add_argument("--since", default=None, help="ISO-8601, ex. 2026-01-01")
    parser.add_argument("--limit", type=int, default=5000)
    args = parser.parse_args()

    client = supabase()
    out = Path(args.out)
    (out / "queries").mkdir(parents=True, exist_ok=True)
    (out / "products").mkdir(parents=True, exist_ok=True)

    rows = client.rpc(
        "export_training_pairs",
        {"p_since": args.since, "p_limit": args.limit},
    ).execute().data or []

    if not rows:
        raise SystemExit(
            "Aucune paire étiquetée. L'usage n'a pas encore produit de donnée : "
            "voir `select public.ai_training_readiness();`"
        )

    # Les produits cités, positifs comme négatifs : l'entraînement a besoin
    # de leur photo pour construire les paires.
    product_ids: set[str] = set()
    for row in rows:
        product_ids.update(p["product_id"] for p in row["positives"])
        product_ids.update(row["negatives"])

    products = fetch_products(client, sorted(product_ids))

    kept_products: dict[str, dict] = {}
    for product in products:
        path = (product.get("image_urls") or [None])[0]
        if not path:
            continue
        try:
            local = download_product_image(
                client, path, out / "products" / safe_name(path)
            )
        except UnreachableImage as unreachable:
            # Le jeu de démonstration, essentiellement. Sans sa photo, un
            # produit ne peut ni servir de positif ni de négatif.
            print(f"  ignoré {product['id']}: {unreachable}")
            continue
        except Exception as failure:  # noqa: BLE001 — un lien mort ne doit pas tout arrêter
            print(f"  échec {product['id']}: {failure}")
            continue
        kept_products[product["id"]] = {
            "id": product["id"],
            "name": product["name"],
            "description": product.get("description"),
            "image": str(local.relative_to(out)),
        }

    pairs = []
    for row in rows:
        positives = [
            p for p in row["positives"] if p["product_id"] in kept_products
        ]
        negatives = [n for n in row["negatives"] if n in kept_products]
        if not positives:
            continue
        try:
            local = download_query_image(
                client, row["image_path"], out / "queries" / safe_name(row["image_path"])
            )
        except Exception as failure:  # noqa: BLE001
            print(f"  photo de requête illisible {row['query_id']}: {failure}")
            continue
        pairs.append({
            "query_id": row["query_id"],
            "image": str(local.relative_to(out)),
            "positives": positives,
            "negatives": negatives,
            "created_at": row["created_at"],
        })

    write_jsonl(out / "products.jsonl", kept_products.values())
    write_jsonl(out / "pairs.jsonl", pairs)

    negatives_total = sum(len(p["negatives"]) for p in pairs)
    print(
        f"\n{len(pairs)} paires, {len(kept_products)} produits, "
        f"{negatives_total} négatifs difficiles → {out}"
    )
    if len(pairs) < 500:
        print(
            "\nMoins de 500 paires : un affinage sur-apprendrait et dégraderait\n"
            "le modèle de départ. Laisser la donnée s'accumuler."
        )


def fetch_products(client, ids: list[str]) -> list[dict]:
    """Par paquets : une clause `in` de mille identifiants dépasse la limite
    d'URL de PostgREST, et l'erreur ne dit pas pourquoi."""
    out: list[dict] = []
    for start in range(0, len(ids), 100):
        chunk = ids[start:start + 100]
        out.extend(
            client.table("products")
            .select("id, name, description, image_urls")
            .in_("id", chunk)
            .execute().data or []
        )
    return out


def safe_name(path: str) -> str:
    return path.replace("/", "_")


def write_jsonl(path: Path, rows) -> None:
    with path.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
