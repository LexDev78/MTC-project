# Une image qui porte le modèle, pas la chaîne d'entraînement.
#
# `torch` sur CPU : le service rend une empreinte par requête, et une
# recherche par photo n'a pas besoin de GPU pour ça (quelques dizaines de
# millisecondes sur CPU, contre une seconde d'aller-retour réseau vers une
# API externe). Le GPU sert à l'entraînement, qui se fait ailleurs.
#
# Conséquence utile : ce service tient sur une machine ordinaire, ce qui est
# tout l'intérêt d'héberger son modèle depuis le Mali.
FROM python:3.12-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends libgl1 libglib2.0-0 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Les roues CPU, nettement plus légères que les roues CUDA par défaut.
RUN pip install --no-cache-dir \
      --extra-index-url https://download.pytorch.org/whl/cpu \
      torch torchvision

COPY requirements-serve.txt .
RUN pip install --no-cache-dir -r requirements-serve.txt

COPY common.py /app/common.py
COPY serve/app.py /app/app.py

ENV MTC_CHECKPOINT=/models/mtc-v1
EXPOSE 8080

# Le point de reprise est monté, pas copié : il pèse plusieurs centaines de
# mégaoctets et change plus souvent que l'image.
#   docker run -p 8080:8080 -v $PWD/checkpoints:/models mtc-embeddings
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080"]

# Construire depuis `ml/` et non depuis `ml/serve/`, parce que l'image a
# besoin de `common.py` :
#   docker build -f serve/Dockerfile -t mtc-embeddings .
