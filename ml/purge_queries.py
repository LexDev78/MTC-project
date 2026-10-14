"""Efface réellement les fichiers dont la base a demandé la suppression.

Supabase refuse qu'on supprime un fichier en SQL (« Direct deletion from
storage tables is not allowed »), et c'est un bon garde-fou : la ligne
partirait, le blob resterait, et plus rien n'en garderait la trace.

La base enregistre donc l'intention dans `storage_purge_queue` (`0088`) —
elle seule connaît les règles — et ce script l'exécute via l'API Storage,
qui supprime le fichier *et* sa ligne.

À faire tourner périodiquement. Tant qu'il ne passe pas, les fichiers
existent encore : inaccessibles (le bucket est privé et sans policy client)
mais présents.
"""


from __future__ import annotations

import argparse

from common import supabase


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true",
                        help="sans ce drapeau, le script ne fait que lister")
    parser.add_argument("--batch", type=int, default=100,
                        help="fichiers supprimés par appel à l'API Storage")
    args = parser.parse_args()

    client = supabase()

    pending = client.table("storage_purge_queue").select(
        "bucket_id, object_path, requested_at"
    ).order("requested_at").execute().data or []

    if not pending:
        print("Rien en attente.")
        return

    by_bucket: dict[str, list[str]] = {}
    for row in pending:
        by_bucket.setdefault(row["bucket_id"], []).append(row["object_path"])

    for bucket, paths in by_bucket.items():
        print(f"{bucket} : {len(paths)} fichiers en attente")
    if not args.apply:
        print("\nLecture seule. Relancer avec --apply pour effacer.")
        return

    removed = 0
    for bucket, paths in by_bucket.items():
        for start in range(0, len(paths), args.batch):
            chunk = paths[start:start + args.batch]
            # L'API Storage supprime le fichier *et* sa ligne — ce que le SQL
            # ne peut pas faire.
            client.storage.from_(bucket).remove(chunk)
            # La file ne se vide qu'après : si l'appel échoue, le travail
            # reste à faire au prochain passage plutôt que d'être oublié.
            for path in chunk:
                client.table("storage_purge_queue").delete().eq(
                    "bucket_id", bucket
                ).eq("object_path", path).execute()
            removed += len(chunk)

    print(f"\n{removed} fichiers effacés.")


if __name__ == "__main__":
    main()
