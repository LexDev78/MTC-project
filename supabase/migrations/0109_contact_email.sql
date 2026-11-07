-- Une adresse e-mail de contact, facultative.
--
-- L'identifiant de connexion **reste le téléphone** (ou le nom d'utilisateur
-- d'un collaborateur) : `auth.users.email` est un pseudo-e-mail fabriqué à
-- partir de lui (`pseudoEmail`, `<identifiant>@mtc.local`). Le remplacer par
-- une vraie adresse casserait la connexion de tous les comptes, et au Mali
-- c'est le numéro qu'on retient, pas une adresse e-mail.
--
-- La vraie adresse vit donc à côté, dans `profiles`. Elle sert à joindre le
-- compte, et pourra servir plus tard à récupérer un mot de passe oublié —
-- c'est pour cela qu'elle est **unique** dès maintenant : une adresse
-- partagée par deux comptes ne saurait pas lequel débloquer.

alter table public.profiles
  add column if not exists contact_email text;

-- Le domaine des pseudo-e-mails est réservé : une adresse en `@mtc.local`
-- n'arrive nulle part, et l'accepter laisserait croire qu'elle est valide.
alter table public.profiles
  drop constraint if exists profiles_contact_email_format;
alter table public.profiles
  add constraint profiles_contact_email_format check (
    contact_email is null
    or (
      contact_email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
      and contact_email !~* '@mtc\.local$'
    )
  );

create unique index if not exists profiles_contact_email_unique
  on public.profiles (lower(contact_email))
  where contact_email is not null;

-- L'écriture passe par une fonction : `0103` a retiré à `authenticated` tout
-- droit d'écrire dans `profiles` (c'est ce qui empêche de s'y nommer
-- administrateur). On n'y rouvre rien ; on ajoute un chemin qui ne touche
-- qu'une colonne, et seulement la sienne.
create or replace function public.set_my_contact_email(p_email text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  -- Vide ou blanc = retirer l'adresse.
  v_email text := nullif(lower(btrim(coalesce(p_email, ''))), '');
begin
  if auth.uid() is null then
    raise exception 'Connectez-vous pour modifier votre adresse e-mail.';
  end if;

  if v_email is not null then
    if v_email !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
      raise exception 'Adresse e-mail invalide.';
    end if;
    if v_email ~* '@mtc\.local$' then
      raise exception 'Cette adresse n''est pas une vraie boîte e-mail.';
    end if;
    if exists (
      select 1 from public.profiles
       where lower(contact_email) = v_email and id <> auth.uid()
    ) then
      raise exception 'Cette adresse est déjà utilisée par un autre compte.';
    end if;
  end if;

  update public.profiles set contact_email = v_email where id = auth.uid();
  return v_email;
end;
$$;

revoke all on function public.set_my_contact_email(text) from public, anon;
grant execute on function public.set_my_contact_email(text) to authenticated;
