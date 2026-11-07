-- Vérifie 0141 (dossier KYC verrouillé une fois soumis) et 0142 (fichiers
-- du dossier livreur) contre une base où elles sont appliquées, sans rien y
-- laisser : tout se passe dans une transaction annulée.
--
--   docker exec -i supabase_db_mtc_verif psql -U postgres -d postgres -q \
--     < supabase/snippets/verif_0141_0142.sql
--
-- Dernière ligne attendue : « TOUTES LES VÉRIFICATIONS PASSENT ».
\set ON_ERROR_STOP 1
\o /dev/null
begin;
set local client_min_messages = warning;

create schema verif;
grant usage on schema verif to anon, authenticated;
create function verif.comme(p_id uuid) returns void language sql security definer as $$
  select set_config('request.jwt.claims', jsonb_build_object('sub', p_id, 'role', 'authenticated',
    'aal', 'aal1', 'app_metadata', (select raw_app_meta_data from auth.users where id = p_id))::text, true);
$$;
create function verif.dossier(p_supplier uuid) returns public.supplier_kyc language sql security definer as $$
  select * from public.supplier_kyc where supplier_id = p_supplier;
$$;
-- Tente une écriture, et dit si elle a été refusée.
create function verif.refuse(p_sql text) returns boolean language plpgsql as $$
begin
  execute p_sql;
  return false;
exception when others then
  return true;
end $$;
grant execute on all functions in schema verif to anon, authenticated;

\set bogolan 'b7eb8585-4091-5b6f-83f7-5d70724e97a3'
\set sikasso 'b6b1daf0-1c8e-583f-939f-687991d429ca'
\set kayes 'bc82e68c-b1d9-538a-a8ed-8393a5ba739f'
\set niono 'deb94bf5-bddb-5399-8010-3b0264c98f1a'

-- ---- 1. un dossier naît brouillon ------------------------------------------------------------
set local role authenticated;
select verif.comme(:'kayes');
insert into public.supplier_kyc (id, supplier_id, legal_type, status, submitted_at, reviewed_at,
                                 reviewed_by_staff_id, rccm_number)
values ('verif-kyc-kayes', :'kayes', 'company', 'approved', now(), now(),
        '2358888a-b13d-56f8-858b-a0c63831b512', 'MA-BKO-2026-B-0001');
do $$
declare
  k public.supplier_kyc := verif.dossier('bc82e68c-b1d9-538a-a8ed-8393a5ba739f');
begin
  if k.status <> 'draft' or k.reviewed_at is not null or k.reviewed_by_staff_id is not null
     or k.submitted_at is not null then
    raise exception 'ÉCHEC : un dossier naît % (examiné par %)', k.status, k.reviewed_by_staff_id;
  end if;
  -- Un second dossier à côté du premier.
  if not verif.refuse($q$insert into public.supplier_kyc (id, supplier_id, legal_type, status)
                       values ('verif-kyc-kayes-2', 'bc82e68c-b1d9-538a-a8ed-8393a5ba739f', 'company', 'draft')$q$) then
    raise exception 'ÉCHEC : une boutique ouvre un second dossier';
  end if;
  -- En brouillon, elle le remplit, comme l'app.
  update public.supplier_kyc set rccm_number = 'MA-BKO-2026-B-0002' where id = 'verif-kyc-kayes';
  insert into public.supplier_documents (id, kyc_id, type, file_path, uploaded_at)
  values ('verif-doc-kayes', 'verif-kyc-kayes', 'rccm_certificate',
          'bc82e68c-b1d9-538a-a8ed-8393a5ba739f/rccm.jpg', '2020-01-01');
  if (select uploaded_at from public.supplier_documents where id = 'verif-doc-kayes') < now() - interval '1 minute' then
    raise exception 'ÉCHEC : la date de dépôt d''une pièce se déclare';
  end if;
  -- Une pièce « seed:// » n'est plus qu'au semis.
  if not verif.refuse($q$insert into public.supplier_documents (id, kyc_id, type, file_path)
                       values ('verif-doc-seed', 'verif-kyc-kayes', 'tax_id', 'seed://faux.jpg')$q$) then
    raise exception 'ÉCHEC : une boutique déclare une pièce fictive';
  end if;
end $$;

-- Soumis : il ne bouge plus.
select public.submit_supplier_kyc();
do $$ begin
  if (verif.dossier('bc82e68c-b1d9-538a-a8ed-8393a5ba739f')).status <> 'submitted' then
    raise exception 'ÉCHEC : la soumission ne passe plus';
  end if;
  if not verif.refuse($q$update public.supplier_kyc set rccm_number = 'X' where id = 'verif-kyc-kayes'$q$) then
    raise exception 'ÉCHEC : un dossier soumis se modifie';
  end if;
  if not verif.refuse($q$delete from public.supplier_documents where id = 'verif-doc-kayes'$q$) then
    raise exception 'ÉCHEC : une pièce d''un dossier soumis s''efface';
  end if;
end $$;

-- ---- 2. le dossier approuvé de l'audit ---------------------------------------------------------
select verif.comme(:'bogolan');
do $$ begin
  if not verif.refuse($q$update public.supplier_kyc set rccm_number = 'FAUX', legal_representative_name = 'Quelqu''un d''autre'
                       where supplier_id = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3'$q$) then
    raise exception 'ÉCHEC : un dossier approuvé change de RCCM';
  end if;
  if not verif.refuse($q$delete from public.supplier_kyc where supplier_id = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3'$q$) then
    raise exception 'ÉCHEC : un dossier approuvé s''efface';
  end if;
  if not verif.refuse($q$insert into public.supplier_documents (id, kyc_id, type, file_path)
                       select 'verif-doc-bogolan', id, 'tax_id', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3/autre.jpg'
                         from public.supplier_kyc where supplier_id = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3'$q$) then
    raise exception 'ÉCHEC : une pièce s''ajoute à un dossier approuvé';
  end if;
  -- Les fichiers du bucket, pareil.
  if not verif.refuse($q$insert into storage.objects (bucket_id, name, owner)
                       values ('kyc-documents', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3/remplacement.jpg', auth.uid())$q$) then
    raise exception 'ÉCHEC : un fichier se dépose dans un dossier approuvé';
  end if;
end $$;

-- ---- 3. refusé : la boutique corrige et resoumet -----------------------------------------------
select verif.comme(:'niono');
do $$ begin
  update public.supplier_kyc set rccm_number = 'MA-SEG-2026-B-0003'
   where supplier_id = 'deb94bf5-bddb-5399-8010-3b0264c98f1a';
  insert into storage.objects (bucket_id, name, owner)
  values ('kyc-documents', 'deb94bf5-bddb-5399-8010-3b0264c98f1a/nouveau.jpg', auth.uid());
end $$;
select public.submit_supplier_kyc();

-- ---- 4. le staff examine et décide, comme avant ------------------------------------------------
select verif.comme('2358888a-b13d-56f8-858b-a0c63831b512');
select public.start_kyc_review('verif-kyc-kayes');
select public.review_supplier_kyc('verif-kyc-kayes', true, null);
do $$ begin
  if (verif.dossier('bc82e68c-b1d9-538a-a8ed-8393a5ba739f')).status <> 'approved' then
    raise exception 'ÉCHEC : la décision du staff ne passe plus';
  end if;
end $$;

-- ---- 5. 0142 : les fichiers d'un livreur approuvé ne bougent plus --------------------------------
select verif.comme('f1c4e8a2-0000-5000-9000-000000000001');
do $$ begin
  if not verif.refuse($q$insert into storage.objects (bucket_id, name, owner)
                       values ('courier-documents', 'f1c4e8a2-0000-5000-9000-000000000001/permis-bis.jpg', auth.uid())$q$) then
    raise exception 'ÉCHEC : un livreur approuvé dépose un fichier dans son dossier';
  end if;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);
insert into storage.objects (bucket_id, name, owner)
values ('courier-documents', 'f1c4e8a2-0000-5000-9000-000000000001/permis.jpg',
        'f1c4e8a2-0000-5000-9000-000000000001');
set local role authenticated;
select verif.comme('f1c4e8a2-0000-5000-9000-000000000001');
-- Une policy qui refuse un DELETE n'échoue pas : elle n'efface rien. On
-- vérifie ensuite que le fichier est toujours là. (L'API Storage lève
-- d'abord ce verrou-ci, qui interdit l'effacement en SQL direct.)
select set_config('storage.allow_delete_query', 'true', true);
delete from storage.objects where bucket_id = 'courier-documents'
  and name = 'f1c4e8a2-0000-5000-9000-000000000001/permis.jpg';
reset role;
do $$ begin
  if not exists (select 1 from storage.objects where bucket_id = 'courier-documents'
                  and name = 'f1c4e8a2-0000-5000-9000-000000000001/permis.jpg') then
    raise exception 'ÉCHEC : un livreur approuvé efface une pièce de son dossier';
  end if;
  if (select allowed_mime_types from storage.buckets where id = 'courier-documents')
     is distinct from array['image/jpeg', 'image/png', 'image/webp'] then
    raise exception 'ÉCHEC : courier-documents accepte n''importe quel type de fichier';
  end if;
end $$;

-- Un livreur dont le dossier n'est pas soumis dépose ses photos.
update public.couriers set documents_submitted_at = null, status = 'pending'
 where id = 'f1c4e8a2-0000-5000-9000-000000000002';
set local role authenticated;
select verif.comme('f1c4e8a2-0000-5000-9000-000000000002');
insert into storage.objects (bucket_id, name, owner)
values ('courier-documents', 'f1c4e8a2-0000-5000-9000-000000000002/permis.jpg', auth.uid());
reset role;

\o
select 'TOUTES LES VÉRIFICATIONS PASSENT' as resultat;
rollback;
