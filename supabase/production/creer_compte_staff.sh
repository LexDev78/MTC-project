#!/usr/bin/env bash
# Créer un compte du staff MTC — le seul chemin pour en créer un.
#
#   SUPABASE_URL=https://<projet>.supabase.co \
#   SERVICE_ROLE_KEY=<clé de service, jamais dans l'app> \
#   supabase/production/creer_compte_staff.sh <identifiant> "<Nom affiché>" <téléphone> <agent|admin>
#
# Depuis `0128`, l'inscription publique refuse tout rôle de staff : le rôle
# vient de `app_metadata.staff_role`, que seule la clé de service écrit. Ce
# script passe par l'API d'administration de Supabase Auth, qui hache le mot
# de passe et crée l'identité comme pour n'importe quel compte.
#
# Le mot de passe est engendré ici (20 caractères), affiché une fois, et
# n'est stocké nulle part. À la première connexion, la personne relie son
# compte à une application d'authentification (`0135`) : sans ce code, le
# compte ne voit rien de ce que voit le staff.
#
# En local : SUPABASE_URL=http://127.0.0.1:54321 et la clé de service de
# `supabase status`.
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "Usage : $0 <identifiant> \"<Nom affiché>\" <téléphone> <agent|admin>" >&2
  exit 64
fi
identifiant="$1"
nom="$2"
telephone="$3"
role="$4"

[[ -n "${SUPABASE_URL:-}" ]] || { echo "SUPABASE_URL n'est pas défini." >&2; exit 1; }
[[ -n "${SERVICE_ROLE_KEY:-}" ]] || { echo "SERVICE_ROLE_KEY n'est pas défini." >&2; exit 1; }
[[ "$role" == agent || "$role" == admin ]] || { echo "Rôle inconnu : $role (agent ou admin)." >&2; exit 1; }
[[ "$identifiant" =~ ^[a-z0-9._-]{3,}$ ]] || { echo "Identifiant invalide : minuscules, chiffres, . _ -, 3 caractères au moins." >&2; exit 1; }

# 20 caractères sans 0/O ni 1/l/I : il se recopie sans hésitation. Tiré de
# 400 octets aléatoires lus d'un coup — pas de `tr </dev/urandom | head`,
# que `pipefail` interromprait par un SIGPIPE.
alea=$(head -c 400 /dev/urandom | LC_ALL=C tr -dc 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789')
mot_de_passe=${alea:0:20}
[[ ${#mot_de_passe} -eq 20 ]] || { echo "Tirage du mot de passe trop court, relancez." >&2; exit 1; }

# Même convention que l'app (`pseudo_email.dart`) : Supabase Auth veut une
# adresse, l'app ne connaît que des identifiants.
corps=$(cat <<EOF
{
  "email": "${identifiant}@mtc.local",
  "password": "${mot_de_passe}",
  "email_confirm": true,
  "user_metadata": {
    "username_or_phone": "${identifiant}",
    "display_name": "${nom}",
    "phone_number": "${telephone}"
  },
  "app_metadata": { "staff_role": "${role}" }
}
EOF
)

reponse=$(curl -sS -w '\n%{http_code}' -X POST "${SUPABASE_URL}/auth/v1/admin/users" \
  -H "apikey: ${SERVICE_ROLE_KEY}" -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" -d "$corps")
code=$(echo "$reponse" | tail -n1)
if [[ "$code" != 200 ]]; then
  echo "Création refusée ($code) : $(echo "$reponse" | sed '$d')" >&2
  exit 1
fi

cat <<EOF
Compte staff créé : ${identifiant} (${role}).
Mot de passe à remettre en main propre, affiché une seule fois :

    ${mot_de_passe}

À la première connexion, l'app demandera de relier le compte à une
application d'authentification (Google Authenticator, Aegis…).
EOF
