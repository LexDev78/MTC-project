-- 0144 — Personne ne s'inscrit sous l'identité d'un autre (audit du
-- 27/10/2026, faille 7, et ce qu'elle a montré autour).
--
-- 1. L'identifiant. L'app ne connaît que l'identifiant (`username_or_phone`)
--    et en tire l'adresse de connexion, `minuscules@mtc.local`
--    (`pseudo_email.dart`, `create-collaborator`, `creer_compte_staff.sh`).
--    Mais par l'API publique, `username_or_phone` arrivait dans les
--    métadonnées sans rapport avec l'adresse : « Client1 » s'inscrivait à
--    côté de « client1 » (l'unicité tenait compte de la casse), et
--    `password_reset_account`, qui cherche en minuscules avec `limit 1`,
--    pouvait viser le mauvais compte. Pire, on pouvait réserver
--    l'identifiant d'un autre avant lui : son inscription échouait ensuite
--    sur la contrainte d'unicité. Désormais l'identifiant est celui de
--    l'adresse — la base le vérifie — et l'unicité ignore la casse et les
--    espaces autour.
--
-- 2. Les noms réservés. `handle_new_user` acceptait n'importe quel
--    `business_name`, « MTC Officiel » compris, et une boutique pouvait se
--    renommer ainsi plus tard par un simple UPDATE (`suppliers_update_own`).
--    Même chose pour le nom affiché d'un client ou d'un livreur, qui signe
--    les commentaires, les avis et les messages. Un nom qui contient « MTC »
--    ou « Mali Trade Connect » — casse, accents, espaces, ponctuation et
--    lettres sosies (cyrilliques, pleine chasse) ignorés —, ou qui se fait
--    passer pour le service client ou l'administration, est refusé. Seuls la
--    boutique officielle et le staff le portent.
--
--    Le nom affiché se vérifie à la validation de la transaction : un compte
--    staff est créé par l'API d'administration en deux temps (l'insertion,
--    puis `app_metadata` qui le fait staff, `apply_account_provisioning`),
--    et « Admin MTC » doit passer au second.
--
-- 3. Le nom d'une boutique recopié sur ses produits (`products.supplier_name`)
--    suit désormais un renommage, au lieu d'attendre la prochaine écriture
--    de chaque produit (`0137`).

-- -------------------------------------------------------- 1. les noms réservés
-- Minuscules ASCII sans accents, mots séparés par une espace, et les
-- lettres isolées qui se suivent recollées en un mot : « M.T.C Officiel »,
-- « mtc-officiel », « ＭＴＣ officiel », « 𝐌𝐓𝐂 » et « МТС Officiel »
-- (cyrillique) donnent tous « mtc officiel ». Les mots ne sont pas collés
-- entre eux : « Karim T. Coulibaly » reste « karim t coulibaly », et ne
-- contient pas « mtc ».
--
-- Dans l'ordre : la forme NFKC (lettres mathématiques, pleine chasse,
-- chiffres romains, exposants → lettres ordinaires) ; les caractères
-- invisibles (espaces de largeur nulle, marques de direction, trait d'union
-- conditionnel, sélecteurs de variante) et les diacritiques combinants
-- retirés — « M<U+200B>TC », « M̶TC » ne se distinguent pas de « MTC » à
-- l'œil ; puis les lettres sosies (cyrilliques, grecques, petites
-- capitales) ramenées à leur jumelle latine.
create or replace function public.normalized_public_name(p_name text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select btrim(regexp_replace(
    regexp_replace(
      translate(
        regexp_replace(lower(normalize(coalesce(p_name, ''), NFKC)),
          '[\u00AD\u034F\u061C\u115F\u1160\u17B4\u17B5\u180E\u200B-\u200F\u202A-\u202E\u2060-\u206F\u3164\uFE00-\uFE0F\uFEFF\uFFA0\u0300-\u036F\u1AB0-\u1AFF\u1DC0-\u1DFF\u20D0-\u20FF\uFE20-\uFE2F]',
          '', 'g'),
        'ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝàáâãäåçèéêëìíîïñòóôõöùúûüýÿĀāĂăĄąĆćĈĉĊċČčĎďĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĨĩĪīĬĭĮįİĴĵĶķĹĺĻļĽľŃńŅņŇňŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšŢţŤťŨũŪūŬŭŮůŰűŲųŴŵŶŷŸŹźŻżŽžſƠơƯưǍǎǏǐǑǒǓǔǕǖǗǘǙǚǛǜǞǟǠǡǦǧǨǩǪǫǬǭǰǴǵǸǹǺǻȀȁȂȃȄȅȆȇȈȉȊȋȌȍȎȏȐȑȒȓȔȕȖȗȘșȚțȞȟȦȧȨȩȪȫȬȭȮȯȰȱȲȳḀḁḂḃḄḅḆḇḈḉḊḋḌḍḎḏḐḑḒḓḔḕḖḗḘḙḚḛḜḝḞḟḠḡḢḣḤḥḦḧḨḩḪḫḬḭḮḯḰḱḲḳḴḵḶḷḸḹḺḻḼḽḾḿṀṁṂṃṄṅṆṇṈṉṊṋṌṍṎṏṐṑṒṓṔṕṖṗṘṙṚṛṜṝṞṟṠṡṢṣṤṥṦṧṨṩṪṫṬṭṮṯṰṱṲṳṴṵṶṷṸṹṺṻṼṽṾṿẀẁẂẃẄẅẆẇẈẉẊẋẌẍẎẏẐẑẒẓẔẕẖẗẘẙẛẠạẢảẤấẦầẨẩẪẫẬậẮắẰằẲẳẴẵẶặẸẹẺẻẼẽẾếỀềỂểỄễỆệỈỉỊịỌọỎỏỐốỒồỔổỖỗỘộỚớỜờỞởỠỡỢợỤụỦủỨứỪừỬửỮữỰựỲỳỴỵỶỷỸỹABCDEFGHIJKLMNOPQRSTUVWXYZАВЕКМНОРСТУХаеорсухмтквнΑΒΕΗΙΚΜΝΟΡΤΥΧαεικνορτυχ０１２３４５６７８９ＡａＢｂＣｃＤｄＥｅＦｆＧｇＨｈＩｉＪｊＫｋＬｌＭｍＮｎＯｏＰｐＱｑＲｒＳｓＴｔＵｕＶｖＷｗＸｘＹｙＺｚᴀʙᴄᴅᴇꜰɢʜɪᴊᴋʟᴍɴᴏᴘʀꜱᴛᴜᴠᴡʏᴢЅѕІіЈјԀԁҺһԚԛԜԝӀӏҮүҒԍԌƖϲϹϳͿςΖζϐϻϺıȷɑɡɩʋɯʍꞵ',
        'aaaaaaceeeeiiiinooooouuuuyaaaaaaceeeeiiiinooooouuuuyyaaaaaaccccccccddeeeeeeeeeegggggggghhiiiiiiiiijjkkllllllnnnnnnoooooorrrrrrssssssssttttuuuuuuuuuuuuwwyyyzzzzzzsoouuaaiioouuuuuuuuuuaaaaggkkoooojggnnaaaaaaeeeeiiiioooorrrruuuusstthhaaeeooooooooyyaabbbbbbccddddddddddeeeeeeeeeeffgghhhhhhhhhhiiiikkkkkkllllllllmmmmmmnnnnnnnnoooooooopppprrrrrrrrssssssssssttttttttuuuuuuuuuuvvvvwwwwwwwwwwxxxxyyzzzzzzhtwysaaaaaaaaaaaaaaaaaaaaaaaaeeeeeeeeeeeeeeeeiiiioooooooooooooooooooooooouuuuuuuuuuuuuuyyyyyyyyabcdefghijklmnopqrstuvwxyzabekmhopctyxaeopcyxmtkbhabehikmnoptyxaeiknoptux0123456789aabbccddeeffgghhiijjkkllmmnnooppqqrrssttuuvvwwxxyyzzabcdefghijklmnoprstuvwyzssiijjddhhqqwwllyyfgglccjjczzbmmijagiumwb'),
      '[^a-z0-9]+', ' ', 'g'),
    '\m([a-z]) (?=[a-z]\M)', '\1', 'g'));
$$;

-- Réservé : un mot qui contient « mtc » (« rn » compté pour « m », qui s'y
-- confond), quelques mots voisins qui, recollés, commencent par « mtc »
-- (« M TC », « MT-C »), « Mali Trade Connect » sous toutes ses graphies, ou
-- un nom qui se fait passer pour le service client ou l'administration.
create or replace function public.is_reserved_public_name(p_name text)
returns boolean
language sql
immutable
parallel safe
set search_path = ''
as $$
  with n as (select public.normalized_public_name(p_name) as mots),
  t as (select mots, array_remove(regexp_split_to_array(mots, ' '), '') as m from n)
  select exists (select 1 from unnest(m) w
                  where w like '%mtc%' or replace(w, 'rn', 'm') like '%mtc%')
      or exists (select 1 from generate_subscripts(m, 1) i
                  where m[i] in ('m', 'mt', 'rn', 'rnt')
                    and replace(m[i] || coalesce(m[i + 1], '') || coalesce(m[i + 2], ''), 'rn', 'm')
                        like 'mtc%')
      or replace(mots, ' ', '') like '%tradeconnect%'
      or replace(mots, ' ', '') in (
           'admin', 'administrateur', 'administratrice', 'administration',
           'support', 'staff', 'moderateur', 'moderatrice', 'moderation',
           'equipe', 'service', 'serviceclient', 'servicesclients',
           'serviceclientele', 'supportclient', 'assistance')
      or replace(mots, ' ', '') like 'serviceclient%'
      or replace(mots, ' ', '') like 'supportclient%'
      or replace(mots, ' ', '') like 'supporttechnique%'
      or replace(mots, ' ', '') like 'administrat%'
    from t;
$$;

revoke all on function public.normalized_public_name(text) from public, anon;
revoke all on function public.is_reserved_public_name(text) from public, anon;
grant execute on function public.normalized_public_name(text) to authenticated;
grant execute on function public.is_reserved_public_name(text) to authenticated;

-- Le nom d'une boutique : à l'inscription (`handle_new_user` insère la
-- ligne) comme à chaque renommage. La boutique officielle, seule, garde le
-- sien.
create or replace function public.guard_supplier_business_name()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.supplier_type = 'principal' then
    return new;
  end if;
  new.business_name := btrim(new.business_name);
  if coalesce(new.business_name, '') = '' then
    raise exception 'Le nom de la boutique est obligatoire.';
  end if;
  if public.is_reserved_public_name(new.business_name) then
    raise exception 'Ce nom est réservé à MTC : choisissez-en un autre.'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

revoke all on function public.guard_supplier_business_name() from public, anon, authenticated;

drop trigger if exists suppliers_guard_business_name on public.suppliers;
create trigger suppliers_guard_business_name
  before insert or update of business_name on public.suppliers
  for each row execute function public.guard_supplier_business_name();

-- Le nom d'un livreur : il n'est jamais staff, la règle s'applique tout de
-- suite.
create or replace function public.guard_courier_display_name()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if public.is_reserved_public_name(new.display_name) then
    raise exception 'Ce nom est réservé à MTC : choisissez-en un autre.'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

revoke all on function public.guard_courier_display_name() from public, anon, authenticated;

drop trigger if exists couriers_guard_display_name on public.couriers;
create trigger couriers_guard_display_name
  before insert or update of display_name on public.couriers
  for each row execute function public.guard_courier_display_name();

-- Le nom affiché d'un compte : vérifié à la validation, quand on sait s'il
-- est staff.
create or replace function public.check_profile_display_name()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_staff_role text;
begin
  select p.display_name, p.staff_role::text into v_name, v_staff_role
    from public.profiles p where p.id = new.id;
  if not found then
    return null;  -- supprimé entre-temps
  end if;
  if v_staff_role is null and public.is_reserved_public_name(v_name) then
    raise exception 'Ce nom est réservé à MTC : choisissez-en un autre.'
      using errcode = '23514';
  end if;
  return null;
end;
$$;

revoke all on function public.check_profile_display_name() from public, anon, authenticated;

drop trigger if exists profiles_check_display_name on public.profiles;
create constraint trigger profiles_check_display_name
  after insert or update of display_name on public.profiles
  deferrable initially deferred
  for each row execute function public.check_profile_display_name();

-- --------------------------------------------- 2. l'identifiant de connexion
do $$
declare
  v_doublons text;
begin
  select string_agg(k, ', ') into v_doublons
    from (select lower(btrim(username_or_phone)) as k
            from public.profiles
           group by 1 having count(*) > 1) d;
  if v_doublons is not null then
    raise exception
      'Identifiants en double à la casse près (%) : à départager à la main avant cette migration.',
      v_doublons;
  end if;
end $$;

create unique index if not exists profiles_username_or_phone_ci_key
  on public.profiles (lower(btrim(username_or_phone)));

-- Reprise de la définition en vigueur (`0128`), avec : l'identifiant
-- obligatoire, rogné, et égal à celui de l'adresse de connexion.
create or replace function public.handle_new_user()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  -- Sans rôle, un compte est client : c'est ainsi que naissent les comptes
  -- créés côté serveur, avant que `app_metadata` ne les convertisse.
  v_role text := coalesce(nullif(meta ->> 'role', ''), 'client');
  v_identifier text := btrim(coalesce(meta ->> 'username_or_phone', ''));
begin
  if v_role not in ('client', 'supplier_tiers', 'livreur') then
    raise exception 'Inscription refusée : le rôle « % » ne s''obtient pas en s''inscrivant.', v_role
      using errcode = '42501';
  end if;
  if meta ?| array['staff_role', 'collaborator_of', 'permissions'] then
    raise exception 'Inscription refusée : l''appartenance à MTC ou à une boutique ne se déclare pas soi-même.'
      using errcode = '42501';
  end if;
  -- L'identifiant est celui de l'adresse de connexion, à la casse près :
  -- c'est la seule forme sous laquelle l'app, `create-collaborator` et le
  -- script du staff créent un compte. Un identifiant sans rapport avec
  -- l'adresse servait à doubler celui d'un autre.
  if v_identifier = ''
     or lower(coalesce(new.email, '')) <> lower(v_identifier) || '@mtc.local' then
    raise exception 'Inscription refusée : l''identifiant ne correspond pas au compte.'
      using errcode = '42501';
  end if;

  insert into public.profiles (id, role, username_or_phone, display_name, phone_number)
  values (
    new.id,
    v_role::public.account_role,
    v_identifier,
    meta ->> 'display_name',
    meta ->> 'phone_number'
  );

  if v_role = 'supplier_tiers' then
    insert into public.suppliers (id, business_name, supplier_type, city, verification_status, legal_type)
    values (
      new.id,
      meta ->> 'business_name',
      'tiers',
      meta ->> 'city',
      'unverified',
      (meta ->> 'legal_type')::public.supplier_legal_type
    );
  elsif v_role = 'livreur' then
    insert into public.couriers (id, status, city, vehicle_label, display_name, phone_number)
    values (
      new.id,
      'pending',
      coalesce(meta ->> 'city', 'Bamako'),
      meta ->> 'vehicle_label',
      meta ->> 'display_name',
      meta ->> 'phone_number'
    );
  end if;

  -- Un compte écrit directement en base porte déjà son `app_metadata`. Par
  -- l'API d'administration, il n'arrive qu'au déclencheur suivant.
  perform public.apply_account_provisioning(
    new.id, '{}'::jsonb, coalesce(new.raw_app_meta_data, '{}'::jsonb)
  );

  return new;
end;
$function$;

-- La recherche du compte à réinitialiser, sur la même clé que l'unicité :
-- un seul compte possible, et l'index sert. Reprise de `0127`, cette
-- comparaison seule changée.
create or replace function public.password_reset_account(p_identifiant text)
 returns uuid
 language sql
 stable security definer
 set search_path to 'public'
as $function$
  select p.id
    from public.profiles p
   where p.deleted_at is null
     and case
       when position('@' in btrim(coalesce(p_identifiant, ''))) > 0 then
         lower(p.contact_email) = lower(btrim(p_identifiant))
         and p.contact_email_verified_at is not null
       else
         lower(btrim(p.username_or_phone)) = lower(btrim(coalesce(p_identifiant, '')))
     end
   limit 1;
$function$;

-- --------------------------------------------- 3. le nom recopié sur les produits
create or replace function public.sync_products_supplier_name()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.products
     set supplier_name = new.business_name
   where supplier_id = new.id
     and supplier_name is distinct from new.business_name;
  return null;
end;
$$;

revoke all on function public.sync_products_supplier_name() from public, anon, authenticated;

drop trigger if exists suppliers_sync_products_name on public.suppliers;
create trigger suppliers_sync_products_name
  after update of business_name on public.suppliers
  for each row
  when (old.business_name is distinct from new.business_name)
  execute function public.sync_products_supplier_name();

-- ------------------------------------------- 4. ce qui existe déjà, pour mémoire
-- Les noms déjà en base ne sont pas changés d'office (ce serait renommer
-- quelqu'un sans le prévenir) : ils sont signalés, et refusés au prochain
-- changement.
do $$
declare
  v_liste text;
begin
  select string_agg(nom, ' ; ') into v_liste from (
    select 'boutique « ' || business_name || ' »' as nom from public.suppliers
     where supplier_type <> 'principal' and public.is_reserved_public_name(business_name)
    union all
    select 'compte « ' || display_name || ' »' from public.profiles
     where staff_role is null and public.is_reserved_public_name(display_name)
  ) d;
  if v_liste is not null then
    raise notice 'Noms réservés déjà portés, à traiter à la main : %', v_liste;
  end if;
end $$;
