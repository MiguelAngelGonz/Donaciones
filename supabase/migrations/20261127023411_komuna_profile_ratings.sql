create function donaplus.snapshot_with_ratings() returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  base jsonb := donaplus.snapshot();
  rated_profiles jsonb;
begin
  select coalesce(jsonb_agg(profile || jsonb_build_object(
    'average_rating', rating.average,
    'review_count', rating.total
  )), '[]') into rated_profiles
  from jsonb_array_elements(coalesce(nullif(base -> 'profiles', 'null'), '[]')) as profile
  cross join lateral (
    select avg(r.rating) as average, count(*) as total
    from donaplus.reviews r
    where r.reviewed = (profile ->> 'id')::uuid
  ) rating;
  return jsonb_set(base, '{profiles}', rated_profiles);
end
$$;
revoke all on function donaplus.snapshot_with_ratings() from public, anon, authenticated;
grant execute on function donaplus.snapshot_with_ratings() to authenticated;


create or replace function public.donaplus_snapshot() returns jsonb
language sql stable security invoker set search_path = ''
as $$
  select donaplus.snapshot_with_ratings() || jsonb_build_object(
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
