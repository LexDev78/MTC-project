-- Le client change le nom affiché de son compte (écran « Modifier le
-- profil » du kit FlutterShop).
--
-- `0103` a retiré à `authenticated` tout droit d'écrire dans `profiles` :
-- c'est ce qui empêche de s'y donner un autre rôle. On n'y rouvre rien ; on
-- ajoute, comme `set_my_contact_email` (`0109`), un chemin qui ne touche
-- qu'une colonne, et seulement la sienne.
--
-- Les instantanés gardent le nom d'alors : commandes
-- (`client_display_name_snapshot`), avis, commentaires, conversations. Un
-- nom change pour la suite, pas pour l'histoire — une boutique doit pouvoir
-- relire une commande telle qu'elle a été passée.
create or replace function public.set_my_display_name(p_display_name text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  -- Espaces de tête, de queue et en double retirés : « Awa  Traoré » et
  -- « Awa Traoré » sont le même nom.
  v_nom text := regexp_replace(
    btrim(coalesce(p_display_name, '')), '\s+', ' ', 'g'
  );
begin
  if auth.uid() is null then
    raise exception 'Connectez-vous pour modifier votre nom.';
  end if;
  if char_length(v_nom) < 2 then
    raise exception 'Votre nom doit compter au moins 2 caractères.';
  end if;
  if char_length(v_nom) > 60 then
    raise exception 'Votre nom ne doit pas dépasser 60 caractères.';
  end if;

  update public.profiles
     set display_name = v_nom
   where id = auth.uid()
     and deleted_at is null;
  if not found then
    raise exception 'Ce compte n''existe plus.';
  end if;

  return v_nom;
end;
$$;

revoke all on function public.set_my_display_name(text) from public, anon;
grant execute on function public.set_my_display_name(text) to authenticated;
