-- Le client choisit son adresse par défaut : celle que le paiement propose,
-- et que la carte d'adresse marque du ruban « Par défaut ».
--
-- `profiles.default_address_id` existait depuis `0001` sans chemin pour
-- l'écrire : `authenticated` n'écrit pas dans `profiles` (`0103`). Comme
-- `set_my_contact_email` (`0109`), une fonction qui ne touche que cette
-- colonne, et seulement la sienne.
--
-- L'adresse doit appartenir à l'appelant. Une adresse d'un autre compte
-- reçoit la même réponse qu'une adresse qui n'existe pas : la fonction ne
-- dit pas si l'identifiant d'un autre client est valide.
--
-- `null` retire le choix ; supprimer l'adresse choisie le retire aussi
-- (`on delete set null`, `0001`).
create or replace function public.set_my_default_address(p_address_id text)
returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Connectez-vous pour choisir votre adresse par défaut.';
  end if;

  if p_address_id is not null and not exists (
    select 1
      from public.addresses
     where id = p_address_id
       and user_id = auth.uid()
  ) then
    raise exception 'Adresse introuvable.';
  end if;

  update public.profiles
     set default_address_id = p_address_id
   where id = auth.uid()
     and deleted_at is null;
  if not found then
    raise exception 'Ce compte n''existe plus.';
  end if;

  return p_address_id;
end;
$$;

revoke all on function public.set_my_default_address(text) from public, anon;
grant execute on function public.set_my_default_address(text) to authenticated;
