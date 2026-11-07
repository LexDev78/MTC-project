#!/usr/bin/env bash
# Construire une version publiée de l'app MTC — et refuser de la construire
# mal configurée.
#
#   SUPABASE_URL=https://<projet>.supabase.co \
#   SUPABASE_ANON_KEY=<clé publique du projet> \
#   tool/build_release.sh appbundle        # ou : apk, ipa, web
#
# Tout argument après la cible est transmis à `flutter build` tel quel.
#
# Ce que le script refuse, et pourquoi :
#   * une URL absente, en http, ou locale : l'app chercherait la base sur le
#     téléphone lui-même, ou ferait passer mots de passe et jetons en clair ;
#   * une clé anonyme absente : aucune requête ne passerait ;
#   * pour Android, une clé de signature absente : la release partirait
#     signée avec la clé de debug, identique sur toutes les machines Flutter
#     (`android/key.properties.example`).
#
# `lib/bootstrap.dart` refait les deux premiers contrôles au démarrage d'un
# build de release : un APK construit sans ce script ne démarre pas faux.
set -euo pipefail

cd "$(dirname "$0")/.."

cible="${1:-}"
if [[ -z "$cible" ]]; then
  echo "Usage : tool/build_release.sh <appbundle|apk|ipa|web> [arguments de flutter build]" >&2
  exit 64
fi
shift

refus() { echo "Refusé : $*" >&2; exit 1; }

url="${SUPABASE_URL:-}"
cle="${SUPABASE_ANON_KEY:-}"

[[ -n "$url" ]] || refus "SUPABASE_URL n'est pas défini."
[[ "$url" == https://* ]] || refus "SUPABASE_URL doit commencer par https:// (reçu : $url)."
hote="${url#https://}"
hote="${hote%%/*}"
hote="${hote%%:*}"
case "$hote" in
  127.0.0.1|localhost|10.0.2.2|*.local)
    refus "SUPABASE_URL désigne une machine locale ($hote)." ;;
esac
[[ -n "$cle" ]] || refus "SUPABASE_ANON_KEY n'est pas défini."
# La clé de service ouvre tout, RLS comprise : elle n'entre jamais dans l'app.
if [[ "$cle" == sb_secret_* ]] || echo "$cle" | cut -d. -f2 | base64 -d 2>/dev/null | grep -q '"service_role"'; then
  refus "SUPABASE_ANON_KEY est une clé de service : elle ne doit jamais être embarquée dans l'app."
fi

if [[ "$cible" == "appbundle" || "$cible" == "apk" ]]; then
  [[ -f android/key.properties ]] || refus "android/key.properties est introuvable (voir android/key.properties.example)."
fi

exec flutter build "$cible" --release \
  --dart-define=SUPABASE_URL="$url" \
  --dart-define=SUPABASE_ANON_KEY="$cle" \
  "$@"
