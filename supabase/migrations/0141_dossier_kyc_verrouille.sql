-- 0141 — Un dossier KYC soumis ne se touche plus (audit du 27/10/2026,
-- faille 5).
--
-- `68b9950` (`0075`) avait retiré le droit d'écrire `status`, mais :
--
--  * l'INSERT restait ouvert sur toutes les colonnes : fournisseur3, non
--    vérifiée, insère son dossier directement en `approved`, avec un
--    `reviewed_by_staff_id` de son choix — il sort de la file du staff ;
--  * les colonnes d'identité restaient modifiables à tout moment :
--    fournisseur1, dossier approuvé, change son RCCM et son représentant
--    légal, le dossier reste `approved` et la boutique vérifiée ; elle peut
--    aussi le supprimer ;
--  * les pièces (`supplier_documents`, bucket `kyc-documents`) se
--    remplaçaient de la même façon.
--
-- Rien ne surveillait la table. Désormais :
--
--  * un dossier naît brouillon, quoi qu'en dise la requête ;
--  * il ne se modifie et ne se supprime qu'en brouillon ou refusé — les
--    deux états où l'app le fait remplir (`saveDraftCompany`,
--    `addDocument`) et d'où `submit_supplier_kyc` le soumet ;
--  * ses pièces et leurs fichiers suivent la même règle ;
--  * une boutique n'a qu'un dossier : `submit_supplier_kyc` et l'app le
--    lisent comme tel (`maybeSingle`), mais rien ne l'imposait — un second
--    dossier, inséré à côté, aurait été soumis et approuvé avec le premier.
--
-- Un changement d'identité après validation repasse par MTC : c'est le
-- staff qui rouvre un dossier, la boutique ne le fait pas seule.
--
-- Les fonctions de la base (soumission, examen, décision) écrivent sous
-- leur propriétaire et passent ; seule la requête directe de l'API est
-- visée, comme pour `guard_supplier_badges`.

-- ----------------------------------------------------- 1. un dossier par boutique
do $$
declare
  v_doublons text;
begin
  select string_agg(supplier_id::text, ', ') into v_doublons
    from (select supplier_id from public.supplier_kyc group by supplier_id having count(*) > 1) d;
  if v_doublons is not null then
    raise exception
      'Plusieurs dossiers KYC pour une même boutique (%) : à fusionner à la main avant cette migration.',
      v_doublons;
  end if;
end $$;

create unique index if not exists supplier_kyc_one_per_supplier
  on public.supplier_kyc (supplier_id);

-- ------------------------------------------------------------ 2. le dossier
create or replace function public.guard_supplier_kyc()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_user not in ('anon', 'authenticated') then
    return coalesce(new, old);
  end if;

  if tg_op = 'INSERT' then
    new.status := 'draft';
    new.submitted_at := null;
    new.reviewed_at := null;
    new.reviewed_by_staff_id := null;
    new.rejection_reason := null;
    new.created_at := now();
    return new;
  end if;

  if old.status not in ('draft', 'rejected') then
    raise exception
      'Ce dossier est entre les mains de MTC : il ne se modifie plus. Pour changer une information, contactez MTC.';
  end if;

  if tg_op = 'UPDATE' and new.supplier_id is distinct from old.supplier_id then
    raise exception 'Un dossier ne change pas de boutique.';
  end if;

  return coalesce(new, old);
end;
$$;

revoke all on function public.guard_supplier_kyc() from public, anon, authenticated;

drop trigger if exists supplier_kyc_guard on public.supplier_kyc;
create trigger supplier_kyc_guard
  before insert or update or delete on public.supplier_kyc
  for each row execute function public.guard_supplier_kyc();

-- ------------------------------------------------------------- 3. les pièces
-- Vrai quand le dossier de cette boutique n'est plus modifiable. Lue par le
-- déclencheur des pièces et par les policies du bucket : elle lit
-- `supplier_kyc` au-delà des droits de l'appelant.
create or replace function public.supplier_kyc_locked(p_supplier_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.supplier_kyc k
     where k.supplier_id = p_supplier_id
       and k.status in ('submitted', 'under_review', 'approved')
  );
$$;

revoke all on function public.supplier_kyc_locked(uuid) from public, anon;
grant execute on function public.supplier_kyc_locked(uuid) to authenticated;

create or replace function public.guard_supplier_document()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_supplier_id uuid;
begin
  if current_user not in ('anon', 'authenticated') then
    return coalesce(new, old);
  end if;

  if tg_op = 'UPDATE' and new.kyc_id is distinct from old.kyc_id then
    raise exception 'Une pièce ne change pas de dossier.';
  end if;

  select k.supplier_id into v_supplier_id
    from public.supplier_kyc k where k.id = coalesce(new.kyc_id, old.kyc_id);
  if public.supplier_kyc_locked(v_supplier_id) then
    raise exception
      'Ce dossier est entre les mains de MTC : ses pièces ne se changent plus.';
  end if;

  if tg_op <> 'DELETE' then
    new.uploaded_at := now();
  end if;
  return coalesce(new, old);
end;
$$;

revoke all on function public.guard_supplier_document() from public, anon, authenticated;

drop trigger if exists supplier_documents_guard on public.supplier_documents;
create trigger supplier_documents_guard
  before insert or update or delete on public.supplier_documents
  for each row execute function public.guard_supplier_document();

-- `seed://` désigne les fichiers fictifs du jeu de démonstration. Le
-- raccourci valait pour tout le monde : une boutique pouvait déclarer une
-- pièce « seed://… », qui n'existe nulle part, à la place d'un vrai fichier.
-- Il ne vaut plus que hors session (le semis).
create or replace function public.guard_supplier_document_path()
returns trigger
language plpgsql
set search_path to 'public'
as $function$
declare
  v_supplier_id uuid;
begin
  select supplier_id into v_supplier_id
    from public.supplier_kyc where id = new.kyc_id;
  if v_supplier_id is null then
    raise exception 'Dossier introuvable : %', new.kyc_id;
  end if;

  if new.file_path like 'seed://%' and auth.uid() is null then
    return new;
  end if;
  if new.file_path not like v_supplier_id::text || '/%'
     or new.file_path like '%/../%' then
    raise exception
      'Une pièce doit être rangée dans le dossier de son fournisseur (% attendu).',
      v_supplier_id;
  end if;
  return new;
end;
$function$;

-- --------------------------------------------------------- 4. les fichiers
-- La policy unique `kyc_documents_owner_or_staff` (ALL) devient quatre :
-- lire reste ouvert au patron et au staff ; déposer, remplacer ou effacer
-- un fichier n'est permis au patron que tant que son dossier n'est pas
-- entre les mains de MTC.
drop policy if exists kyc_documents_owner_or_staff on storage.objects;

create policy kyc_documents_read on storage.objects
  for select using (
    bucket_id = 'kyc-documents'
    and (((storage.foldername(name))[1] = (public.operating_supplier_id())::text
          and public.is_supplier_owner())
         or public.is_staff())
  );

create policy kyc_documents_insert on storage.objects
  for insert with check (
    bucket_id = 'kyc-documents'
    and (((storage.foldername(name))[1] = (public.operating_supplier_id())::text
          and public.is_supplier_owner()
          and not public.supplier_kyc_locked(public.operating_supplier_id()))
         or public.is_staff())
  );

create policy kyc_documents_update on storage.objects
  for update using (
    bucket_id = 'kyc-documents'
    and (((storage.foldername(name))[1] = (public.operating_supplier_id())::text
          and public.is_supplier_owner()
          and not public.supplier_kyc_locked(public.operating_supplier_id()))
         or public.is_staff())
  ) with check (
    bucket_id = 'kyc-documents'
    and (((storage.foldername(name))[1] = (public.operating_supplier_id())::text
          and public.is_supplier_owner()
          and not public.supplier_kyc_locked(public.operating_supplier_id()))
         or public.is_staff())
  );

create policy kyc_documents_delete on storage.objects
  for delete using (
    bucket_id = 'kyc-documents'
    and (((storage.foldername(name))[1] = (public.operating_supplier_id())::text
          and public.is_supplier_owner()
          and not public.supplier_kyc_locked(public.operating_supplier_id()))
         or public.is_staff())
  );
