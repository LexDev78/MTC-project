"""Ce que tous les scripts de ce dossier partagent.

Connexion à Supabase avec la clé de service, résolution des chemins
d'images, et l'encodeur `open_clip` enveloppé derrière deux méthodes.

Tout ici s'exécute sur la machine de l'exploitant, jamais sur un serveur
exposé : les tables lues (requêtes conservées, empreintes, jeu
d'évaluation) sont fermées aux clients, et la clé de service ne quitte pas
cette machine.
"""

from __future__ import annotations

import os
import urllib.parse
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv
from supabase import Client, create_client

load_dotenv(Path(__file__).parent / ".env")

PRODUCT_IMAGE_BUCKET = "product-images"
QUERY_IMAGE_BUCKET = "visual-search-queries"


def supabase() -> Client:
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not url or not key:
        raise SystemExit(
            "SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY sont requis — voir ml/.env.example"
        )
    return create_client(url, key)


class UnreachableImage(Exception):
    """Photo que le serveur ne peut pas atteindre."""


def resolve_product_image_url(path: str) -> str:
    """Pendant Python de `_shared/image_urls.ts`.

    `products.image_urls` stocke un chemin, pas une URL (voir le fichier TS
    pour le détail). Les photos `assets/...` du jeu de démonstration
    n'existent que dans le binaire de l'application : aucun script ne les
    lira, et mieux vaut une exception qu'un téléchargement qui échoue à
    mi-chemin.
    """
    if path.startswith("assets/"):
        raise UnreachableImage(
            f"Photo embarquée dans l'application : {path}"
        )
    if path.startswith(("http://", "https://")):
        return path
    base = os.environ["SUPABASE_URL"].rstrip("/")
    quoted = "/".join(urllib.parse.quote(part) for part in path.split("/"))
    return f"{base}/storage/v1/object/public/{PRODUCT_IMAGE_BUCKET}/{quoted}"


def download_query_image(client: Client, path: str, dest: Path) -> Path:
    """Télécharge une photo de requête depuis le bucket privé."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        return dest
    dest.write_bytes(client.storage.from_(QUERY_IMAGE_BUCKET).download(path))
    return dest


def download_product_image(client: Client, path: str, dest: Path) -> Path:
    """Télécharge une photo de produit depuis le bucket public."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        return dest
    resolve_product_image_url(path)  # lève tôt si la photo est inatteignable
    dest.write_bytes(client.storage.from_(PRODUCT_IMAGE_BUCKET).download(path))
    return dest


# ---- l'encodeur ------------------------------------------------------------


@dataclass
class Encoder:
    """Un modèle `open_clip` derrière le strict nécessaire.

    Deux tours — image et texte — projetant dans le **même** espace. C'est
    ce qui permet de comparer une photo de requête à un produit décrit par
    sa photo *et* son nom.
    """

    model: object
    preprocess: object
    tokenizer: object
    device: str
    dim: int

    def embed_image(self, path):  # -> np.ndarray
        import torch
        from PIL import Image

        with torch.no_grad():
            tensor = self.preprocess(Image.open(path).convert("RGB"))
            tensor = tensor.unsqueeze(0).to(self.device)
            features = self.model.encode_image(tensor)
            features = features / features.norm(dim=-1, keepdim=True)
        return features.cpu().numpy()[0]

    def embed_text(self, text: str):  # -> np.ndarray
        import torch

        with torch.no_grad():
            tokens = self.tokenizer([text]).to(self.device)
            features = self.model.encode_text(tokens)
            features = features / features.norm(dim=-1, keepdim=True)
        return features.cpu().numpy()[0]

    def embed_product(self, image_path, text: str | None, text_weight: float = 0.5):
        """L'empreinte d'un produit : sa photo, et ses mots.

        Les deux vecteurs normalisés sont mélangés puis renormalisés. Ce
        n'est pas une évidence — c'est un réglage.

        La requête est une photo seule ; le produit a une photo *et* un nom.
        Mélanger place le produit entre son image et sa description, ce qui
        aide quand deux articles se ressemblent en photo et que seul le nom
        les sépare (le cas des tissus). Mais trop de texte éloigne le
        produit de sa propre photo, et dégrade précisément la comparaison
        image-image que fait la recherche.

        D'où un poids, et non une constante : `evaluate.py` le mesure.
        `text_weight=0` donne une comparaison purement visuelle.
        """
        import numpy as np

        image_vector = self.embed_image(image_path)
        if not text or text_weight <= 0:
            return image_vector
        text_vector = self.embed_text(text)
        mixed = (1 - text_weight) * image_vector + text_weight * text_vector
        norm = np.linalg.norm(mixed)
        return mixed if norm == 0 else mixed / norm


def load_encoder(checkpoint: str | None = None, trainable: bool = False) -> Encoder:
    """Charge le modèle de base, et par-dessus notre point de reprise s'il existe.

    Le modèle de base vient de `MTC_BASE_MODEL` / `MTC_BASE_PRETRAINED` :
    il n'est pas figé dans le code, parce que le choix se tranche par la
    mesure (voir README).
    """
    import open_clip
    import torch

    base = os.environ.get("MTC_BASE_MODEL", "ViT-B-16-SigLIP")
    pretrained = os.environ.get("MTC_BASE_PRETRAINED", "webli")
    device = (
        "cuda" if torch.cuda.is_available()
        # Les Mac Apple Silicon : utile pour mettre la chaîne au point, pas
        # pour entraîner sérieusement.
        else "mps" if torch.backends.mps.is_available()
        else "cpu"
    )

    model, _, preprocess = open_clip.create_model_and_transforms(
        base, pretrained=pretrained
    )
    tokenizer = open_clip.get_tokenizer(base)

    if checkpoint:
        state = torch.load(Path(checkpoint) / "model.pt", map_location="cpu")
        model.load_state_dict(state["model"])

    model = model.to(device)
    model.train() if trainable else model.eval()

    with torch.no_grad():
        probe = model.encode_text(tokenizer(["dimension"]).to(device))
    return Encoder(
        model=model,
        preprocess=preprocess,
        tokenizer=tokenizer,
        device=device,
        dim=probe.shape[-1],
    )


# ---- le modèle externe, pour pouvoir le comparer --------------------------


def embed_with_voyage(image_path, text: str | None = None, model: str = "voyage-multimodal-3.5"):
    """Empreinte par l'API externe.

    Présent uniquement pour que `evaluate.py` puisse noter le modèle en
    service sur le même étalon que le modèle maison. Sans ce point de
    comparaison, « notre modèle a 0,62 de recall@5 » ne veut rien dire.
    """
    import base64
    import json
    import mimetypes
    import urllib.request

    import numpy as np

    api_key = os.environ.get("VOYAGE_API_KEY")
    if not api_key:
        raise SystemExit(
            "VOYAGE_API_KEY est requis pour comparer au modèle externe — voir ml/.env.example"
        )

    path = Path(image_path)
    mime = mimetypes.guess_type(path.name)[0] or "image/jpeg"
    data_url = (
        f"data:{mime};base64," + base64.b64encode(path.read_bytes()).decode()
    )

    content = []
    if text:
        content.append({"type": "text", "text": text})
    content.append({"type": "image_base64", "image_base64": data_url})

    request = urllib.request.Request(
        "https://api.voyageai.com/v1/multimodalembeddings",
        data=json.dumps({
            "model": model,
            "inputs": [{"content": content}],
            "input_type": "document",
        }).encode(),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        body = json.loads(response.read())
    return np.array(body["data"][0]["embedding"], dtype="float32")
