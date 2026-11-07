"""Indexe le catalogue avec un modèle local, sans le mettre en service.

C'est l'étape qui rend une comparaison possible. Le modèle servant continue
de répondre aux clients pendant ce temps : les empreintes cohabitent, une
par (produit, modèle), et seule la colonne `role` de `ai_models` décide
laquelle est consultée (`0085`).

À faire tourner après l'entraînement et avant `evaluate.py` — une mesure sur
un catalogue non indexé ne mesure que l'indexation manquante.
"""

from __future__ import annotations

import argparse
import json
import tempfile
from pathlib import Path

from common import (
    UnreachableImage,
    download_product_image,
    load_encoder,
    supabase,
)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkpoint", required=True)
    parser.add_argument("--model", required=True, help="nom déclaré dans ai_models")
    parser.add_argument("--limit", type=int, default=200)
    parser.add_argument("--text-weight", type=float, default=None,
                        help="défaut : la valeur d'entraînement, lue dans metadata.json")
    args = parser.parse_args()

    client = supabase()

    registered = client.table("ai_models").select("name, dim, role").eq(
        "name", args.model
    ).maybe_single().execute().data
    if not registered:
        raise SystemExit(
            f"« {args.model} » n'est pas dans ai_models. Le déclarer d'abord :\n\n"
            "  insert into public.ai_models (name, kind, dim, provider, role)\n"
            f"  values ('{args.model}', 'embedding', <dim>, 'self_hosted', 'candidate');"
        )

    encoder = load_encoder(args.checkpoint)
    if encoder.dim != registered["dim"]:
        raise SystemExit(
            f"Le registre annonce {registered['dim']} dimensions, le modèle en "
            f"produit {encoder.dim}. Corriger ai_models avant d'indexer — sinon "
            "les vecteurs seront refusés un par un."
        )

    # Le même mélange texte/image qu'à l'entraînement, sans quoi
    # l'évaluation porterait sur autre chose que ce qui a été appris.
    text_weight = args.text_weight
    if text_weight is None:
        metadata = Path(args.checkpoint) / "metadata.json"
        text_weight = (
            json.loads(metadata.read_text())["text_weight"]
            if metadata.exists() else 0.5
        )
    print(f"{args.model} — {encoder.dim} dimensions, poids du texte {text_weight}")

    pending = client.rpc(
        "products_needing_embedding",
        {"p_limit": args.limit, "p_model": args.model},
    ).execute().data or []
    if not pending:
        print("Rien à indexer : le catalogue est à jour pour ce modèle.")
        return

    cache = Path(tempfile.mkdtemp(prefix="mtc-index-"))
    indexed, skipped = 0, 0

    for product in pending:
        path = product["image_url"]
        if not path:
            continue
        try:
            local = download_product_image(client, path, cache / path.replace("/", "_"))
        except UnreachableImage as unreachable:
            print(f"  ignoré {product['product_id']}: {unreachable}")
            skipped += 1
            continue
        except Exception as failure:  # noqa: BLE001
            print(f"  échec {product['product_id']}: {failure}")
            skipped += 1
            continue

        text = ". ".join(
            part for part in (product["name"], product.get("description")) if part
        )
        vector = encoder.embed_product(local, text, text_weight)

        client.rpc("upsert_product_embedding", {
            "p_product_id": product["product_id"],
            "p_embedding": [float(value) for value in vector],
            "p_model": args.model,
            # Le **chemin**, pas l'URL résolue : c'est lui que
            # `products_needing_embedding` compare pour détecter une photo
            # changée.
            "p_source_image_url": path,
        }).execute()
        indexed += 1

    print(f"\n{indexed} produits indexés, {skipped} écartés.")
    if skipped:
        print(
            "Les produits écartés sont ceux dont la photo est embarquée dans "
            "l'application (jeu de démonstration) : aucun serveur ne peut les lire."
        )


if __name__ == "__main__":
    main()
