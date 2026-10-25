#!/usr/bin/env bash
# Vérifie la migration 0128 par la vraie API de la pile locale : GoTrue,
# PostgREST et la fonction edge `create-collaborator`, avec la seule clé
# anonyme côté attaquant — exactement ce dont disposait l'audit.
#
#   bash supabase/snippets/verif_0128_api.sh
#
# Crée des comptes préfixés `verif128-` et les supprime à la fin, même en
# cas d'échec. Ne touche à aucun autre compte. Les sessions portent le
# User-Agent `mtc-tests`, comme celles des tests.
#
# Dernière ligne attendue : « TOUTES LES VÉRIFICATIONS PASSENT ».
set -euo pipefail

cd "$(dirname "$0")/../.."
eval "$(supabase status -o env 2>/dev/null | grep -E '^(ANON_KEY|API_URL)=')"
DB=(docker exec -i supabase_db_MTC_project psql -U postgres -d postgres -Atq)
UA="User-Agent: mtc-tests"
BOGOLAN=b7eb8585-4091-5b6f-83f7-5d70724e97a3
REPONSE=$(mktemp)

nettoyer() {
  "${DB[@]}" -c "
    delete from public.suppliers where id in (select id from auth.users where email like 'verif128-%@mtc.local');
    delete from auth.users where email like 'verif128-%@mtc.local';" >/dev/null
  rm -f "$REPONSE"
}
trap nettoyer EXIT
nettoyer

echec() { echo "ÉCHEC : $*" >&2; exit 1; }

inscrire() { # $1 = corps JSON
  curl -s -o "$REPONSE" -w '%{http_code}' -X POST "$API_URL/auth/v1/signup" \
    -H "apikey: $ANON_KEY" -H "Content-Type: application/json" -H "$UA" -d "$1"
}
jeton() { # $1 = identifiant, $2 = mot de passe
  curl -s -X POST "$API_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $ANON_KEY" -H "Content-Type: application/json" -H "$UA" \
    -d "{\"email\":\"$1@mtc.local\",\"password\":\"$2\"}" | sed -nE 's/.*"access_token":"([^"]+)".*/\1/p'
}
rpc() { # $1 = jeton, $2 = fonction, $3 = corps
  local corps=${3:-'{}'}
  curl -s -X POST "$API_URL/rest/v1/rpc/$2" -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $1" -H "Content-Type: application/json" -H "$UA" -d "$corps"
}
compte() { # $1 = jeton, $2 = table — le nombre de lignes visibles
  curl -s -o /dev/null -D - "$API_URL/rest/v1/$2?select=*" -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $1" -H "$UA" -H "Prefer: count=exact" \
    | tr -d '\r' | sed -nE 's/^[Cc]ontent-[Rr]ange: .*\/([0-9*]+)$/\1/p'
}
profil() { "${DB[@]}" -c "select coalesce(string_agg(role || '/' || coalesce(staff_role::text, '-'), ','), 'aucun') from public.profiles where username_or_phone = '$1';"; }

# ---- 1. l'inscription publique ne fait plus d'administrateur -------------------
code=$(inscrire '{"email":"verif128-admin@mtc.local","password":"password123","data":{"role":"supplier_principal","staff_role":"admin","username_or_phone":"verif128-admin","display_name":"Faux admin","phone_number":"+22370001111"}}')
[[ "$code" != 200 ]] || echec "inscription en admin acceptée"
[[ "$(profil verif128-admin)" == aucun ]] || echec "un profil reste après l'inscription refusée"
echo "1. admin par l'inscription publique : refusé ($code)"

# ---- 2. ni de collaborateur d'une boutique choisie ----------------------------------
code=$(inscrire "{\"email\":\"verif128-intrus@mtc.local\",\"password\":\"password123\",\"data\":{\"role\":\"supplier_tiers\",\"collaborator_of\":\"$BOGOLAN\",\"permissions\":[\"products\",\"orders\",\"storefront\",\"messages\"],\"username_or_phone\":\"verif128-intrus\",\"display_name\":\"Intrus\",\"phone_number\":\"+22370001112\",\"business_name\":\"X\",\"city\":\"Bamako\",\"legal_type\":\"company\"}}")
[[ "$code" != 200 ]] || echec "inscription en collaborateur de Bogolan acceptée"
[[ "$(profil verif128-intrus)" == aucun ]] || echec "un profil reste après l'inscription refusée"
echo "2. collaborateur par l'inscription publique : refusé ($code)"

# ---- 3. un client ne se donne pas de rôle après coup --------------------------------
code=$(inscrire '{"email":"verif128-client@mtc.local","password":"password123","data":{"role":"client","username_or_phone":"verif128-client","display_name":"Client","phone_number":"+22370001113"}}')
[[ "$code" == 200 ]] || echec "inscription d'un client refusée ($code) : $(cat "$REPONSE")"
CLIENT=$(jeton verif128-client password123)
code=$(curl -s -o "$REPONSE" -w '%{http_code}' -X PUT "$API_URL/auth/v1/user" -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $CLIENT" -H "Content-Type: application/json" -H "$UA" -d '{"app_metadata":{"staff_role":"admin"}}')
[[ "$code" == 403 ]] || echec "un client a pu écrire son app_metadata ($code)"
curl -s -o /dev/null -X PUT "$API_URL/auth/v1/user" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $CLIENT" \
  -H "Content-Type: application/json" -H "$UA" -d "{\"data\":{\"staff_role\":\"admin\",\"collaborator_of\":\"$BOGOLAN\"}}"
CLIENT=$(jeton verif128-client password123)
[[ "$(profil verif128-client)" == client/- ]] || echec "le profil du client a changé : $(profil verif128-client)"
[[ "$(rpc "$CLIENT" is_staff)" == false ]] || echec "le client passe pour du staff"
[[ "$(rpc "$CLIENT" operating_supplier_id)" == null ]] || echec "le client opère une boutique"
echo "3. client : app_metadata refusé (403), user_metadata sans effet"

# ---- 4. le vrai staff passe toujours -----------------------------------------------------
ADMIN=$(jeton admin1 password123)
[[ -n "$ADMIN" ]] || echec "admin1 ne se connecte pas (mot de passe de démonstration changé ?)"
[[ "$(rpc "$ADMIN" is_admin)" == true ]] || echec "admin1 n'est plus admin"
n=$(compte "$ADMIN" orders); [[ "$n" -gt 0 ]] || echec "admin1 ne voit plus les commandes"
echo "4. admin1 : admin, voit $n commandes"

# ---- 5. un patron recrute par la fonction edge -----------------------------------------
code=$(inscrire '{"email":"verif128-patron@mtc.local","password":"password123","data":{"role":"supplier_tiers","username_or_phone":"verif128-patron","display_name":"Patron","phone_number":"+22370001114","business_name":"Boutique Vérif","city":"Bamako","legal_type":"individual"}}')
[[ "$code" == 200 ]] || echec "inscription du patron refusée ($code)"
PATRON=$(jeton verif128-patron password123)
BOUTIQUE=$(rpc "$PATRON" operating_supplier_id | tr -d '"')
reponse=$(curl -s -X POST "$API_URL/functions/v1/create-collaborator" -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $PATRON" -H "Content-Type: application/json" -H "$UA" \
  -d '{"displayName":"Vendeuse","usernameOrPhone":"verif128-vendeuse","phoneNumber":"+22370001115","permissions":["products","orders","inventée"]}')
MDP=$(echo "$reponse" | sed -nE 's/.*"temporary_password":"([^"]+)".*/\1/p')
[[ -n "$MDP" ]] || echec "la fonction edge n'a pas créé le collaborateur : $reponse"
ligne=$("${DB[@]}" -c "select c.supplier_id || '|' || array_to_string(c.permissions, ',') || '|' || p.role || '|' || p.must_change_password || '|' || (c.created_by = c.supplier_id)
  from public.supplier_collaborators c join public.profiles p on p.id = c.user_id where p.username_or_phone = 'verif128-vendeuse';")
[[ "$ligne" == "$BOUTIQUE|orders,products|supplier_tiers|true|true" ]] || echec "rattachement inattendu : $ligne"
VENDEUSE=$(jeton verif128-vendeuse "$MDP")
[[ "$(rpc "$VENDEUSE" operating_supplier_id | tr -d '"')" == "$BOUTIQUE" ]] || echec "la vendeuse n'opère pas la boutique du patron"
echo "5. create-collaborator : vendeuse rattachée, droits filtrés (orders,products)"

# ---- 6. et ne rattache pas le client d'un autre ----------------------------------------
CLIENT_ID=$("${DB[@]}" -c "select id from public.profiles where username_or_phone = 'verif128-client';")
refus=$(rpc "$PATRON" add_supplier_collaborator "{\"p_user_id\":\"$CLIENT_ID\",\"p_permissions\":[\"products\"]}")
[[ "$refus" == *"pas été créé pour votre boutique"* ]] || echec "le patron a rattaché un client : $refus"
echo "6. add_supplier_collaborator sur un client : refusé"

echo "TOUTES LES VÉRIFICATIONS PASSENT"
