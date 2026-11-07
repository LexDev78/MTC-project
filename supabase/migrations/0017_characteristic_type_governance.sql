-- Gouvernance des types de caractéristiques de produit (couleur/stockage/
-- taille/poids + propositions fournisseur soumises à validation staff) —
-- clone exact du circuit "proposition → file d'attente staff →
-- approuvé/rejeté → notification" déjà utilisé pour `supplier_kyc`
-- (`0001_initial_schema.sql`) et `payout_requests` (`0005_payout_status_rpc.sql`).
--
-- Voir /Users/solomon/.claude/plans/sunny-splashing-token.md section 1.1 / 5.

create type public.characteristic_type_status as enum ('pending', 'approved', 'rejected');

create table public.product_characteristic_types (
  id text primary key,
  label text not null unique,
  status public.characteristic_type_status not null default 'pending',
  proposed_by_supplier_id uuid references public.suppliers (id),
  reviewed_by_staff_id uuid references public.profiles (id),
  reviewed_at timestamptz,
  rejection_reason text,
  created_at timestamptz not null default now()
);

-- Les 4 types de départ demandés par le fournisseur, pré-approuvés (aucun
-- proposant, jamais soumis à révision).
insert into public.product_characteristic_types (id, label, status) values
  ('couleur', 'Couleur', 'approved'),
  ('stockage', 'Stockage', 'approved'),
  ('taille', 'Taille', 'approved'),
  ('poids', 'Poids', 'approved');

alter type public.notification_type add value 'characteristic_type_decision';

alter table public.product_characteristic_types enable row level security;

-- Un type approuvé est visible de tous (catalogue public + picker
-- fournisseur) ; un type en attente/rejeté n'est visible que de son
-- proposant et du staff.
create policy "characteristic_types_select" on public.product_characteristic_types
  for select using (
    status = 'approved'
    or proposed_by_supplier_id = public.operating_supplier_id()
    or public.is_staff()
  );

-- Un fournisseur ne peut créer qu'une proposition à son propre nom, toujours
-- `pending` — l'approbation/le rejet passent exclusivement par la policy
-- staff ci-dessous.
create policy "characteristic_types_insert_supplier" on public.product_characteristic_types
  for insert with check (
    status = 'pending' and proposed_by_supplier_id = public.operating_supplier_id()
  );

create policy "characteristic_types_review_staff" on public.product_characteristic_types
  for update using (public.is_staff())
  with check (public.is_staff());

grant select on public.product_characteristic_types to anon;
grant select, insert, update on public.product_characteristic_types to authenticated;
