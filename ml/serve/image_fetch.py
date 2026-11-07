"""Ce que le service d'empreintes accepte de télécharger, et comment.

Le service reçoit une image en data URL (recherche par photo) ou en URL
(indexation du catalogue, `index-product-embeddings`). Une URL quelconque
le faisait appeler n'importe quelle adresse — le réseau interne de la
machine, le service de métadonnées d'un hébergeur — pour le compte d'une
boutique qui avait écrit cette URL dans ses photos (audit du 27/10/2026,
faille 8). La base n'accepte plus d'URL dans les photos (`0145`), et ce
module ne télécharge plus que ce qu'une photo de produit peut légitimement
être :

  * une URL du bucket public `product-images`
    (`/storage/v1/object/public/product-images/...`) ;
  * sur l'un des hôtes déclarés (`MTC_IMAGE_HOSTS`, à défaut celui de
    `SUPABASE_URL`) — sans hôte déclaré, aucune URL n'est acceptée ;
  * en HTTPS, sauf pour un hôte listé dans `MTC_IMAGE_HTTP_HOSTS` (la pile
    locale) ;
  * sans redirection, en au plus `MTC_IMAGE_MAX_BYTES` octets (10 Mo par
    défaut) et `MTC_IMAGE_TIMEOUT` secondes.

Bibliothèque standard seulement : le module se teste sans le modèle
(`python serve/test_image_fetch.py`, depuis `ml/`).
"""

from __future__ import annotations

import base64
import binascii
import os
import re
import urllib.error
import urllib.parse
import urllib.request

PRODUCT_IMAGE_PREFIX = "/storage/v1/object/public/product-images/"
DATA_URL = re.compile(r"^data:(image/(?:jpeg|png|webp));base64,(.*)$", re.S)


class RejectedImage(ValueError):
    """Image refusée : le message peut être rendu tel quel à l'appelant."""


def _hosts(variable: str) -> set[str]:
    return {
        host.strip().lower()
        for host in os.environ.get(variable, "").split(",")
        if host.strip()
    }


def allowed_hosts() -> set[str]:
    hosts = _hosts("MTC_IMAGE_HOSTS")
    if not hosts and os.environ.get("SUPABASE_URL"):
        host = urllib.parse.urlsplit(os.environ["SUPABASE_URL"]).hostname
        if host:
            hosts.add(host.lower())
    return hosts


def max_bytes() -> int:
    return int(os.environ.get("MTC_IMAGE_MAX_BYTES", str(10 * 1024 * 1024)))


def check_url(url: str) -> str:
    """Rend l'URL si elle est acceptable, lève `RejectedImage` sinon."""
    parts = urllib.parse.urlsplit(url)
    host = (parts.hostname or "").lower()
    if parts.scheme not in ("https", "http"):
        raise RejectedImage("Seules les URL http(s) sont acceptées.")
    if parts.username or parts.password:
        raise RejectedImage("URL refusée.")
    if host not in allowed_hosts():
        raise RejectedImage("Hôte non autorisé.")
    if parts.scheme == "http" and host not in _hosts("MTC_IMAGE_HTTP_HOSTS"):
        raise RejectedImage("HTTPS requis.")
    path = urllib.parse.unquote(parts.path)
    if not path.startswith(PRODUCT_IMAGE_PREFIX) or ".." in path or "\\" in path:
        raise RejectedImage("Seules les photos de produit sont acceptées.")
    if parts.query or parts.fragment:
        raise RejectedImage("URL refusée.")
    return url


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    """Une redirection mènerait ailleurs que là où `check_url` a regardé."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):  # noqa: D102
        raise RejectedImage("Redirection refusée.")


_opener = urllib.request.build_opener(_NoRedirect)


def fetch_url(url: str) -> bytes:
    check_url(url)
    limit = max_bytes()
    timeout = float(os.environ.get("MTC_IMAGE_TIMEOUT", "10"))
    try:
        with _opener.open(url, timeout=timeout) as response:
            declared = response.headers.get("Content-Length")
            if declared and declared.isdigit() and int(declared) > limit:
                raise RejectedImage("Image trop lourde.")
            body = response.read(limit + 1)
    except urllib.error.URLError as error:
        if isinstance(error.reason, RejectedImage):
            raise error.reason
        raise RejectedImage("Image injoignable.") from error
    if len(body) > limit:
        raise RejectedImage("Image trop lourde.")
    return body


def decode_data_url(image: str) -> bytes:
    match = DATA_URL.match(image)
    if not match:
        raise RejectedImage("Image non reconnue.")
    encoded = match.group(2)
    # Base64 : 4 caractères pour 3 octets. On refuse avant de décoder.
    if len(encoded) * 3 // 4 > max_bytes():
        raise RejectedImage("Image trop lourde.")
    try:
        return base64.b64decode(encoded, validate=True)
    except (binascii.Error, ValueError) as invalid:
        raise RejectedImage("Base64 illisible.") from invalid


def read_image(image: str) -> bytes:
    if image.startswith("data:"):
        return decode_data_url(image)
    return fetch_url(image)
