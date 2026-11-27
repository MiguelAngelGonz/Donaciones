create table donaplus.reviews (
  id uuid primary key default gen_random_uuid(),
  donation uuid not null references donaplus.donations(id),
  author uuid not null references donaplus.profiles(id),
  reviewed uuid not null references donaplus.profiles(id),
  rating integer not null check (rating between 1 and 5),
  comment text check (char_length(comment) <= 500),
  created_at timestamptz not null default now(),
  unique (donation, author),
  check (author <> reviewed)
);

create index reviews_author on donaplus.reviews(author);
create index reviews_reviewed on donaplus.reviews(reviewed);
alter table donaplus.reviews enable row level security;
revoke all on donaplus.reviews from public, anon, authenticated;

create function donaplus.visible_reviews() returns jsonb
language sql stable security definer set search_path = ''
as $$
  select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc, r.id), '[]')
  from donaplus.reviews r
  where (select auth.uid()) in (r.author, r.reviewed)
$$;
revoke all on function donaplus.visible_reviews() from public, anon, authenticated;
grant execute on function donaplus.visible_reviews() to authenticated;

create or replace function public.donaplus_snapshot() returns jsonb
language sql stable security invoker set search_path = ''
as $$
  select donaplus.snapshot() || jsonb_build_object('reviews', donaplus.visible_reviews())
$$;
revoke all on function public.donaplus_snapshot() from public, anon, authenticated;
grant execute on function public.donaplus_snapshot() to authenticated;

create function donaplus.submit_review(
  donation_id uuid,
  stars integer,
  feedback text
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target donaplus.donations%rowtype;
  result donaplus.reviews%rowtype;
  clean_feedback text := nullif(trim(feedback), '');
begin
  if actor is null then
    raise exception 'Inicia sesión para dejar una reseña.' using errcode = '42501';
  end if;

  select * into target
  from donaplus.donations
  where id = donation_id and actor in (donor, recipient)
  for update;
  if not found then
    raise exception 'Solo los participantes pueden reseñar esta donación.' using errcode = '42501';
  end if;

  if target.state <> 'finalizada' then
    raise exception 'Solo puedes reseñar una donación finalizada.';
  end if;

  select * into result from donaplus.reviews
  where donation = donation_id and author = actor;
  if found then
    if result.rating = stars and result.comment is not distinct from clean_feedback then
      return to_jsonb(result);
    end if;
    raise exception 'Ya enviaste una reseña para esta donación.';
  end if;

  if target.finished_at is null or now() >= target.finished_at + interval '360 hours' then
    raise exception 'El plazo de 14 días para reseñar esta donación ha vencido.';
  end if;
  if stars is null or stars not between 1 and 5 then
    raise exception 'La calificación debe estar entre 1 y 5 estrellas.';
  end if;
  if char_length(clean_feedback) > 500 then
    raise exception 'El comentario no puede superar los 500 caracteres.';
  end if;

  insert into donaplus.reviews (donation, author, reviewed, rating, comment)
  values (
    target.id, actor,
    case when actor = target.donor then target.recipient else target.donor end,
    stars, clean_feedback
  )
  returning * into result;
  return to_jsonb(result);
end;
$$;
revoke all on function donaplus.submit_review(uuid, integer, text)
from public, anon, authenticated;
grant execute on function donaplus.submit_review(uuid, integer, text) to authenticated;

create function public.komuna_submit_review(donation_id uuid, rating integer, comment text default null)
returns jsonb
language sql security invoker set search_path = ''
as $$ select donaplus.submit_review(donation_id, rating, comment) $$;
revoke all on function public.komuna_submit_review(uuid, integer, text)
from public, anon, authenticated;
grant execute on function public.komuna_submit_review(uuid, integer, text) to authenticated;
