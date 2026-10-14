"""Affine le modèle de base sur nos propres recherches.

## Ce qu'on apprend au modèle

Rapprocher une **photo de requête** du **produit que la personne cherchait**,
et l'éloigner des produits qui lui ont été proposés sans être retenus. Ces
derniers sont des négatifs difficiles : ils ressemblent déjà à la photo, donc
les séparer est exactement le travail qui reste à faire. Des négatifs tirés
au hasard n'apprendraient rien — distinguer un pagne d'une brouette est déjà
acquis.

## La perte

Celle de SigLIP : pour chaque paire (requête, produit), une entropie croisée
binaire sur `σ(échelle · similarité + biais)`, avec +1 pour les paires
correctes et -1 pour les autres.

Pourquoi elle plutôt que l'InfoNCE de CLIP : l'InfoNCE normalise sur le lot,
donc sa qualité dépend du **nombre** de négatifs présents dans le lot. Elle
réclame des lots de plusieurs milliers d'exemples, c'est-à-dire plusieurs
GPU. La perte sigmoïde traite chaque paire indépendamment et tient avec de
petits lots — ce que sera notre matériel.

## Ce qu'on ne touche pas

Les premières couches restent gelées. Avec quelques milliers d'exemples,
tout réentraîner efface la représentation visuelle générale qu'on est
justement venu chercher, et le modèle devient excellent sur nos photos et
inutilisable sur la suivante. Seuls les derniers blocs et les projections
bougent (`--unfreeze`).
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import torch
import torch.nn.functional as F
from PIL import Image
from torch.utils.data import DataLoader, Dataset

import open_clip


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", required=True, help="chemin de pairs.jsonl")
    parser.add_argument("--out", required=True, help="dossier du point de reprise")
    parser.add_argument("--base", default=None, help="défaut : MTC_BASE_MODEL")
    parser.add_argument("--pretrained", default=None)
    parser.add_argument("--epochs", type=int, default=8)
    parser.add_argument("--batch", type=int, default=16)
    parser.add_argument("--lr", type=float, default=1e-5)
    parser.add_argument("--negatives", type=int, default=4,
                        help="négatifs difficiles retenus par requête")
    parser.add_argument("--neg-weight", type=float, default=1.0)
    parser.add_argument("--text-weight", type=float, default=0.5,
                        help="part du texte dans l'empreinte d'un produit")
    parser.add_argument("--unfreeze", type=int, default=2,
                        help="nombre de blocs terminaux à dégeler par tour")
    parser.add_argument("--val-fraction", type=float, default=0.15)
    args = parser.parse_args()

    import os
    base = args.base or os.environ.get("MTC_BASE_MODEL", "ViT-B-16-SigLIP")
    pretrained = args.pretrained or os.environ.get("MTC_BASE_PRETRAINED", "webli")

    device = (
        "cuda" if torch.cuda.is_available()
        else "mps" if torch.backends.mps.is_available()
        else "cpu"
    )
    print(f"Modèle de base : {base} ({pretrained}) sur {device}")

    model, _, preprocess = open_clip.create_model_and_transforms(
        base, pretrained=pretrained
    )
    tokenizer = open_clip.get_tokenizer(base)
    model = model.to(device)

    freeze_all_but_last(model, args.unfreeze)
    trainable = [p for p in model.parameters() if p.requires_grad]
    print(
        f"{sum(p.numel() for p in trainable):,} paramètres entraînables "
        f"sur {sum(p.numel() for p in model.parameters()):,}"
    )

    root = Path(args.data).parent
    pairs = [json.loads(line) for line in Path(args.data).read_text().splitlines()]
    products = {
        row["id"]: row
        for row in (
            json.loads(line)
            for line in (root / "products.jsonl").read_text().splitlines()
        )
    }
    if len(pairs) < 50:
        raise SystemExit(
            f"{len(pairs)} paires seulement : trop peu pour que l'entraînement "
            "signifie quoi que ce soit. Voir ml/README.md."
        )

    # Découpe par date et non au hasard : en production le modèle verra des
    # photos postérieures à son entraînement. Mélanger daterait la mesure
    # d'une optimisme qu'on ne retrouvera pas.
    pairs.sort(key=lambda p: p["created_at"])
    cut = int(len(pairs) * (1 - args.val_fraction))
    train_pairs, val_pairs = pairs[:cut], pairs[cut:]
    print(f"{len(train_pairs)} paires d'entraînement, {len(val_pairs)} de validation")

    make = lambda rows: DataLoader(  # noqa: E731
        PairDataset(rows, products, root, preprocess, tokenizer, args.negatives),
        batch_size=args.batch,
        shuffle=rows is train_pairs,
        collate_fn=collate,
        num_workers=0,
    )
    train_loader, val_loader = make(train_pairs), make(val_pairs)

    optimizer = torch.optim.AdamW(trainable, lr=args.lr, weight_decay=0.01)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(
        optimizer, T_max=max(args.epochs * len(train_loader), 1)
    )

    # Le biais initial très négatif est l'astuce de SigLIP : au départ, la
    # quasi-totalité des paires sont négatives, et sans lui le modèle
    # commence par tout rejeter puis met des époques à s'en remettre.
    logit_scale = torch.nn.Parameter(torch.tensor(math.log(10.0), device=device))
    logit_bias = torch.nn.Parameter(torch.tensor(-10.0, device=device))
    optimizer.add_param_group({"params": [logit_scale, logit_bias], "lr": args.lr * 10})

    best = float("inf")
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    for epoch in range(1, args.epochs + 1):
        model.train()
        total = 0.0
        for batch in train_loader:
            optimizer.zero_grad()
            loss = pair_loss(
                model, batch, device, logit_scale, logit_bias,
                args.text_weight, args.neg_weight,
            )
            loss.backward()
            torch.nn.utils.clip_grad_norm_(trainable, 1.0)
            optimizer.step()
            scheduler.step()
            total += loss.item()
        train_loss = total / max(len(train_loader), 1)

        model.eval()
        with torch.no_grad():
            total = sum(
                pair_loss(
                    model, batch, device, logit_scale, logit_bias,
                    args.text_weight, args.neg_weight,
                ).item()
                for batch in val_loader
            )
        val_loss = total / max(len(val_loader), 1)
        print(f"époque {epoch:2d}  entraînement {train_loss:.4f}  validation {val_loss:.4f}")

        # On garde la meilleure validation, pas la dernière époque : avec peu
        # de données, la perte d'entraînement continue de baisser longtemps
        # après que le modèle a cessé de progresser.
        if val_loss < best:
            best = val_loss
            save(out, model, base, pretrained, args, epoch, val_loss)
            print(f"           → enregistré ({out})")

    print(
        f"\nMeilleure validation : {best:.4f}\n"
        "La perte ne dit pas si le modèle est meilleur en recherche. "
        "Mesurer avec index_catalogue.py puis evaluate.py."
    )


def freeze_all_but_last(model, blocks: int) -> None:
    """Gèle tout, puis rouvre les derniers blocs et les projections.

    Parcours par nom plutôt que par structure : `open_clip` enveloppe des
    architectures différentes (ViT propre, timm, SigLIP) dont les attributs
    ne portent pas les mêmes noms, et un accès direct casserait au premier
    changement de modèle de base.
    """
    for parameter in model.parameters():
        parameter.requires_grad = False

    named = list(model.named_parameters())
    depths = {
        int(part)
        for name, _ in named
        for index, part in enumerate(name.split("."))
        if part.isdigit() and index > 0 and "blocks" in name.split(".")[index - 1]
    }
    threshold = max(depths) - blocks + 1 if depths else 0

    reopened = 0
    for name, parameter in named:
        keep = "proj" in name or name.endswith("ln_final.weight") or "head" in name
        if not keep:
            parts = name.split(".")
            keep = any(
                part.isdigit() and int(part) >= threshold
                and index > 0 and "blocks" in parts[index - 1]
                for index, part in enumerate(parts)
            )
        if keep:
            parameter.requires_grad = True
            reopened += 1

    if reopened == 0:
        # Plutôt que d'entraîner zéro paramètre en silence pendant une heure.
        raise SystemExit(
            "Aucun paramètre dégelé : la nomenclature de ce modèle de base "
            "diffère de celle attendue. Adapter freeze_all_but_last()."
        )


class PairDataset(Dataset):
    def __init__(self, pairs, products, root, preprocess, tokenizer, negatives):
        self.pairs = pairs
        self.products = products
        self.root = Path(root)
        self.preprocess = preprocess
        self.tokenizer = tokenizer
        self.negatives = negatives

    def __len__(self) -> int:
        return len(self.pairs)

    def __getitem__(self, index):
        pair = self.pairs[index]
        query = self.preprocess(
            Image.open(self.root / pair["image"]).convert("RGB")
        )

        # Le positif le plus fort : une mise au panier vaut mieux qu'un clic.
        positive = max(pair["positives"], key=lambda p: p["weight"])

        # Les négatifs arrivent classés par similarité décroissante : les
        # premiers sont les plus instructifs. On complète par répétition
        # plutôt que de rejeter la requête — les négatifs du lot prennent le
        # relais.
        chosen = pair["negatives"][: self.negatives]
        while chosen and len(chosen) < self.negatives:
            chosen.append(chosen[len(chosen) % len(pair["negatives"])])

        return {
            "query": query,
            "positive": self.encode_product(positive["product_id"]),
            "weight": float(positive["weight"]),
            "negatives": [self.encode_product(pid) for pid in chosen],
        }

    def encode_product(self, product_id: str):
        product = self.products[product_id]
        text = ". ".join(
            part for part in (product["name"], product.get("description")) if part
        )
        return {
            "id": product_id,
            "image": self.preprocess(
                Image.open(self.root / product["image"]).convert("RGB")
            ),
            "tokens": self.tokenizer([text])[0],
        }


def collate(items):
    products, ids = [], []
    for item in items:
        for product in [item["positive"], *item["negatives"]]:
            products.append(product)
            ids.append(product["id"])
    return {
        "queries": torch.stack([item["query"] for item in items]),
        "weights": torch.tensor([item["weight"] for item in items]),
        "product_images": torch.stack([p["image"] for p in products]),
        "product_tokens": torch.stack([p["tokens"] for p in products]),
        "product_ids": ids,
        "positive_ids": [item["positive"]["id"] for item in items],
    }


def pair_loss(model, batch, device, logit_scale, logit_bias, text_weight, neg_weight):
    """La perte sigmoïde, sur toutes les paires du lot.

    Tous les produits du lot servent de négatifs à toutes les requêtes — pas
    seulement ceux apportés par la requête. C'est gratuit et c'est ce qui
    permet d'apprendre avec peu de données.

    Les étiquettes se construisent par **identifiant** de produit et non par
    position : deux requêtes différentes peuvent avoir le même produit pour
    réponse, et le compter comme négatif pour l'une apprendrait le contraire
    de ce qu'on veut.
    """
    queries = model.encode_image(batch["queries"].to(device))
    queries = F.normalize(queries, dim=-1)

    product_images = F.normalize(
        model.encode_image(batch["product_images"].to(device)), dim=-1
    )
    if text_weight > 0:
        product_texts = F.normalize(
            model.encode_text(batch["product_tokens"].to(device)), dim=-1
        )
        products = F.normalize(
            (1 - text_weight) * product_images + text_weight * product_texts, dim=-1
        )
    else:
        products = product_images

    logits = logit_scale.exp() * (queries @ products.T) + logit_bias

    positive_ids = batch["positive_ids"]
    product_ids = batch["product_ids"]
    mask = torch.tensor(
        [[pid == qpos for pid in product_ids] for qpos in positive_ids],
        device=device,
    )

    # `logsigmoid(x)` et `logsigmoid(-x)` plutôt que `log(sigmoid(...))` :
    # stable quand les logits s'écartent, ce qu'ils font dès que le modèle
    # apprend.
    loss_positive = -F.logsigmoid(logits[mask])
    loss_negative = -F.logsigmoid(-logits[~mask])

    weights = batch["weights"].to(device)
    weights = weights / weights.mean()
    # Chaque requête n'a qu'un positif dans le masque (le plus fort) : les
    # poids s'alignent ligne à ligne.
    weighted_positive = (loss_positive * weights[: loss_positive.numel()]).mean()

    return weighted_positive + neg_weight * loss_negative.mean()


def save(out: Path, model, base, pretrained, args, epoch, val_loss) -> None:
    torch.save({"model": model.state_dict()}, out / "model.pt")
    (out / "metadata.json").write_text(json.dumps({
        "base_model": base,
        "pretrained": pretrained,
        # Relu par index_catalogue.py, evaluate.py et serve/ : l'empreinte
        # d'un produit doit être calculée avec le même mélange à
        # l'indexation qu'à l'entraînement, sinon la mesure porte sur autre
        # chose que ce qui a été appris.
        "text_weight": args.text_weight,
        "epoch": epoch,
        "val_loss": val_loss,
    }, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
