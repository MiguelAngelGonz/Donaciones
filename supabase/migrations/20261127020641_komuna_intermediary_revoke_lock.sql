create or replace function donaplus.manage_intermediary(operation text, payload jsonb) returns uuid
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
    -- Include reserved needs so a concurrent cancellation cannot reactivate one unnoticed.
    perform 1 from donaplus.publications
    where author = person and beneficiary_alias is not null and state in ('activa', 'reservada')
    order by id for update;
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

