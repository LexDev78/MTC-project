"""Ce que `image_fetch` refuse, et ce qu'il laisse passer.

    cd ml && python serve/test_image_fetch.py
"""

from __future__ import annotations

import base64
import os
import sys
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import image_fetch  # noqa: E402
from image_fetch import RejectedImage  # noqa: E402

SUPABASE = "https://abcd.supabase.co"
PHOTO = f"{SUPABASE}/storage/v1/object/public/product-images/b7eb8585-4091-5b6f-83f7-5d70724e97a3/x.jpg"


class CheckUrl(unittest.TestCase):
    def setUp(self):
        patcher = mock.patch.dict(os.environ, {"SUPABASE_URL": SUPABASE}, clear=True)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_une_photo_du_bucket_passe(self):
        self.assertEqual(image_fetch.check_url(PHOTO), PHOTO)

    def test_les_adresses_internes_et_etrangeres_sont_refusees(self):
        for url in [
            "http://169.254.169.254/latest/meta-data/",
            "http://127.0.0.1:8080/embed",
            "http://localhost/",
            "https://exemple.ml/photo.jpg",
            "https://abcd.supabase.co.exemple.ml/storage/v1/object/public/product-images/a.jpg",
            "https://user:pass@abcd.supabase.co/storage/v1/object/public/product-images/a.jpg",
            "file:///etc/passwd",
            "gopher://abcd.supabase.co/",
        ]:
            with self.subTest(url=url), self.assertRaises(RejectedImage):
                image_fetch.check_url(url)

    def test_hors_du_bucket_des_produits_refuse(self):
        for path in [
            "/storage/v1/object/public/review-media/a.jpg",
            "/storage/v1/object/sign/kyc-documents/a.jpg",
            "/auth/v1/admin/users",
            "/storage/v1/object/public/product-images/../kyc-documents/a.jpg",
            "/storage/v1/object/public/product-images/%2e%2e/kyc-documents/a.jpg",
            "/storage/v1/object/public/product-images/a.jpg?download=1",
        ]:
            with self.subTest(path=path), self.assertRaises(RejectedImage):
                image_fetch.check_url(SUPABASE + path)

    def test_http_seulement_pour_les_hotes_declares(self):
        with mock.patch.dict(os.environ, {"MTC_IMAGE_HOSTS": "kong"}, clear=True):
            local = "http://kong/storage/v1/object/public/product-images/a.jpg"
            with self.assertRaises(RejectedImage):
                image_fetch.check_url(local)
            os.environ["MTC_IMAGE_HTTP_HOSTS"] = "kong"
            self.assertEqual(image_fetch.check_url(local), local)

    def test_sans_hote_declare_rien_ne_passe(self):
        with mock.patch.dict(os.environ, {}, clear=True):
            with self.assertRaises(RejectedImage):
                image_fetch.check_url(PHOTO)


class DataUrl(unittest.TestCase):
    def test_une_photo_en_base64_passe(self):
        data = "data:image/jpeg;base64," + base64.b64encode(b"\xff\xd8\xff").decode()
        self.assertEqual(image_fetch.read_image(data), b"\xff\xd8\xff")

    def test_trop_lourde_refusee_avant_decodage(self):
        with mock.patch.dict(os.environ, {"MTC_IMAGE_MAX_BYTES": "10"}):
            data = "data:image/png;base64," + base64.b64encode(b"x" * 100).decode()
            with self.assertRaises(RejectedImage):
                image_fetch.read_image(data)

    def test_autre_type_refuse(self):
        data = "data:text/html;base64," + base64.b64encode(b"<script>").decode()
        with self.assertRaises(RejectedImage):
            image_fetch.read_image(data)


class _Serveur(BaseHTTPRequestHandler):
    def do_GET(self):  # noqa: N802
        if self.path.endswith("/redirige.jpg"):
            self.send_response(302)
            self.send_header("Location", "http://169.254.169.254/latest/meta-data/")
            self.end_headers()
            return
        corps = b"x" * (64 if self.path.endswith("/petite.jpg") else 4096)
        self.send_response(200)
        self.send_header("Content-Type", "image/jpeg")
        self.end_headers()
        self.wfile.write(corps)

    def log_message(self, *args):
        pass


class Telechargement(unittest.TestCase):
    """Contre un vrai serveur local, déclaré comme hôte autorisé."""

    @classmethod
    def setUpClass(cls):
        cls.serveur = HTTPServer(("127.0.0.1", 0), _Serveur)
        threading.Thread(target=cls.serveur.serve_forever, daemon=True).start()
        cls.base = f"http://127.0.0.1:{cls.serveur.server_port}"

    @classmethod
    def tearDownClass(cls):
        cls.serveur.shutdown()

    def setUp(self):
        patcher = mock.patch.dict(os.environ, {
            "MTC_IMAGE_HOSTS": "127.0.0.1",
            "MTC_IMAGE_HTTP_HOSTS": "127.0.0.1",
            "MTC_IMAGE_MAX_BYTES": "1024",
        }, clear=True)
        patcher.start()
        self.addCleanup(patcher.stop)

    def url(self, nom):
        return f"{self.base}/storage/v1/object/public/product-images/{nom}"

    def test_une_petite_photo_se_telecharge(self):
        self.assertEqual(len(image_fetch.read_image(self.url("petite.jpg"))), 64)

    def test_une_photo_trop_lourde_est_coupee(self):
        with self.assertRaises(RejectedImage):
            image_fetch.read_image(self.url("lourde.jpg"))

    def test_une_redirection_est_refusee(self):
        with self.assertRaises(RejectedImage):
            image_fetch.read_image(self.url("redirige.jpg"))


if __name__ == "__main__":
    unittest.main()
