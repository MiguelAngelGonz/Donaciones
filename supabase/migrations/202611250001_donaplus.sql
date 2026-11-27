create schema donaplus;
revoke all on schema donaplus from public, anon, authenticated;
grant usage on schema donaplus to authenticated;

create table donaplus.profiles (
  id uuid primary key references auth.users on delete cascade,
  username text not null check (username ~ '^[^[:space:]]+$'),
  name text not null check (trim(name) <> ''),
  phone text not null check (phone ~ '^[0-9]{10}$'),
  location text not null check (trim(location) <> ''),
  created_at timestamptz not null default now()
);
create unique index profiles_username on donaplus.profiles (lower(username));

create table donaplus.categories (
  id text primary key,
  name text not null,
  icon text not null
);
insert into donaplus.categories values
  ('cat-salud', 'Salud', 'health'),
  ('cat-educacion', 'Educación', 'school'),
  ('cat-alimentacion', 'Alimentación', 'restaurant'),
  ('cat-ropa', 'Ropa', 'checkroom'),
  ('cat-hogar', 'Artículos para el hogar', 'chair');

create table donaplus.publications (
  id uuid primary key default gen_random_uuid(),
  author uuid not null references donaplus.profiles,
  category text not null references donaplus.categories,
  kind text not null check (kind in ('articulo', 'necesidad')),
  title text not null check (trim(title) <> ''),
  description text not null check (trim(description) <> ''),
  location text not null check (trim(location) <> ''),
  quantity integer not null check (quantity > 0),
  condition text check (condition in ('nuevo', 'comoNuevo', 'usado')),
  urgency text check (urgency in ('alta', 'media', 'baja')),
  details jsonb not null default '{}' check (jsonb_typeof(details) = 'object'),
  photos text[] not null default '{}',
  state text not null default 'activa'
    check (state in ('activa', 'reservada', 'cerrada', 'retirada')),
  created_at timestamptz not null default now(),
  check (kind <> 'articulo' or cardinality(photos) between 1 and 5),
  check (kind <> 'articulo' or category = 'cat-alimentacion' or condition is not null),
  check (kind <> 'necesidad' or urgency is not null)
);

create table donaplus.proposals (
  id uuid primary key default gen_random_uuid(),
  publication uuid not null references donaplus.publications,
  sender uuid not null references donaplus.profiles,
  kind text not null check (kind in ('solicitud', 'oferta')),
  body text not null check (trim(body) <> ''),
  photos text[] not null default '{}',
  state text not null default 'pendiente'
    check (state in ('pendiente', 'aceptada', 'rechazada', 'retirada')),
  client_key text not null,
  rejection text,
  created_at timestamptz not null default now(),
  unique (sender, publication, client_key),
  check (kind <> 'oferta' or cardinality(photos) between 1 and 5),
  check (kind <> 'solicitud' or char_length(body) <= 300)
);
create unique index proposals_pending on donaplus.proposals (publication, sender)
  where state = 'pendiente';

create table donaplus.donations (
  id uuid primary key default gen_random_uuid(),
  publication uuid not null references donaplus.publications,
  proposal uuid not null unique references donaplus.proposals,
  donor uuid not null references donaplus.profiles,
  recipient uuid not null references donaplus.profiles,
  state text not null default 'aceptada'
    check (state in ('aceptada', 'enEntrega', 'entregada', 'finalizada', 'cancelada')),
  place text,
  scheduled_at timestamptz,
  delivered_at timestamptz,
  finished_at timestamptz,
  cancellation text,
  share_donor boolean not null default false,
  share_recipient boolean not null default false,
  history jsonb not null default '[]',
  check (donor <> recipient)
);
create unique index donations_current_publication on donaplus.donations (publication)
  where state <> 'cancelada';
create index donations_donor on donaplus.donations(donor);
create index donations_recipient on donaplus.donations(recipient);

create table donaplus.messages (
  id uuid primary key default gen_random_uuid(),
  donation uuid not null references donaplus.donations,
  sender uuid not null references donaplus.profiles,
  body text not null check (char_length(trim(body)) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index messages_donation on donaplus.messages(donation, created_at);

create table donaplus.actions (
  actor uuid not null references donaplus.profiles,
  donation uuid not null references donaplus.donations,
  operation text not null,
  client_key text not null,
  primary key (actor, donation, operation, client_key)
);

alter table donaplus.profiles enable row level security;
alter table donaplus.categories enable row level security;
alter table donaplus.publications enable row level security;
alter table donaplus.proposals enable row level security;
alter table donaplus.donations enable row level security;
alter table donaplus.messages enable row level security;
alter table donaplus.actions enable row level security;
revoke all on all tables in schema donaplus from public, anon, authenticated;

create function donaplus.create_profile() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.raw_user_meta_data ->> 'privacy_accepted' is distinct from 'true' then
    raise exception 'Se requiere aceptar el aviso de privacidad.';
  end if;
  insert into donaplus.profiles(id, username, name, phone, location)
  values (
    new.id,
    trim(new.raw_user_meta_data ->> 'username'),
    trim(new.raw_user_meta_data ->> 'name'),
    trim(new.raw_user_meta_data ->> 'phone'),
    trim(new.raw_user_meta_data ->> 'location')
  );
  return new;
end;
$$;
revoke all on function donaplus.create_profile() from public, anon, authenticated;
create trigger donaplus_create_profile after insert on auth.users
for each row execute function donaplus.create_profile();

-- Names in a published article and its photos are visible in the authenticated feed.
-- Account contacts never leave the private schema except through the snapshot below.
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('donaplus-publications', 'donaplus-publications', false, 5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']);

create function donaplus.can_read_photo(path text) returns boolean
language sql stable security definer set search_path = ''
as $$
  select auth.uid() is not null and (
    split_part(path, '/', 1) = auth.uid()::text
    or exists (
      select 1 from donaplus.publications p where path = any(p.photos)
        and (p.state = 'activa' or exists (
          select 1 from donaplus.proposals q
          where q.publication = p.id and q.sender = auth.uid()
        ))
    )
    or exists (
      select 1 from donaplus.proposals q
      join donaplus.publications p on p.id = q.publication
      where path = any(q.photos) and p.author = auth.uid()
    )
  );
$$;
revoke all on function donaplus.can_read_photo(text) from public, anon, authenticated;
grant execute on function donaplus.can_read_photo(text) to authenticated;

create policy donaplus_upload_photo on storage.objects for insert to authenticated
with check (bucket_id = 'donaplus-publications'
  and (storage.foldername(name))[1] = auth.uid()::text);
create policy donaplus_read_photo on storage.objects for select to authenticated
using (bucket_id = 'donaplus-publications' and donaplus.can_read_photo(name));

create function donaplus.snapshot() returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  actor uuid := auth.uid();
begin
  if actor is null or not exists (select 1 from donaplus.profiles where id = actor) then
    raise exception 'Inicia sesión para acceder a Komuna.' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'categories', (select jsonb_agg(c) from donaplus.categories c),
    'profiles', (select jsonb_agg(jsonb_build_object(
      'id', p.id, 'username', p.username, 'name', p.name, 'created_at', p.created_at,
      'phone', case when p.id = actor then p.phone end,
      'location', case when p.id = actor then p.location end
    )) from donaplus.profiles p where p.id = actor or exists (
      select 1 from donaplus.publications a
      where a.author = p.id and (a.state = 'activa' or exists (
        select 1 from donaplus.proposals q where q.publication = a.id and q.sender = actor
      ))
    ) or exists (
      select 1 from donaplus.proposals q join donaplus.publications a on a.id = q.publication
      where a.author = actor and q.sender = p.id
    )),
    'publications', (select jsonb_agg(p order by p.created_at desc)
      from donaplus.publications p where p.state = 'activa' or p.author = actor or exists (
        select 1 from donaplus.proposals q where q.publication = p.id and q.sender = actor
      )),
    'proposals', (select jsonb_agg(q order by q.created_at desc)
      from donaplus.proposals q join donaplus.publications p on p.id = q.publication
      where actor in (q.sender, p.author)),
    'donations', (select jsonb_agg(to_jsonb(d) || jsonb_build_object(
      'shared_phone', case
        when d.state not in ('aceptada', 'enEntrega') then null
        when d.donor = actor and d.share_recipient then r.phone
        when d.recipient = actor and d.share_donor then o.phone
      end,
      'messages', (select jsonb_agg(m order by m.created_at, m.id)
        from donaplus.messages m where m.donation = d.id)
    )) from donaplus.donations d
      join donaplus.profiles r on r.id = d.recipient
      join donaplus.profiles o on o.id = d.donor
      where actor in (d.donor, d.recipient))
  );
end;
$$;
revoke all on function donaplus.snapshot() from public, anon, authenticated;
grant execute on function donaplus.snapshot() to authenticated;

create function donaplus.write(operation text, payload jsonb) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  caller_id uuid := actor;
  action_name text := operation;
  item_id uuid := (payload ->> 'id')::uuid;
  request_key text := payload ->> 'client_key';
  result_id uuid;
  p donaplus.publications%rowtype;
  q donaplus.proposals%rowtype;
  d donaplus.donations%rowtype;
  photo_paths text[];
  next_state text;
begin
  if actor is null or not exists (select 1 from donaplus.profiles where id = actor) then
    raise exception 'Inicia sesión para realizar esta acción.' using errcode = '42501';
  end if;

  if operation = 'profile' then
    update donaplus.profiles set
      name = trim(payload ->> 'name'), phone = trim(payload ->> 'phone'),
      location = trim(payload ->> 'location')
    where id = actor;
    return actor;
  end if;

  if operation in ('publish', 'edit', 'propose') then
    photo_paths := array(select jsonb_array_elements_text(coalesce(payload -> 'photos', '[]')));
    if cardinality(photo_paths) > 5 or exists (
      select 1 from unnest(photo_paths) as path
      where split_part(path, '/', 1) <> actor::text
        or not exists (select 1 from storage.objects o
          where o.bucket_id = 'donaplus-publications' and o.name = path)
    ) then
      raise exception 'Selecciona hasta cinco fotos de tu dispositivo.';
    end if;
  end if;

  if operation = 'publish' then
    insert into donaplus.publications
      (author, category, kind, title, description, location, quantity, condition, urgency, details, photos)
    values (actor, payload ->> 'category', payload ->> 'kind', trim(payload ->> 'title'),
      trim(payload ->> 'description'), trim(payload ->> 'location'), (payload ->> 'quantity')::integer,
      payload ->> 'condition', payload ->> 'urgency', coalesce(payload -> 'details', '{}'), photo_paths)
    returning id into result_id;
    return result_id;
  end if;

  if operation in ('edit', 'withdraw_publication', 'propose', 'accept', 'reject', 'withdraw_proposal') then
    if operation in ('accept', 'reject', 'withdraw_proposal') then
      select * into q from donaplus.proposals where id = item_id;
      if not found then raise exception 'No se encontró la propuesta.'; end if;
      select * into p from donaplus.publications where id = q.publication for update;
      select * into q from donaplus.proposals where id = item_id for update;
    else
      select * into p from donaplus.publications where id = item_id for update;
      if not found then raise exception 'No se encontró la publicación.'; end if;
    end if;

    if operation in ('edit', 'withdraw_publication', 'accept', 'reject') and p.author <> actor then
      raise exception 'Esta acción corresponde a quien publicó el artículo.' using errcode = '42501';
    end if;
    if operation = 'withdraw_proposal' and q.sender <> actor then
      raise exception 'Solo puedes retirar tu propia propuesta.' using errcode = '42501';
    end if;

    if operation = 'accept' and q.state = 'aceptada' then
      select id into result_id from donaplus.donations where proposal = q.id;
      return result_id;
    end if;
    if operation = 'propose' then
      select id into result_id from donaplus.proposals
        where publication = p.id and sender = actor and client_key = request_key;
      if found then return result_id; end if;
    end if;

    if p.state <> 'activa' then raise exception 'La publicación ya no está activa.'; end if;
    if operation in ('accept', 'reject', 'withdraw_proposal') and q.state <> 'pendiente' then
      raise exception 'La propuesta ya fue atendida.';
    end if;

    case operation
      when 'edit' then
        update donaplus.publications set category = payload ->> 'category',
          title = trim(payload ->> 'title'), description = trim(payload ->> 'description'),
          location = trim(payload ->> 'location'), quantity = (payload ->> 'quantity')::integer,
          condition = payload ->> 'condition', urgency = payload ->> 'urgency',
          details = coalesce(payload -> 'details',
            case when category = payload ->> 'category' then details else '{}' end),
          photos = photo_paths
        where id = p.id;
        return p.id;
      when 'withdraw_publication' then
        update donaplus.publications set state = 'retirada' where id = p.id;
        update donaplus.proposals set state = 'rechazada' where publication = p.id and state = 'pendiente';
        return p.id;
      when 'propose' then
        if p.author = actor then raise exception 'Elige una publicación de otra persona.'; end if;
        if exists (select 1 from donaplus.proposals
          where publication = p.id and sender = actor and state = 'pendiente') then
          raise exception 'Ya tienes una propuesta pendiente para esta publicación.';
        end if;
        insert into donaplus.proposals (publication, sender, kind, body, photos, client_key)
        values (p.id, actor, case when p.kind = 'articulo' then 'solicitud' else 'oferta' end,
          trim(payload ->> 'body'), photo_paths, request_key)
        returning id into result_id;
        return result_id;
      when 'accept' then
        update donaplus.publications set state = 'reservada' where id = p.id;
        update donaplus.proposals set
          state = case when id = q.id then 'aceptada' else 'rechazada' end
        where publication = p.id and state = 'pendiente';
        insert into donaplus.donations (publication, proposal, donor, recipient, history)
        values (p.id, q.id,
          case when q.kind = 'solicitud' then p.author else q.sender end,
          case when q.kind = 'solicitud' then q.sender else p.author end,
          jsonb_build_array(jsonb_build_object(
            'state', 'aceptada', 'actor', actor, 'at', now()
          )))
        returning id into result_id;
        return result_id;
      when 'reject' then
        update donaplus.proposals set state = 'rechazada', rejection = payload ->> 'reason' where id = q.id;
        return q.id;
      when 'withdraw_proposal' then
        update donaplus.proposals set state = 'retirada' where id = q.id;
        return q.id;
    end case;
  end if;

  select * into d from donaplus.donations where id = item_id for update;
  if not found or actor not in (d.donor, d.recipient) then
    raise exception 'No tienes acceso a esta donación.' using errcode = '42501';
  end if;

  if operation in ('message', 'share_phone') then
    if d.state not in ('aceptada', 'enEntrega') then
      raise exception 'El chat ya no está disponible para esta donación.';
    end if;
    if operation = 'message' then
      insert into donaplus.messages (donation, sender, body)
      values (d.id, actor, trim(payload ->> 'body')) returning id into result_id;
      return result_id;
    end if;
    update donaplus.donations set
      share_donor = case when actor = d.donor then (payload ->> 'share')::boolean else share_donor end,
      share_recipient = case when actor = d.recipient then (payload ->> 'share')::boolean else share_recipient end
    where id = d.id;
    return d.id;
  end if;

  if request_key is null then raise exception 'Falta el identificador de la acción.'; end if;
  if exists (select 1 from donaplus.actions a where a.actor = caller_id and a.donation = d.id
    and a.operation = action_name and a.client_key = request_key) then return d.id;
  end if;

  case operation
    when 'schedule' then
      if d.state <> 'aceptada' or coalesce(trim(payload ->> 'place'), '') = ''
        or (payload ->> 'date')::timestamptz is null then
        raise exception 'Indica un lugar y una fecha para coordinar la entrega.';
      end if;
      next_state := 'enEntrega';
      update donaplus.donations set place = trim(payload ->> 'place'),
        scheduled_at = (payload ->> 'date')::timestamptz where id = d.id;
    when 'deliver' then
      if actor <> d.donor or d.state <> 'enEntrega' then
        raise exception 'Solo el donante puede marcar la entrega acordada.';
      end if;
      next_state := 'entregada';
      update donaplus.donations set delivered_at = now() where id = d.id;
    when 'receive' then
      if actor <> d.recipient or d.state <> 'entregada' then
        raise exception 'Solo el donatario puede confirmar la recepción.';
      end if;
      next_state := 'finalizada';
      update donaplus.donations set finished_at = now() where id = d.id;
      update donaplus.publications set state = 'cerrada' where id = d.publication;
    when 'cancel' then
      if d.state not in ('aceptada', 'enEntrega') or coalesce(trim(payload ->> 'reason'), '') = '' then
        raise exception 'Indica el motivo para cancelar esta entrega.';
      end if;
      next_state := 'cancelada';
      update donaplus.donations set cancellation = trim(payload ->> 'reason') where id = d.id;
      update donaplus.publications set state = 'activa' where id = d.publication;
    else raise exception 'Acción no disponible.';
  end case;
  update donaplus.donations set state = next_state,
    history = history || jsonb_build_object('state', next_state, 'actor', actor, 'at', now())
    where id = d.id;
  insert into donaplus.actions values (actor, d.id, operation, request_key);
  return d.id;
end;
$$;
revoke all on function donaplus.write(text, jsonb) from public, anon, authenticated;
grant execute on function donaplus.write(text, jsonb) to authenticated;

-- Expose only invoker entry points; private functions enforce ownership and participation.
create function public.donaplus_snapshot() returns jsonb
language sql stable security invoker set search_path = ''
as $$ select donaplus.snapshot() $$;
revoke all on function public.donaplus_snapshot() from public, anon, authenticated;
grant execute on function public.donaplus_snapshot() to authenticated;

create function public.donaplus_write(operation text, payload jsonb) returns uuid
language sql security invoker set search_path = ''
as $$ select donaplus.write(operation, payload) $$;
revoke all on function public.donaplus_write(text, jsonb) from public, anon, authenticated;
grant execute on function public.donaplus_write(text, jsonb) to authenticated;
