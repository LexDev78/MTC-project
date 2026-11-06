#!/usr/bin/env bash
# La course que `0153` ferme : l'annulation automatique d'une commande, et sa
# confirmation par la boutique au même moment. Deux sessions, ce qu'une
# vérification en une seule transaction ne peut pas montrer.
#
#   tool/pile_de_verification.sh demarrer
#   supabase/snippets/verif_0153_course.sh
#
# Contre la pile de vérification SEULEMENT : le script enregistre une vraie
# commande (Moussa, un boubou chez Bogolan) et la vieillit de 25 h.
#
# Avant `0153`, la confirmation attendait la fin de l'annulation puis
# s'appliquait sur la commande annulée : « confirmée », stock déjà rendu
# (`0152`), le client prévenu des deux. Attendu désormais : la confirmation
# est refusée, la commande reste annulée, et son article est rendu une fois.
set -euo pipefail

conteneur=supabase_db_mtc_verif
if ! docker ps --format '{{.Names}}' | grep -qx "$conteneur"; then
  echo "La pile de vérification ne tourne pas ($conteneur) : rien n'est lancé." >&2
  exit 2
fi

P="docker exec -i $conteneur psql -U postgres -d postgres -At -v ON_ERROR_STOP=1"
MOUSSA=3355adef-385d-5eee-a565-815c8cf8e4d3
BOGOLAN=b7eb8585-4091-5b6f-83f7-5d70724e97a3
BOUBOU=62599202-a3f0-5adc-ae1c-fe2a691adf92
claims() {
  echo "select set_config('request.jwt.claims', json_build_object('sub','$1','role','authenticated','aal','aal1','app_metadata',(select raw_app_meta_data from auth.users where id='$1'))::text, true);"
}

VAR=$($P -c "select id from public.product_variants where product_id='$BOUBOU' and is_default")
CMD=$($P <<SQL | grep -E '^[0-9a-f-]{36}$' | head -1
begin;
$(claims $MOUSSA)
set local role authenticated;
select public.place_order('x','+22370000002', jsonb_build_array(jsonb_build_object('supplier_id','$BOGOLAN','delivery_mode','self_delivery','items', jsonb_build_array(jsonb_build_object('product_id','$BOUBOU','variant_id','$VAR','quantity',1)))), 'Maison','Bamako','Rue 1',12.6,-8.0);
commit;
SQL
)
GRP=$($P -c "select id from public.order_supplier_groups where order_id='$CMD'")
$P -c "update public.orders set placed_at = now() - interval '25 hours' where id='$CMD'" >/dev/null
avant=$($P -c "select stock_quantity from public.product_variants where id='$VAR'")

# A : l'annulation automatique, qui garde sa transaction ouverte 4 s.
$P -c "begin; select public.cancel_unconfirmed_orders(); select pg_sleep(4); commit;" >/dev/null 2>&1 &
sleep 1.5
# B : la boutique confirme pendant ce temps.
refus=$($P 2>&1 <<SQL || true
begin;
$(claims $BOGOLAN)
set local role authenticated;
select public.update_order_group_status('$CMD', '$GRP', 'confirmed');
commit;
SQL
)
wait

etat=$($P -c "select g.status || '/' || o.status from public.order_supplier_groups g join public.orders o on o.id = g.order_id where g.id='$GRP'")
apres=$($P -c "select stock_quantity from public.product_variants where id='$VAR'")
echo "commande : $etat, stock $avant → $apres"
echo "$refus" | grep -m1 ERROR || true

if [ "$etat" != "cancelled/cancelled" ] || [ "$apres" -ne $((avant + 1)) ] \
   || ! echo "$refus" | grep -q "annulée entre-temps"; then
  echo "ÉCHEC : la confirmation a ressuscité la commande annulée" >&2
  exit 1
fi
echo "VÉRIFICATION PASSE"
