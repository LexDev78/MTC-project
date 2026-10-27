-- Le patron doit voir qui n'a pas encore changé son mot de passe.
--
-- `0098` pose le drapeau sur `profiles`, que le patron ne peut pas lire :
-- `profiles_select_own` ne montre à chacun que le sien, et c'est bien ainsi
-- — un fournisseur n'a pas à parcourir les profils de la plateforme.
--
-- L'information doit donc transiter par la fonction qui lui rend déjà son
-- équipe, et qui filtre sur sa propre boutique. Sans elle, le patron ne
-- saurait jamais si le code qu'il a dicté a été remplacé, ni distinguer un
-- compte prêt d'un compte que quiconque ayant entendu le code peut encore
-- ouvrir.
create or replace function public.fetch_my_collaborators()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'user_id', c.user_id,
           'display_name', p.display_name,
           'username_or_phone', p.username_or_phone,
           'phone_number', p.phone_number,
           'permissions', to_jsonb(c.permissions),
           'must_change_password', p.must_change_password,
           'created_at', c.created_at
         ) order by p.display_name), '[]'::jsonb)
    from public.supplier_collaborators c
    join public.profiles p on p.id = c.user_id
   where c.supplier_id = public.operating_supplier_id()
     and public.is_supplier_owner();
$$;

revoke all on function public.fetch_my_collaborators() from public, anon;
grant execute on function public.fetch_my_collaborators() to authenticated;
