-- Brancher l'envoi d'e-mails de MTC sur Brevo ou Resend (migration 0125).
--
-- À lancer dans l'éditeur SQL du projet Supabase de **production**, partie
-- par partie. En local, rien à faire : sans réglage, les e-mails vont dans
-- Mailpit (http://127.0.0.1:54324).
--
-- ---------------------------------------------------------------------------
-- Avant tout, chez le service choisi
-- ---------------------------------------------------------------------------
--
-- Brevo (société française, interface en français) :
--   1. Créer un compte sur brevo.com.
--   2. Expéditeurs, domaines et IP dédiées : ajouter l'adresse d'expédition
--      (par exemple no-reply@votre-domaine.ml) et authentifier le domaine
--      (enregistrements DNS DKIM et DMARC fournis par Brevo).
--   3. SMTP et API → Clés API : générer une clé (elle commence par
--      « xkeysib- »).
--
-- Resend :
--   1. Créer un compte sur resend.com.
--   2. Domains : ajouter et vérifier votre domaine (enregistrements DNS).
--   3. API Keys : créer une clé avec l'accès « Sending access » (elle
--      commence par « re_ »).
--
-- Sans domaine authentifié, les codes partent mais arrivent souvent dans les
-- courriers indésirables, quand ils ne sont pas refusés.

-- ---------------------------------------------------------------------------
-- 1. Les réglages — remplacer les valeurs, puis lancer ce bloc
-- ---------------------------------------------------------------------------
-- Ils vont dans Vault, chiffrés. Relancer le bloc les met à jour.
do $$
declare
  v_reglages constant jsonb := jsonb_build_object(
    'mail_provider', 'brevo',                    -- ou 'resend'
    'mail_api_key', 'COLLER_LA_CLE_API_ICI',
    'mail_from', 'no-reply@votre-domaine.ml',    -- adresse vérifiée chez le service
    'mail_from_name', 'MTC - Mali Trade Connect'
  );
  v_nom text;
  v_id uuid;
begin
  if v_reglages::text ~ 'COLLER_|votre-domaine' then
    raise exception 'Remplacez d''abord la clé et l''adresse d''expédition par les vôtres.';
  end if;
  if v_reglages ->> 'mail_provider' not in ('brevo', 'resend') then
    raise exception 'Service inconnu : brevo ou resend.';
  end if;
  for v_nom in select jsonb_object_keys(v_reglages) loop
    select id into v_id from vault.secrets where name = v_nom;
    if v_id is null then
      perform vault.create_secret(v_reglages ->> v_nom, v_nom);
    else
      perform vault.update_secret(v_id, v_reglages ->> v_nom);
    end if;
  end loop;
end $$;

-- Ce que la base utilisera (la clé n'est pas montrée) :
select config - 'api_key' as reglages, (config ->> 'api_key') is not null as cle_posee
  from (select public.mail_config() as config) c;

-- ---------------------------------------------------------------------------
-- 2. Un essai réel — remplacer l'adresse par la vôtre
-- ---------------------------------------------------------------------------
-- select public.send_mail(
--   'votre.adresse@exemple.com',
--   'Essai d''envoi MTC',
--   'Si vous lisez ceci, l''envoi d''e-mails de MTC fonctionne.',
--   null,
--   'essai'
-- );

-- ---------------------------------------------------------------------------
-- 3. Ce que le service a répondu (quelques secondes après l'envoi)
-- ---------------------------------------------------------------------------
-- 200 ou 201 : accepté. 401 ou 403 : clé refusée. 400 ou 422 : adresse
-- d'expédition ou domaine non vérifiés — le motif est dans « error ».
select * from public.recent_mail_deliveries(10);

-- ---------------------------------------------------------------------------
-- Revenir à Mailpit (en local seulement)
-- ---------------------------------------------------------------------------
-- delete from vault.secrets
--  where name in ('mail_provider', 'mail_api_key', 'mail_from', 'mail_from_name', 'mail_api_url');
