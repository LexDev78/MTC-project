-- Les tests n'envoient pas de vrais e-mails.
--
-- Les tests d'intégration demandent des codes de vérification (`0124`) et les
-- lisent dans Mailpit, la boîte de test locale. Une fois un vrai service
-- branché en local (`0125`, Brevo ou Resend), ces mêmes tests feraient partir
-- de vrais e-mails — vers des adresses inventées, qui peuvent appartenir à
-- quelqu'un — et échoueraient faute de trouver le code dans Mailpit.
--
-- `resetAndSeed()` (le harnais des tests) appelle donc cette garde avant de
-- toucher à la base : tant qu'un service réel est configuré, les tests ne
-- tournent pas. Retirer les secrets `mail_*` de Vault les rouvre (voir
-- `supabase/snippets/configurer_envoi_mail.sql`).

create or replace function public.test_assert_mail_sandbox()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_service text := public.mail_config() ->> 'provider';
begin
  if v_service <> 'mailpit' then
    raise exception
      'Un service d''envoi réel (%) est configuré : les tests enverraient de vrais e-mails. Retirez les secrets mail_* de Vault pour les lancer.',
      v_service;
  end if;
end;
$$;

revoke all on function public.test_assert_mail_sandbox() from public, anon, authenticated;
grant execute on function public.test_assert_mail_sandbox() to service_role;

notify pgrst, 'reload schema';
