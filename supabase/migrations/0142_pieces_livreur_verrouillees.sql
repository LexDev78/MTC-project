-- 0142 — Les fichiers du dossier d'un livreur (audit du 27/10/2026, point 9,
-- et le même défaut que la faille 5, trouvé en la corrigeant).
--
--  * Le bucket `courier-documents` n'avait aucune liste de types : un
--    livreur pouvait y déposer du HTML ou du SVG, que le staff ouvre depuis
--    la file d'examen. Il prend la liste de `kyc-documents` : l'app n'envoie
--    que des photos (`uploadPickedImage`, `courier_dossier_controller.dart`).
--  * Les lignes `courier_documents` se verrouillent bien à la soumission
--    (`courier_documents_write_own_draft`, `0105`), mais pas les fichiers :
--    les policies UPDATE et DELETE du bucket ne regardaient que le dossier
--    de rangement. Un livreur approuvé remplaçait la photo de son permis
--    par une autre, sous le même nom, après l'examen. Les écritures sur le
--    bucket suivent désormais la règle des lignes : tant que le dossier
--    n'est ni soumis ni approuvé.

update storage.buckets
   set allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'],
       file_size_limit = 10 * 1024 * 1024
 where id = 'courier-documents';

-- Même condition que les policies de `courier_documents` (`0105`).
create or replace function public.courier_documents_open()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.couriers c
     where c.id = auth.uid()
       and c.documents_submitted_at is null
       and c.status <> 'approved'
  );
$$;

revoke all on function public.courier_documents_open() from public, anon;
grant execute on function public.courier_documents_open() to authenticated;

drop policy if exists courier_documents_files_write on storage.objects;
create policy courier_documents_files_write on storage.objects
  for insert with check (
    bucket_id = 'courier-documents'
    and (storage.foldername(name))[1] = (auth.uid())::text
    and public.courier_documents_open()
  );

drop policy if exists courier_documents_files_manage on storage.objects;
create policy courier_documents_files_manage on storage.objects
  for update using (
    bucket_id = 'courier-documents'
    and (storage.foldername(name))[1] = (auth.uid())::text
    and public.courier_documents_open()
  ) with check (
    bucket_id = 'courier-documents'
    and (storage.foldername(name))[1] = (auth.uid())::text
    and public.courier_documents_open()
  );

drop policy if exists courier_documents_files_delete on storage.objects;
create policy courier_documents_files_delete on storage.objects
  for delete using (
    bucket_id = 'courier-documents'
    and (storage.foldername(name))[1] = (auth.uid())::text
    and public.courier_documents_open()
  );
