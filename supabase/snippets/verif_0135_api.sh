#!/usr/bin/env bash
# Vérifie la double authentification du staff (`0135`) par la vraie API de
# la pile locale : un compte staff créé par `creer_compte_staff.sh`, une
# session au seul mot de passe qui ne voit rien, un enrôlement TOTP, un code
# calculé ici comme le ferait l'application d'authentification, puis une
# session `aal2` qui retrouve les droits du staff.
#
#   bash supabase/snippets/verif_0135_api.sh
#
# Demande la TOTP activée dans GoTrue (`[auth.mfa.totp]` de `config.toml`,
# puis `supabase stop && supabase start`). Rallume l'exigence le temps de
# l'essai et remet le réglage d'avant à la fin, même en cas d'échec. Le
# compte `verif135-admin` est supprimé à la fin.
#
# Dernière ligne attendue : « TOUTES LES VÉRIFICATIONS PASSENT ».
set -euo pipefail

cd "$(dirname "$0")/../.."
eval "$(supabase status -o env 2>/dev/null | grep -E '^(ANON_KEY|API_URL|SERVICE_ROLE_KEY)=')"
DB=(docker exec -i supabase_db_MTC_project psql -U postgres -d postgres -Atq)
UA="User-Agent: mtc-tests"

reglage_avant=$("${DB[@]}" -c "select coalesce((select value::text from public.app_settings where key = 'staff_mfa_required'), 'absent');")
nettoyer() {
  "${DB[@]}" -c "delete from auth.users where email = 'verif135-admin@mtc.local';" >/dev/null
  if [[ "$reglage_avant" == absent ]]; then
    "${DB[@]}" -c "delete from public.app_settings where key = 'staff_mfa_required';" >/dev/null
  else
    "${DB[@]}" -c "update public.app_settings set value = '$reglage_avant'::jsonb where key = 'staff_mfa_required';" >/dev/null
  fi
}
trap nettoyer EXIT
"${DB[@]}" -c "delete from auth.users where email = 'verif135-admin@mtc.local';" >/dev/null

echec() { echo "ÉCHEC : $*" >&2; exit 1; }
champ() { sed -nE "s/.*\"$1\":\"([^\"]+)\".*/\1/p"; }
rpc() { curl -s -X POST "$API_URL/rest/v1/rpc/$2" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $1" \
  -H "Content-Type: application/json" -H "$UA" -d '{}'; }
nb_commandes() { curl -s -o /dev/null -D - "$API_URL/rest/v1/orders?select=id" -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $1" -H "$UA" -H "Prefer: count=exact" | tr -d '\r' | sed -nE 's/^[Cc]ontent-[Rr]ange: .*\/([0-9]+)$/\1/p'; }

# Le code TOTP du moment (RFC 6238 : HMAC-SHA1, 30 s, 6 chiffres), calculé
# depuis la clé comme une application d'authentification le fait.
code_totp() {
  perl -MDigest::SHA=hmac_sha1 -e '
    my %v; @v{("A".."Z","2".."7")} = (0..31);
    my $bits = join "", map { sprintf "%05b", $v{$_} } grep { exists $v{$_} } split //, uc shift;
    my $cle = pack "B*", substr($bits, 0, int(length($bits) / 8) * 8);
    my $h = hmac_sha1(pack("NN", 0, int(time() / 30)), $cle);
    my $o = ord(substr($h, -1)) & 0x0f;
    printf "%06d\n", (unpack("N", substr($h, $o, 4)) & 0x7fffffff) % 1000000;
  ' "$1"
}

# ---- 1. un compte staff, créé par le script de production --------------------------
sortie=$(SUPABASE_URL="$API_URL" SERVICE_ROLE_KEY="$SERVICE_ROLE_KEY" \
  supabase/production/creer_compte_staff.sh verif135-admin "Admin vérif" "+22378009135" admin)
MDP=$(echo "$sortie" | sed -nE 's/^    ([A-Za-z0-9]{20})$/\1/p')
[[ ${#MDP} -eq 20 ]] || echec "le script n'a pas rendu de mot de passe : $sortie"
[[ "$("${DB[@]}" -c "select role || '/' || staff_role from public.profiles where username_or_phone = 'verif135-admin';")" == supplier_principal/admin ]] \
  || echec "le script n'a pas fait un administrateur"
echo "1. creer_compte_staff.sh : administrateur créé, mot de passe de 20 caractères"

"${DB[@]}" -c "insert into public.app_settings (key, value) values ('staff_mfa_required', 'true') on conflict (key) do update set value = 'true';" >/dev/null

# ---- 2. le mot de passe seul n'ouvre rien ------------------------------------------------
jeton() {
  curl -s -X POST "$API_URL/auth/v1/token?grant_type=password" -H "apikey: $ANON_KEY" \
    -H "Content-Type: application/json" -H "$UA" \
    -d "{\"email\":\"verif135-admin@mtc.local\",\"password\":\"$MDP\"}" | champ access_token
}
AAL1=$(jeton)
[[ -n "$AAL1" ]] || echec "connexion par mot de passe impossible"
[[ "$(rpc "$AAL1" is_admin)" == false ]] || echec "une session aal1 est admin"
[[ "$(nb_commandes "$AAL1")" == 0 ]] || echec "une session aal1 voit les commandes"
[[ "$(rpc "$AAL1" staff_mfa_required)" == true ]] || echec "l'app ne peut pas savoir qu'un code est exigé"
echo "2. mot de passe seul : ni admin, ni commandes"

# ---- 3. enrôlement, puis le code de l'application ----------------------------------------
enrolement=$(curl -s -X POST "$API_URL/auth/v1/factors" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $AAL1" \
  -H "Content-Type: application/json" -H "$UA" -d '{"factor_type":"totp","issuer":"MTC","friendly_name":"verif"}')
FACTEUR=$(echo "$enrolement" | sed -nE 's/^\{"id":"([^"]+)".*/\1/p')
CLE=$(echo "$enrolement" | champ secret)
[[ -n "$FACTEUR" && -n "$CLE" ]] || echec "enrôlement TOTP refusé : $enrolement"

# Un code faux ne passe pas.
DEFI=$(curl -s -X POST "$API_URL/auth/v1/factors/$FACTEUR/challenge" -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $AAL1" -H "$UA" | champ id)
faux=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API_URL/auth/v1/factors/$FACTEUR/verify" -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $AAL1" -H "Content-Type: application/json" -H "$UA" \
  -d "{\"challenge_id\":\"$DEFI\",\"code\":\"000000\"}")
[[ "$faux" != 200 ]] || echec "un code faux a été accepté"

DEFI=$(curl -s -X POST "$API_URL/auth/v1/factors/$FACTEUR/challenge" -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $AAL1" -H "$UA" | champ id)
verification=$(curl -s -X POST "$API_URL/auth/v1/factors/$FACTEUR/verify" -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $AAL1" -H "Content-Type: application/json" -H "$UA" \
  -d "{\"challenge_id\":\"$DEFI\",\"code\":\"$(code_totp "$CLE")\"}")
AAL2=$(echo "$verification" | champ access_token)
[[ -n "$AAL2" ]] || echec "le bon code a été refusé : $verification"
echo "3. TOTP : code faux refusé ($faux), bon code accepté"

# ---- 4. la session confirmée retrouve les droits du staff ---------------------------------
[[ "$(rpc "$AAL2" is_admin)" == true ]] || echec "la session aal2 n'est pas admin"
n=$(nb_commandes "$AAL2"); [[ "$n" -gt 0 ]] || echec "la session aal2 ne voit pas les commandes"
echo "4. session aal2 : admin, voit $n commandes"

# ---- 5. et la connexion suivante redemande le code ----------------------------------------
AAL1=$(jeton)
[[ "$(rpc "$AAL1" is_admin)" == false ]] || echec "une nouvelle connexion au mot de passe est admin sans code"
echo "5. nouvelle connexion : le code est redemandé"

echo "TOUTES LES VÉRIFICATIONS PASSENT"
