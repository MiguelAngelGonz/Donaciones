create table donaplus.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient uuid not null references donaplus.profiles(id) on delete cascade,
  publication uuid not null references donaplus.publications(id),
  donation uuid references donaplus.donations(id),
  kind text not null check (kind in (
    'nuevaCoincidencia', 'nuevaPropuesta', 'propuestaAceptada',
    'propuestaRechazada', 'cambioEstadoDonacion', 'nuevoMensaje'
  )),
  event_key text not null,
  message text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  unique (recipient, event_key)
);

create index notifications_inbox on donaplus.notifications(recipient, created_at desc, id);
create index active_publications_by_category on donaplus.publications(category, kind)
where state = 'activa';

alter table donaplus.notifications enable row level security;
revoke all on donaplus.notifications from public, anon, authenticated;
grant select on donaplus.notifications to authenticated;
grant update (read_at) on donaplus.notifications to authenticated;

create policy read_own_notifications on donaplus.notifications for select to authenticated
using (recipient = (select auth.uid()));
create policy update_own_notifications on donaplus.notifications for update to authenticated
using (recipient = (select auth.uid())) with check (recipient = (select auth.uid()));

create function donaplus.notify_publication_matches() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.state <> 'activa' then return new; end if;
  if tg_op = 'UPDATE' then
    if old.state = 'activa' and old.category = new.category then return new; end if;
  end if;

  -- Serialize new matches for a category so simultaneous publications see one another.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('komuna-matches:' || new.category, 0)
  );
  insert into donaplus.notifications (recipient, publication, kind, event_key, message)
  select
    destination.recipient,
    destination.publication,
    'nuevaCoincidencia',
    'match:' || new.category || ':' || least(new.id, counterpart.id) || ':' || greatest(new.id, counterpart.id),
    'Nueva coincidencia: ' || destination.title
  from donaplus.publications counterpart
  cross join lateral (
    values (new.author, counterpart.id, counterpart.title),
           (counterpart.author, new.id, new.title)
  ) as destination(recipient, publication, title)
  where counterpart.state = 'activa'
    and counterpart.category = new.category
    and counterpart.kind <> new.kind
    and counterpart.author <> new.author
  on conflict (recipient, event_key) do nothing;
  return new;
end;
$$;

create function donaplus.notify_proposal() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  recipient_id uuid;
  notice_kind text;
  notice_message text;
begin
  if tg_op = 'INSERT' then
    select author into recipient_id from donaplus.publications where id = new.publication;
    notice_kind := 'nuevaPropuesta';
    notice_message := case new.kind
      when 'solicitud' then 'Recibiste una solicitud para tu artículo.'
      else 'Recibiste una oferta para tu necesidad.'
    end;
  elsif new.state <> old.state and new.state in ('aceptada', 'rechazada') then
    recipient_id := new.sender;
    notice_kind := case new.state
      when 'aceptada' then 'propuestaAceptada'
      else 'propuestaRechazada'
    end;
    notice_message := case new.state
      when 'aceptada' then 'Tu propuesta fue aceptada.'
      else 'Tu propuesta fue rechazada.'
    end;
  else
    return new;
  end if;

  insert into donaplus.notifications (recipient, publication, kind, event_key, message)
  values (recipient_id, new.publication, notice_kind, 'proposal:' || new.id || ':' || new.state, notice_message)
  on conflict (recipient, event_key) do nothing;
  return new;
end;
$$;

create function donaplus.notify_donation_change() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  notice_message text;
begin
  if new.state = old.state then return new; end if;
  notice_message := case new.state
    when 'enEntrega' then 'Se coordinó la entrega de tu donación.'
    when 'entregada' then 'La donación se marcó como entregada.'
    when 'finalizada' then 'Se confirmó la recepción de tu donación.'
    when 'cancelada' then 'Una de tus donaciones se canceló.'
  end;
  if notice_message is null then return new; end if;
  insert into donaplus.notifications (recipient, publication, donation, kind, event_key, message)
  select participant.id, new.publication, new.id, 'cambioEstadoDonacion',
         'donation:' || new.id || ':' || new.state, notice_message
  from (values (new.donor), (new.recipient)) as participant(id)
  where participant.id is distinct from actor
  on conflict (recipient, event_key) do nothing;
  return new;
end;
$$;

create function donaplus.notify_donation_message() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into donaplus.notifications (recipient, publication, donation, kind, event_key, message)
  select case when d.donor = new.sender then d.recipient else d.donor end,
         d.publication, d.id, 'nuevoMensaje', 'message:' || new.id,
         'Tienes un mensaje nuevo sobre tu donación.'
  from donaplus.donations d
  where d.id = new.donation and new.sender in (d.donor, d.recipient)
  on conflict (recipient, event_key) do nothing;
  return new;
end;
$$;

revoke all on function donaplus.notify_publication_matches() from public, anon, authenticated;
revoke all on function donaplus.notify_proposal() from public, anon, authenticated;
revoke all on function donaplus.notify_donation_change() from public, anon, authenticated;
revoke all on function donaplus.notify_donation_message() from public, anon, authenticated;

create trigger publication_match_notifications
after insert or update of category, state on donaplus.publications
for each row execute function donaplus.notify_publication_matches();

create trigger proposal_notifications
after insert or update of state on donaplus.proposals
for each row execute function donaplus.notify_proposal();

create trigger donation_change_notifications
after update of state on donaplus.donations
for each row execute function donaplus.notify_donation_change();

create trigger donation_message_notifications
after insert on donaplus.messages
for each row execute function donaplus.notify_donation_message();

create or replace function public.donaplus_snapshot() returns jsonb
language sql stable security invoker set search_path = ''
as $$
  select donaplus.snapshot() || jsonb_build_object(
    'reviews', donaplus.visible_reviews(),
    'notifications', (
      select coalesce(jsonb_agg(
        jsonb_build_object(
          'id', notice.id, 'recipient', notice.recipient, 'publication', notice.publication,
          'donation', notice.donation, 'kind', notice.kind, 'message', notice.message,
          'created_at', notice.created_at, 'read_at', notice.read_at
        ) order by notice.created_at desc, notice.id
      ), '[]')
      from donaplus.notifications notice
      where notice.recipient = (select auth.uid())
    )
  )
$$;

create function public.komuna_mark_notifications_read(notification_ids uuid[])
returns void
language sql security invoker set search_path = ''
as $$
  update donaplus.notifications
  set read_at = now()
  where recipient = (select auth.uid())
    and id = any(notification_ids) and read_at is null
$$;

revoke all on function public.komuna_mark_notifications_read(uuid[]) from public, anon, authenticated;
grant execute on function public.komuna_mark_notifications_read(uuid[]) to authenticated;
