-- Vérifie la migration 0131 (un retrait ne porte que sur l'argent que MTC a
-- reçu) contre la base locale, sans rien y laisser : tout se passe dans une
-- transaction annulée.
--
--   docker exec -i supabase_db_MTC_project psql -U postgres -d postgres -q \
--     < supabase/snippets/verif_0131.sql
--
-- Dernière ligne attendue : « TOUTES LES VÉRIFICATIONS PASSENT ».
\set ON_ERROR_STOP 1
\o /dev/null
begin;
set local client_min_messages = warning;

create schema verif;
grant usage on schema verif to anon, authenticated;

create function verif.refuse(p_cas text, p_sql text, p_motif text)
returns void language plpgsql as $$
declare
  v_message text;
begin
  begin
    execute p_sql;
  exception when others then
    v_message := sqlerrm;
  end;
  if v_message is null then
    raise exception 'ÉCHEC % : accepté alors qu''il devait être refusé', p_cas;
  end if;
  if v_message not like p_motif then
    raise exception 'ÉCHEC % : refusé, mais pour une autre raison : %', p_cas, v_message;
  end if;
end $$;

create function verif.inscrire(p_id uuid, p_user jsonb)
returns void language sql as $$
  insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token, email_change, email_change_token_new)
  values ('00000000-0000-0000-0000-000000000000', p_id, 'authenticated', 'authenticated',
    (p_user ->> 'username_or_phone') || '@mtc.local', '', now(), now(), now(),
    '{"provider":"email","providers":["email"]}', p_user, '', '', '', '');
$$;

-- Une vente livrée, telle que la base la garde, sans passer par l'écran.
create function verif.vente(p_boutique uuid, p_montant integer, p_methode text, p_paiement text,
                            p_mode text, p_statut text default 'delivered', p_course text default null)
returns void language plpgsql as $$
declare
  v_commande text := gen_random_uuid()::text;
  v_groupe text := gen_random_uuid()::text;
begin
  insert into public.orders (id, client_id, client_display_name_snapshot, status, total_fcfa,
                             delivery_city, payment_method, payment_status)
  values (v_commande, '3355adef-385d-5eee-a565-815c8cf8e4d3', 'Moussa', p_statut::public.order_status,
          p_montant, 'Bamako', p_methode::public.payment_method, p_paiement::public.payment_status);
  insert into public.order_supplier_groups (id, order_id, supplier_id, supplier_name, delivery_mode,
                                            delivery_fee_fcfa, subtotal_fcfa, status)
  values (v_groupe, v_commande, p_boutique, 'Boutique vérif', p_mode::public.delivery_mode, 0,
          p_montant, p_statut::public.order_status);
  if p_course is not null then
    insert into public.deliveries (order_id, supplier_group_id, status, courier_id, delivered_at)
    values (v_commande, v_groupe, p_course::public.delivery_status,
            'f1c4e8a2-0000-5000-9000-000000000001', now());
  end if;
end $$;

create function verif.jeton(p_id uuid) returns text language sql as $$
  select jsonb_build_object('sub', p_id, 'role', 'authenticated',
    'app_metadata', (select raw_app_meta_data from auth.users where id = p_id))::text;
$$;
grant execute on all functions in schema verif to anon, authenticated;

-- ---- 1. qui tient l'argent -------------------------------------------------------------------
\set boutique 'c0000000-0000-4000-8000-000000000001'
select verif.inscrire(:'boutique', '{"role":"supplier_tiers","username_or_phone":"v-ledger","display_name":"Patron","phone_number":"+22370000050","business_name":"Boutique vérif","city":"Bamako","legal_type":"individual"}');
select verif.vente(:'boutique', 10000, 'now', 'paid', 'self_delivery');                          -- Orange Money reçu : MTC
select verif.vente(:'boutique', 20000, 'on_delivery', 'pending_on_delivery', 'mtc_delivery', 'delivered', 'delivered'); -- espèces au livreur MTC : MTC
select verif.vente(:'boutique', 30000, 'on_delivery', 'pending_on_delivery', 'self_delivery');  -- espèces à la boutique : la boutique
select verif.vente(:'boutique', 40000, 'now', 'pending_on_delivery', 'self_delivery');          -- en ligne, non confirmé : personne
select verif.vente(:'boutique', 50000, 'on_delivery', 'pending_on_delivery', 'self_delivery', 'cancelled'); -- annulée : rien
select verif.vente(:'boutique', 60000, 'on_delivery', 'pending_on_delivery', 'self_delivery', 'in_transit'); -- pas encore livrée : rien
select verif.vente(:'boutique', 70000, 'on_delivery', 'pending_on_delivery', 'mtc_delivery');   -- MTC sans course livrée : personne
insert into public.payout_requests (id, supplier_id, amount_fcfa, status, method, payout_destination)
values ('verif-verse', :'boutique', 5000, 'paid', 'orange_money', '+22370000050'),
       ('verif-refuse', :'boutique', 7000, 'rejected', 'orange_money', '+22370000050');
do $$
declare
  v jsonb := public.supplier_ledger('c0000000-0000-4000-8000-000000000001');
  v_attendu jsonb := '{"gross_fcfa": 170000, "collected_by_mtc_fcfa": 30000, "collected_by_supplier_fcfa": 30000,
    "awaiting_payment_fcfa": 110000, "commission_rate_percent": 10, "commission_on_mtc_fcfa": 3000,
    "commission_owed_fcfa": 3000, "commission_fcfa": 6000, "net_fcfa": 24000, "paid_out_fcfa": 5000,
    "available_fcfa": 19000}';
begin
  if v is distinct from v_attendu then
    raise exception 'ÉCHEC : grand livre % au lieu de %', v, v_attendu;
  end if;
end $$;

-- ---- 2. la garde des retraits ------------------------------------------------------------------
select verif.jeton(:'boutique') as patron \gset
select set_config('verif.patron', :'patron', true);
set local role authenticated;
select set_config('request.jwt.claims', current_setting('verif.patron'), true);
do $$ begin
  perform verif.refuse('retirer un franc de trop', $q$insert into public.payout_requests (id, supplier_id, amount_fcfa, status, method, payout_destination)
    values ('verif-trop', 'c0000000-0000-4000-8000-000000000001', 19001, 'requested', 'orange_money', '+22370000050')$q$,
    'Montant demandé (19001 FCFA) supérieur au solde disponible (19000 FCFA).');
  perform verif.refuse('sans numéro', $q$insert into public.payout_requests (id, supplier_id, amount_fcfa, status, method, payout_destination)
    values ('verif-vide', 'c0000000-0000-4000-8000-000000000001', 1000, 'requested', 'orange_money', '  ')$q$,
    'Indiquez le numéro qui recevra le versement.');
  -- Une demande qui se dit déjà payée, datée d'un an, avec un motif : elle
  -- naît demandée, maintenant, sans décision.
  insert into public.payout_requests (id, supplier_id, amount_fcfa, status, requested_at, method,
                                      payout_destination, processed_at, rejection_reason)
  values ('verif-deja-payee', 'c0000000-0000-4000-8000-000000000001', 19000, 'paid',
          now() - interval '1 year', 'orange_money', '+22370000050', now() - interval '1 year', 'rien');
end $$;
reset role;
do $$ begin
  if (select (status, requested_at = now(), processed_at, rejection_reason)::text
        from public.payout_requests where id = 'verif-deja-payee') <> '(requested,t,,)' then
    raise exception 'ÉCHEC : la demande a gardé ce qu''elle disait d''elle-même (%)',
      (select (status, requested_at, processed_at, rejection_reason)::text from public.payout_requests where id = 'verif-deja-payee');
  end if;
  if (public.supplier_ledger('c0000000-0000-4000-8000-000000000001') ->> 'available_fcfa')::int <> 0 then
    raise exception 'ÉCHEC : la demande n''a pas réservé son montant';
  end if;
end $$;

-- ---- 3. la fraude de l'audit : un faux client, une fausse commande, « livrée » -----------------------
-- Moussa joue le faux client de Bogolan Bamako. La boutique livre « elle-même »
-- et passe la commande à livrée d'un geste : avant 0131, son solde montait
-- de 90 % du prix.
select (public.supplier_ledger('b7eb8585-4091-5b6f-83f7-5d70724e97a3') ->> 'available_fcfa') as avant \gset
select set_config('verif.avant', :'avant', true);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"3355adef-385d-5eee-a565-815c8cf8e4d3","role":"authenticated","app_metadata":{}}', true);
select public.place_order('Moussa', '+22370000002',
  '[{"supplier_id":"b7eb8585-4091-5b6f-83f7-5d70724e97a3","delivery_mode":"self_delivery","items":[
     {"product_id":"62599202-a3f0-5adc-ae1c-fe2a691adf92","variant_id":"bf018c0c-bc89-4a35-be63-fefee9faeceb","quantity":1}]}]',
  'Maison', 'Bamako', 'Rue 1', 12.6, -8.0) as fausse \gset
select set_config('verif.fausse', :'fausse', true);
select set_config('request.jwt.claims', '{"sub":"b7eb8585-4091-5b6f-83f7-5d70724e97a3","role":"authenticated","app_metadata":{}}', true);
do $$
declare
  v_groupe text := (select id from public.order_supplier_groups where order_id = current_setting('verif.fausse'));
  v_statut text;
  v_prix integer := (select subtotal_fcfa from public.order_supplier_groups where order_id = current_setting('verif.fausse'));
  v_apres integer;
begin
  foreach v_statut in array array['confirmed', 'preparing', 'in_transit', 'delivered'] loop
    perform public.update_order_group_status(current_setting('verif.fausse'), v_groupe, v_statut);
  end loop;
  v_apres := (public.fetch_my_finance_summary() ->> 'available_fcfa')::integer;
  if v_apres <> current_setting('verif.avant')::integer - round(v_prix * 0.10) then
    raise exception 'ÉCHEC : la fausse vente a rapporté au lieu de coûter sa commission (avant %, après %, prix %)',
      current_setting('verif.avant'), v_apres, v_prix;
  end if;
  perform verif.refuse('se faire payer la fausse vente', format($q$insert into public.payout_requests (id, supplier_id, amount_fcfa, status, method, payout_destination)
    values ('verif-fraude', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3', %s, 'requested', 'orange_money', '+22370000099')$q$, v_apres + round(v_prix * 0.9)),
    'Montant demandé%supérieur au solde disponible%');
end $$;

-- Une boutique qui n'a encaissé qu'elle-même doit sa commission : aucun
-- retrait, si petit soit-il.
reset role;
\set seule 'c0000000-0000-4000-8000-000000000002'
select verif.inscrire(:'seule', '{"role":"supplier_tiers","username_or_phone":"v-seule","display_name":"Patronne","phone_number":"+22370000051","business_name":"Boutique seule","city":"Bamako","legal_type":"individual"}');
select verif.vente(:'seule', 100000, 'on_delivery', 'pending_on_delivery', 'self_delivery');
select verif.jeton(:'seule') as seule_jeton \gset
select set_config('verif.seule', :'seule_jeton', true);
set local role authenticated;
select set_config('request.jwt.claims', current_setting('verif.seule'), true);
do $$ begin
  if (public.fetch_my_finance_summary() ->> 'available_fcfa')::int <> -10000 then
    raise exception 'ÉCHEC : la commission due n''apparaît pas (%)', public.fetch_my_finance_summary();
  end if;
  perform verif.refuse('retirer en devant sa commission', $q$insert into public.payout_requests (id, supplier_id, amount_fcfa, status, method, payout_destination)
    values ('verif-dette', 'c0000000-0000-4000-8000-000000000002', 1, 'requested', 'orange_money', '+22370000051')$q$,
    'Montant demandé (1 FCFA) supérieur au solde disponible (-10000 FCFA).');
end $$;

-- ---- 4. qui lit quoi ---------------------------------------------------------------------------
reset role;
-- Une vendeuse de Bogolan, créée comme create-collaborator le fait.
select verif.inscrire('c0000000-0000-4000-8000-000000000003', '{"username_or_phone":"v-vendeuse","display_name":"Vendeuse","phone_number":"+22370000052"}');
update auth.users set raw_app_meta_data = raw_app_meta_data || '{"collaborator_of":"b7eb8585-4091-5b6f-83f7-5d70724e97a3","permissions":["orders","products"]}'
 where id = 'c0000000-0000-4000-8000-000000000003';
select verif.jeton('c0000000-0000-4000-8000-000000000003') as vendeuse \gset
select verif.jeton('2358888a-b13d-56f8-858b-a0c63831b512') as admin1 \gset
select verif.jeton('0354c601-5e09-57b6-a23c-affaa5acf0d0') as agent1 \gset
select set_config('verif.vendeuse', :'vendeuse', true), set_config('verif.admin1', :'admin1', true), set_config('verif.agent1', :'agent1', true);
set local role authenticated;
select set_config('request.jwt.claims', current_setting('verif.vendeuse'), true);
do $$ begin
  perform verif.refuse('la vendeuse lit les finances', 'select public.fetch_my_finance_summary()',
    'Les finances de la boutique sont réservées à son propriétaire.');
  -- Les clés d'argent sont **absentes** (`0100`), pas à zéro : un zéro se
  -- lirait comme « la boutique n'a rien vendu ».
  if public.fetch_supplier_dashboard_stats() ?| array['finance', 'gross_fcfa', 'paid_out_fcfa']
     or exists (select 1 from jsonb_array_elements(public.fetch_supplier_dashboard_stats() -> 'best_sellers') a
                 where a ? 'amount_fcfa')
     or (public.fetch_supplier_dashboard_stats() ->> 'orders_total')::int = 0 then
    raise exception 'ÉCHEC : le tableau de bord de la vendeuse montre de l''argent, ou plus ses ventes (%)',
      public.fetch_supplier_dashboard_stats();
  end if;
end $$;
select set_config('request.jwt.claims', '{"sub":"3355adef-385d-5eee-a565-815c8cf8e4d3","role":"authenticated","app_metadata":{}}', true);
do $$ begin
  perform verif.refuse('un client lit des finances', 'select public.fetch_my_finance_summary()',
    'Les finances de la boutique sont réservées à son propriétaire.');
  perform verif.refuse('un client lit les commissions', 'select public.fetch_platform_commission_fcfa()',
    'Réservé aux administrateurs MTC.');
  perform verif.refuse('un client lit un grand livre', $q$select public.supplier_ledger('b7eb8585-4091-5b6f-83f7-5d70724e97a3')$q$,
    '%permission denied%');
end $$;
select set_config('request.jwt.claims', '{"sub":"b7eb8585-4091-5b6f-83f7-5d70724e97a3","role":"authenticated","app_metadata":{}}', true);
do $$ begin
  if public.fetch_supplier_dashboard_stats() -> 'finance' is distinct from public.fetch_my_finance_summary() then
    raise exception 'ÉCHEC : le tableau de bord et l''écran des finances ne disent pas la même chose';
  end if;
end $$;
select set_config('request.jwt.claims', current_setting('verif.agent1'), true);
do $$ begin
  if (public.fetch_my_finance_summary() ->> 'commission_rate_percent')::numeric <> 0 then
    raise exception 'ÉCHEC : MTC se prend une commission sur ses propres ventes';
  end if;
  perform verif.refuse('un agent lit les commissions', 'select public.fetch_platform_commission_fcfa()',
    'Réservé aux administrateurs MTC.');
end $$;
reset role;
select set_config('verif.commissions', (select sum((public.supplier_ledger(s.id) ->> 'commission_fcfa')::bigint)::text
  from public.suppliers s where s.supplier_type = 'tiers'), true);
set local role authenticated;
select set_config('request.jwt.claims', current_setting('verif.admin1'), true);
do $$ begin
  if public.fetch_platform_commission_fcfa()::text <> current_setting('verif.commissions') then
    raise exception 'ÉCHEC : le total des commissions ne suit pas le grand livre';
  end if;
end $$;
reset role;

\o
select 'TOUTES LES VÉRIFICATIONS PASSENT' as resultat;
rollback;
