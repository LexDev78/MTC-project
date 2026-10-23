-- Les réglages de notification du client (écran « Notifications » du kit
-- FlutterShop) : tout couper, ou couper une sorte de notification.
--
-- Seules les sortes qu'un client reçoit vraiment ont un réglage :
--   order_updates — `order_status_update` (sa commande avance, ou est annulée) ;
--   messages      — `new_message` (une boutique lui écrit) ;
--   comments      — `new_comment` (on répond sous un produit).
-- Le kit propose aussi promotions, localisation, paiements : MTC n'envoie
-- rien de tel, et un interrupteur sans effet serait un mensonge.
--
-- Sans ligne, tout est permis : c'est l'état de chaque compte existant, et
-- celui des fournisseurs et livreurs, qui n'ont pas cet écran.
create table if not exists public.notification_preferences (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  enabled boolean not null default true,
  order_updates boolean not null default true,
  messages boolean not null default true,
  comments boolean not null default true
);

alter table public.notification_preferences enable row level security;

-- Chacun ne lit et n'écrit que sa propre ligne.
drop policy if exists notification_preferences_select_own
  on public.notification_preferences;
create policy notification_preferences_select_own
  on public.notification_preferences
  for select using (user_id = auth.uid());

drop policy if exists notification_preferences_insert_own
  on public.notification_preferences;
create policy notification_preferences_insert_own
  on public.notification_preferences
  for insert with check (user_id = auth.uid());

drop policy if exists notification_preferences_update_own
  on public.notification_preferences;
create policy notification_preferences_update_own
  on public.notification_preferences
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Les droits par défaut du schéma ouvrent tout à `anon` et `authenticated` ;
-- on ne garde que ce que l'écran fait : lire, créer, modifier sa ligne.
revoke all on table public.notification_preferences from anon, authenticated;
grant select, insert, update on table public.notification_preferences
  to authenticated;

-- Le réglage s'applique à la source : une notification coupée n'est pas
-- écrite. Elle n'apparaît donc ni dans la liste, ni dans le compteur de la
-- cloche, et le push — déclenché après l'insertion
-- (`notifications_send_push`) — ne part pas.
--
-- `security definer` : la notification est écrite par la session de celui
-- qui agit (une boutique qui change l'état d'une commande, un client qui
-- écrit), qui ne peut pas lire les réglages du destinataire.
create or replace function public.notification_respects_preferences()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v public.notification_preferences;
begin
  select * into v
    from public.notification_preferences
   where user_id = new.user_id;

  if not found then
    return new;
  end if;

  if not v.enabled
     or (new.type = 'order_status_update' and not v.order_updates)
     or (new.type = 'new_message' and not v.messages)
     or (new.type = 'new_comment' and not v.comments) then
    return null;
  end if;

  return new;
end;
$$;

revoke all on function public.notification_respects_preferences()
  from public, anon, authenticated;

drop trigger if exists notifications_respect_preferences
  on public.notifications;
create trigger notifications_respect_preferences
  before insert on public.notifications
  for each row execute function public.notification_respects_preferences();
