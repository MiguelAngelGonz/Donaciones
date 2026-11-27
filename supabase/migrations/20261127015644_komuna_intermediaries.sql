create table donaplus.administrators (
  user_id uuid primary key references donaplus.profiles(id) on delete cascade
);

create table donaplus.intermediary_requests (
  id uuid primary key default gen_random_uuid(),
  applicant uuid not null references donaplus.profiles(id) on delete cascade,
  organization text not null check (char_length(trim(organization)) between 1 and 120),
  document_path text not null unique,
  document_name text not null check (char_length(document_name) between 1 and 255),
  document_size integer not null check (document_size between 1 and 5242880),
  state text not null default 'pendiente'
    check (state in ('pendiente', 'aprobada', 'rechazada', 'revocada')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  reviewer uuid references donaplus.profiles(id) on delete set null,
  reason text
);

create unique index intermediary_one_open_request
  on donaplus.intermediary_requests(applicant)
  where state in ('pendiente', 'aprobada');

alter table donaplus.administrators enable row level security;
alter table donaplus.intermediary_requests enable row level security;
revoke all on donaplus.administrators, donaplus.intermediary_requests
  from public, anon, authenticated;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('komuna-intermediary-documents', 'komuna-intermediary-documents', false,
        5242880, array['application/pdf', 'image/jpeg', 'image/png']);

create function donaplus.is_admin() returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from donaplus.administrators where user_id = (select auth.uid()))
$$;
revoke all on function donaplus.is_admin() from public, anon, authenticated;
grant execute on function donaplus.is_admin() to authenticated;

create function donaplus.can_review_intermediary_document(object_path text) returns boolean
language sql stable security definer set search_path = ''
as $$
  select donaplus.is_admin() and exists (
    select 1 from donaplus.intermediary_requests
    where document_path = object_path and state = 'pendiente'
  )
$$;
revoke all on function donaplus.can_review_intermediary_document(text) from public, anon, authenticated;
grant execute on function donaplus.can_review_intermediary_document(text) to authenticated;

create policy intermediary_document_upload on storage.objects
for insert to authenticated with check (
  bucket_id = 'komuna-intermediary-documents'
  and name ~ ('^' || (select auth.uid())::text || '/[0-9]+-[0-9]+\.(pdf|jpeg|jpg|png)$')
);
create policy intermediary_document_review on storage.objects
for select to authenticated using (
  bucket_id = 'komuna-intermediary-documents'
  and donaplus.can_review_intermediary_document(name)
);

create function donaplus.intermediary_snapshot() returns jsonb
language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
    'admin', donaplus.is_admin(),
    'authorized', exists (
      select 1 from donaplus.intermediary_requests
      where applicant = (select auth.uid()) and state = 'aprobada'
    ),
    'requests', coalesce((
      select jsonb_agg(
        (to_jsonb(r) - 'document_path') || jsonb_build_object(
          'document_path', case when r.state = 'pendiente' and donaplus.is_admin()
            then r.document_path end,
          'username', p.username, 'name', p.name
        ) order by r.created_at, r.id
      )
      from donaplus.intermediary_requests r
      join donaplus.profiles p on p.id = r.applicant
      where r.applicant = (select auth.uid()) or donaplus.is_admin()
    ), '[]')
  )
$$;
revoke all on function donaplus.intermediary_snapshot() from public, anon, authenticated;
grant execute on function donaplus.intermediary_snapshot() to authenticated;

alter table donaplus.publications add column beneficiary_alias text
  check (beneficiary_alias is null or (
    kind = 'necesidad' and char_length(trim(beneficiary_alias)) between 1 and 80
  ));
alter table donaplus.donations add column intermediary uuid references donaplus.profiles(id);

create function donaplus.record_donation_intermediary() returns trigger
language plpgsql set search_path = ''
as $$
begin
  select case when p.beneficiary_alias is not null then p.author end
    into new.intermediary from donaplus.publications p where p.id = new.publication;
  return new;
end
$$;
revoke all on function donaplus.record_donation_intermediary() from public, anon, authenticated;
create trigger record_donation_intermediary before insert on donaplus.donations
for each row execute function donaplus.record_donation_intermediary();

create function donaplus.prevent_revoked_reactivation() returns trigger
language plpgsql set search_path = ''
as $$
begin
  if new.beneficiary_alias is not null and new.state = 'activa'
      and old.state <> 'activa' and not exists (
        select 1 from donaplus.intermediary_requests
        where applicant = new.author and state = 'aprobada'
      ) then
    new.state := 'retirada';
  end if;
  return new;
end
$$;
revoke all on function donaplus.prevent_revoked_reactivation() from public, anon, authenticated;
create trigger prevent_revoked_reactivation before update of state on donaplus.publications
for each row execute function donaplus.prevent_revoked_reactivation();

alter table donaplus.notifications alter column publication drop not null;
alter table donaplus.notifications drop constraint notifications_kind_check;
alter table donaplus.notifications add constraint notifications_kind_check check (kind in (
  'nuevaCoincidencia', 'nuevaPropuesta', 'propuestaAceptada', 'propuestaRechazada',
  'cambioEstadoDonacion', 'nuevoMensaje', 'decisionRolIntermediario'
));

create function donaplus.manage_intermediary(operation text, payload jsonb) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  requested donaplus.intermediary_requests%rowtype;
  person uuid;
  path text := payload ->> 'document_path';
  size_bytes integer;
  org text := trim(payload ->> 'organization');
  doc_name text := trim(payload ->> 'document_name');
  decision_reason text := nullif(trim(payload ->> 'reason'), '');
  next_state text;
  notice text;
begin
  if actor is null then
    raise exception 'Inicia sesión para continuar.' using errcode = '42501';
  end if;

  if operation = 'request' then
    perform 1 from donaplus.profiles where id = actor for update;
    if not found then
      raise exception 'Completa tu perfil para continuar.' using errcode = '42501';
    end if;
    if exists (select 1 from donaplus.intermediary_requests
               where applicant = actor and state in ('pendiente', 'aprobada')) then
      raise exception 'Ya tienes una solicitud pendiente o el rol autorizado.';
    end if;
    if org is null or char_length(org) not between 1 and 120
       or doc_name is null or char_length(doc_name) not between 1 and 255 then
      raise exception 'Revisa el nombre de la organización y el documento.';
    end if;
    select (o.metadata ->> 'size')::integer into size_bytes from storage.objects o
    where o.bucket_id = 'komuna-intermediary-documents' and o.name = path
      and o.owner_id = actor::text and split_part(o.name, '/', 1) = actor::text;
    if size_bytes is null or size_bytes not between 1 and 5242880 then
      raise exception 'Adjunta un documento válido de hasta 5 MB.';
    end if;
    insert into donaplus.intermediary_requests(applicant, organization, document_path, document_name, document_size)
      values (actor, org, path, doc_name, size_bytes) returning * into requested;
    return requested.id;
  end if;

  if operation not in ('approve', 'reject', 'revoke') or not donaplus.is_admin() then
    raise exception 'La revisión requiere una cuenta administradora.' using errcode = '42501';
  end if;

  if operation = 'revoke' then
    person := (payload ->> 'user_id')::uuid;
  else
    select applicant into person from donaplus.intermediary_requests
      where id = (payload ->> 'id')::uuid;
  end if;
  if person is null then raise exception 'No se encontró la solicitud.'; end if;
  perform 1 from donaplus.profiles where id = person for update;

  if operation = 'revoke' then
    select * into requested from donaplus.intermediary_requests
      where applicant = person and state = 'aprobada' for update;
    if not found then raise exception 'La cuenta no tiene una autorización activa.'; end if;
    next_state := 'revocada';
    notice := 'Se revocó tu autorización como intermediario comunitario.';
    with withdrawn as (
      update donaplus.publications set state = 'retirada'
      where author = person and beneficiary_alias is not null and state = 'activa'
      returning id
    )
    update donaplus.proposals set state = 'rechazada',
      rejection = 'Se revocó la autorización del intermediario.'
    where publication in (select id from withdrawn) and state = 'pendiente';
  else
    select * into requested from donaplus.intermediary_requests
      where id = (payload ->> 'id')::uuid and state = 'pendiente' for update;
    if not found then raise exception 'La solicitud ya fue atendida.'; end if;
    if operation = 'approve' then
      next_state := 'aprobada';
      notice := 'Se aprobó tu solicitud de intermediario comunitario.';
    else
      if decision_reason is null or char_length(decision_reason) > 500 then
        raise exception 'Escribe un motivo de rechazo de hasta 500 caracteres.';
      end if;
      next_state := 'rechazada';
      notice := 'Se rechazó tu solicitud de intermediario comunitario.';
    end if;
  end if;

  update donaplus.intermediary_requests
    set state = next_state, decided_at = now(), reviewer = actor,
        reason = case when operation = 'reject' then decision_reason end
    where id = requested.id;
  insert into donaplus.notifications(recipient, kind, event_key, message)
    values (person, 'decisionRolIntermediario', 'intermediary:' || requested.id || ':' || next_state, notice);
  return requested.id;
end
$$;
revoke all on function donaplus.manage_intermediary(text, jsonb) from public, anon, authenticated;
grant execute on function donaplus.manage_intermediary(text, jsonb) to authenticated;

create function public.komuna_manage_intermediary(operation text, payload jsonb) returns uuid
language sql security invoker set search_path = ''
as $$
  select donaplus.manage_intermediary(operation, payload)
$$;
revoke all on function public.komuna_manage_intermediary(text, jsonb) from public, anon, authenticated;
grant execute on function public.komuna_manage_intermediary(text, jsonb) to authenticated;

create function donaplus.write_with_intermediary(operation text, payload jsonb) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  beneficiary text := nullif(trim(payload ->> 'beneficiary_alias'), '');
  item_id uuid;
begin
  if operation in ('publish', 'edit') and payload ? 'beneficiary_alias' then
    if beneficiary is not null then
      perform 1 from donaplus.profiles where id = actor for update;
      if not exists (
        select 1 from donaplus.intermediary_requests
        where applicant = actor and state = 'aprobada'
      ) then
        raise exception 'Necesitas autorización de intermediario para publicar en nombre de otra persona.'
          using errcode = '42501';
      end if;
      if payload ->> 'kind' is distinct from 'necesidad' or char_length(beneficiary) > 80 then
        raise exception 'Escribe un alias de beneficiario de hasta 80 caracteres.';
      end if;
    end if;
    item_id := donaplus.write(operation, payload);
    if beneficiary is not null and not exists (
      select 1 from donaplus.publications where id = item_id and kind = 'necesidad'
    ) then
      raise exception 'El alias del beneficiario solo corresponde a una necesidad.';
    end if;
    update donaplus.publications set beneficiary_alias = beneficiary where id = item_id;
    return item_id;
  end if;
  return donaplus.write(operation, payload);
end
$$;
revoke all on function donaplus.write_with_intermediary(text, jsonb) from public, anon, authenticated;
grant execute on function donaplus.write_with_intermediary(text, jsonb) to authenticated;

create or replace function public.donaplus_write(operation text, payload jsonb) returns uuid
language sql security invoker set search_path = ''
as $$
  select donaplus.write_with_intermediary(operation, payload)
$$;

create or replace function public.donaplus_snapshot() returns jsonb
language sql stable security invoker set search_path = ''
as $$
  select donaplus.snapshot() || jsonb_build_object(
    'reviews', donaplus.visible_reviews(),
    'intermediary', donaplus.intermediary_snapshot(),
    'intermediary_notices', (
      select coalesce(jsonb_agg(n order by n.created_at desc, n.id), '[]')
      from donaplus.notifications n
      where n.recipient = (select auth.uid()) and n.kind = 'decisionRolIntermediario'
    ),
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
        and notice.publication is not null
    )
  )
$$;


