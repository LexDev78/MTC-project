"""Sert notre modèle derrière le même contrat que le modèle externe.

C'est la pièce qui rend la bascule invisible pour le reste du système :
`supabase/functions/_shared/embeddings.ts` appelle `POST /embed` et reçoit
`{embedding: [...]}`, exactement comme il appelait Voyage. Rien d'autre ne
change côté serveur, et rien du tout côté application.

Le contrat est volontairement le nôtre et non celui de Voyage : il n'y a
aucune raison d'imiter la forme d'une API qu'on quitte.

    MTC_CHECKPOINT=/models/mtc-v1 \
    MTC_SERVE_TOKEN=... \
    uvicorn app:app --host 0.0.0.0 --port 8080
"""

from __future__ import annotations

import base64
import binascii
import json
import os
import re
import tempfile
from pathlib import Path

from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel

import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from common import load_encoder  # noqa: E402

app = FastAPI(title="MTC embeddings")

DATA_URL = re.compile(r"^data:([^;,]+);base64,(.*)$", re.S)

_encoder = None
_text_weight = 0.5
_model_name = os.environ.get("MTC_MODEL_NAME", "mtc-v1")


@app.on_event("startup")
def load() -> None:
    """Chargé une fois, au démarrage.

    Un modèle se charge en quelques secondes et pèse plusieurs centaines de
    mégaoctets : le faire par requête rendrait chaque recherche plus lente
    que l'appel à l'API externe qu'on remplace.
    """
    global _encoder, _text_weight
    checkpoint = os.environ.get("MTC_CHECKPOINT")
    if not checkpoint:
        raise RuntimeError("MTC_CHECKPOINT est requis.")
    _encoder = load_encoder(checkpoint)

    metadata = Path(checkpoint) / "metadata.json"
    if metadata.exists():
        # Le même mélange qu'à l'entraînement et qu'à l'indexation. Un écart
        # ici décalerait silencieusement toutes les requêtes par rapport au
        # catalogue indexé.
        _text_weight = json.loads(metadata.read_text()).get("text_weight", 0.5)


class EmbedRequest(BaseModel):
    model: str | None = None
    text: str | None = None
    image: str | None = None


@app.get("/health")
def health() -> dict:
    return {
        "ready": _encoder is not None,
        "model": _model_name,
        "dim": _encoder.dim if _encoder else None,
    }


@app.post("/embed")
def embed(request: EmbedRequest, authorization: str | None = Header(default=None)) -> dict:
    expected = os.environ.get("MTC_SERVE_TOKEN")
    # Le jeton est exigé dès qu'il est configuré. Sans lui, n'importe qui
    # pouvant joindre le port consomme le GPU.
    if expected and authorization != f"Bearer {expected}":
        raise HTTPException(status_code=401, detail="Non autorisé.")
    if _encoder is None:
        raise HTTPException(status_code=503, detail="Modèle pas encore chargé.")
    if not request.image and not request.text:
        raise HTTPException(status_code=400, detail="Ni texte ni image.")

    if request.image:
        with tempfile.NamedTemporaryFile(suffix=".bin", delete=True) as handle:
            handle.write(read_image(request.image))
            handle.flush()
            vector = _encoder.embed_product(handle.name, request.text, _text_weight)
    else:
        vector = _encoder.embed_text(request.text)

    return {
        "embedding": [float(value) for value in vector],
        "model": request.model or _model_name,
        "dim": len(vector),
    }


def read_image(image: str) -> bytes:
    match = DATA_URL.match(image)
    if match:
        try:
            return base64.b64decode(match.group(2), validate=True)
        except (binascii.Error, ValueError) as invalid:
            raise HTTPException(status_code=400, detail="Base64 illisible.") from invalid

    if image.startswith(("http://", "https://")):
        import urllib.request

        with urllib.request.urlopen(image, timeout=20) as response:
            return response.read()

    raise HTTPException(status_code=400, detail="Image non reconnue.")
