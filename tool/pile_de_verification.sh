#!/usr/bin/env bash
# Une seconde pile Supabase locale, montée de zéro, pour lancer la suite
# d'intégration sans vider celle où l'on essaie l'app à la main.
#
#   tool/pile_de_verification.sh demarrer   # rejoue toutes les migrations et les seeds
#   tool/pile_de_verification.sh tester     # la suite d'intégration, contre elle
#   tool/pile_de_verification.sh arreter    # l'arrête et efface ses volumes
#
# Pourquoi : la suite réinitialise sa base à chaque test (`test_reset_and_seed`
# vide `auth.users`) et refuse de tourner quand un vrai service d'e-mail est
# branché (`0126`). Sur la pile de développement, c'est perdre ce qu'on y a
# fait à la main ; ici, il n'y a rien à perdre. Et `demarrer` vérifie au
# passage que la chaîne des migrations s'applique depuis une base vide.
#
# La pile s'appelle `mtc_verif` et répond sur les ports 55xxx (API 55321,
# Mailpit 55324). Sans Studio ni fonctions edge : aucun test d'intégration
# ne les appelle.
set -euo pipefail

depot="$(cd "$(dirname "$0")/.." && pwd)"
dossier="${TMPDIR:-/tmp}/mtc-pile-de-verification"
api=http://127.0.0.1:55321
mailpit=http://127.0.0.1:55324

demarrer() {
  rm -rf "$dossier"
  mkdir -p "$dossier/supabase"
  cp -R "$depot/supabase/config.toml" "$depot/supabase/seed.sql" \
    "$depot/supabase/migrations" "$depot/supabase/seeds" "$dossier/supabase/"
  perl -0pi -e '
    s/^project_id = "MTC_project"/project_id = "mtc_verif"/m;
    s/^port = 54321$/port = 55321/m;  s/^port = 54322$/port = 55322/m;
    s/^shadow_port = 54320$/shadow_port = 55320/m;  s/^port = 54329$/port = 55329/m;
    s/^port = 54323$/port = 55323/m;  s/^port = 54324$/port = 55324/m;
    s/^inspector_port = 8083$/inspector_port = 8183/m;  s/^port = 54327$/port = 55327/m;
    s/(\[studio\]\n(?:#.*\n)*)enabled = true/$1enabled = false/;
    s/(\[edge_runtime\]\n(?:#.*\n)*)enabled = true/$1enabled = false/;
    s/(\[analytics\]\n(?:#.*\n)*)enabled = true/$1enabled = false/;
  ' "$dossier/supabase/config.toml"

  supabase start --workdir "$dossier"

  # Les e-mails vers le Mailpit de cette pile — l'adresse par défaut est
  # celui de la pile de développement, que ce réseau Docker ne joint pas.
  # Et les notifications push nulle part : la fonction par défaut est celle
  # de la pile de développement.
  docker exec -i supabase_db_mtc_verif psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q <<'SQL'
select vault.create_secret('http://supabase_inbucket_mtc_verif:8025/api/v1/send', 'mail_api_url');
select vault.create_secret('http://127.0.0.1:9/nulle-part', 'push_function_url');
SQL
  echo "Pile de vérification prête : $api"
}

tester() {
  cd "$depot"
  flutter test --tags integration \
    --dart-define=MTC_TEST_SUPABASE_URL="$api" \
    --dart-define=MTC_TEST_MAILPIT_URL="$mailpit" "$@"
}

arreter() {
  supabase stop --no-backup --workdir "$dossier"
  # `stop --no-backup` peut laisser un volume derrière lui ; le disque est
  # compté sur cette machine.
  for volume in $(docker volume ls -q --filter name=_mtc_verif); do
    docker volume rm "$volume" >/dev/null
  done
  rm -rf "$dossier"
}

case "${1:-}" in
  demarrer) demarrer ;;
  tester) shift; tester "$@" ;;
  arreter) arreter ;;
  *) echo "Usage : $0 demarrer | tester [fichiers…] | arreter" >&2; exit 64 ;;
esac
