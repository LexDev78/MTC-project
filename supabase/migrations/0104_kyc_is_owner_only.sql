-- Le dossier d'identité du patron, ouvert à ses employés.
--
-- Le KYC fait partie de ce qui ne se délègue jamais — avec l'argent, la
-- suppression du compte et la gestion de l'équipe. Les gardes de `0093`
-- l'ont posé pour les écrans et les RPC, mais trois règles plus anciennes
-- cloisonnaient encore par `operating_supplier_id()`. Or c'est précisément
-- la valeur qu'un collaborateur **hérite de son patron** : elle répond « la
-- boutique que j'opère », pas « ma boutique ». Là où le propriétaire était
-- visé, l'employé passait aussi.
--
-- Mesuré avec un collaborateur n'ayant que la permission `products`, en
-- transaction annulée :
--
--   select supplier_can('kyc'), is_supplier_owner();        -- false, false
--   select count(*) from supplier_kyc;                      -- 1  (le dossier du patron)
--   update supplier_kyc set tax_id='FAUX' ...;              -- UPDATE 1
--   select count(*) from storage.objects
--    where bucket_id='kyc-documents';                       -- 1  (sa pièce d'identité)
--   update storage.objects set name='…/autre.jpg' …;         -- UPDATE 1
--
-- Autrement dit : lire la carte d'identité et le numéro fiscal de son
-- patron, et altérer un dossier en attente d'examen par MTC. La politique
-- du bucket étant en `ALL`, la suppression par l'API Storage relevait de la
-- même clause (le SQL direct, lui, est refusé par la plateforme).
--
-- La correction est d'un mot : `is_supplier_owner()`. On garde
-- `operating_supplier_id()` pour désigner la boutique — c'est bien son
-- dossier — et on exige en plus d'en être le propriétaire.

-- 1. Le dossier lui-même.
drop policy if exists supplier_kyc_all_owner_or_staff on public.supplier_kyc;
create policy supplier_kyc_all_owner_or_staff on public.supplier_kyc
  for all
  using (
    (supplier_id = public.operating_supplier_id() and public.is_supplier_owner())
    or public.is_staff()
  )
  with check (
    (supplier_id = public.operating_supplier_id() and public.is_supplier_owner())
    or public.is_staff()
  );

-- 2. Les pièces qui lui sont rattachées.
drop policy if exists supplier_documents_all_owner_or_staff on public.supplier_documents;
create policy supplier_documents_all_owner_or_staff on public.supplier_documents
  for all
  using (
    exists (
      select 1 from public.supplier_kyc k
       where k.id = supplier_documents.kyc_id
         and ((k.supplier_id = public.operating_supplier_id()
               and public.is_supplier_owner())
              or public.is_staff())
    )
  )
  with check (
    exists (
      select 1 from public.supplier_kyc k
       where k.id = supplier_documents.kyc_id
         and ((k.supplier_id = public.operating_supplier_id()
               and public.is_supplier_owner())
              or public.is_staff())
    )
  );

-- 3. Les fichiers dans le bucket privé.
drop policy if exists kyc_documents_owner_or_staff on storage.objects;
create policy kyc_documents_owner_or_staff on storage.objects
  for all
  using (
    bucket_id = 'kyc-documents'
    and (
      ((storage.foldername(name))[1] = (public.operating_supplier_id())::text
        and public.is_supplier_owner())
      or public.is_staff()
    )
  )
  with check (
    bucket_id = 'kyc-documents'
    and (
      ((storage.foldername(name))[1] = (public.operating_supplier_id())::text
        and public.is_supplier_owner())
      or public.is_staff()
    )
  );

-- 4. Pendant qu'on y est : la pièce jointe d'une conversation.
--
-- `chat_attachments_participants` était en `ALL` sur le dossier de la
-- conversation : chaque participant pouvait donc supprimer ou renommer le
-- fichier envoyé par l'autre. C'est le même défaut que la réécriture des
-- messages (`0102`), sur le fichier au lieu du texte. On sépare : les deux
-- participants lisent et déposent, mais seul l'auteur du fichier le retire.
drop policy if exists chat_attachments_participants on storage.objects;

create policy chat_attachments_read on storage.objects
  for select
  using (
    bucket_id = 'chat-attachments'
    and exists (
      select 1 from public.chat_conversations c
       where c.id = (storage.foldername(objects.name))[1]
         and (c.client_id = auth.uid()
              or c.supplier_id = public.operating_supplier_id())
    )
  );

create policy chat_attachments_write on storage.objects
  for insert
  with check (
    bucket_id = 'chat-attachments'
    and exists (
      select 1 from public.chat_conversations c
       where c.id = (storage.foldername(objects.name))[1]
         and (c.client_id = auth.uid()
              or c.supplier_id = public.operating_supplier_id())
    )
  );

-- `owner` est renseigné par l'API Storage à l'envoi : c'est la seule trace
-- de qui a déposé le fichier, le chemin ne portant que la conversation.
create policy chat_attachments_owner_manage on storage.objects
  for update
  using (bucket_id = 'chat-attachments' and owner = auth.uid())
  with check (bucket_id = 'chat-attachments' and owner = auth.uid());

create policy chat_attachments_owner_delete on storage.objects
  for delete
  using (bucket_id = 'chat-attachments' and owner = auth.uid());
