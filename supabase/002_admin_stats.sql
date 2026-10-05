-- The Chain MK2 — schema 002: Niklas adminsida (2026-10-05).
-- Körs EN gång i Supabase → SQL Editor. Kan köras om utan skada. Bara LÄSNING:
-- rör ingen data, varken MK1 (app_state) eller MK2-tabellerna.
-- Spärr: bara niklgron@gmail.com får svar — alla andra får "not authorized".

create or replace function public.mk2_admin_stats()
returns table (
  email             text,
  display_name      text,
  created_at        timestamptz,
  last_sign_in_at   timestamptz,
  providers         text,
  web_updated_at    timestamptz,
  web_client_seen   jsonb,
  mk2_workouts      bigint,
  mk2_last_workout  bigint,
  mk2_last_activity bigint,
  mk2_devices       bigint,
  mk2_build         text,
  moved_at          timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'niklgron@gmail.com' then
    raise exception 'not authorized';
  end if;
  return query
    with stamps as (
      select user_id, stamp_ms, stamp_node from public.mk2_workouts
      union all select user_id, stamp_ms, stamp_node from public.mk2_program
      union all select user_id, stamp_ms, stamp_node from public.mk2_bodyweight
      union all select user_id, stamp_ms, stamp_node from public.mk2_notes
      union all select user_id, stamp_ms, stamp_node from public.mk2_exercises
      union all select user_id, stamp_ms, stamp_node from public.mk2_settings
    ),
    act as (
      select s.user_id, max(s.stamp_ms) as last_ms, count(distinct s.stamp_node) as devices
      from stamps s group by s.user_id
    ),
    w as (
      select x.user_id,
             count(*) as n,
             max((x.data -> 'workout' ->> 'end')::bigint) as last_end
      from public.mk2_workouts x
      where not x.deleted
        and coalesce(x.data ->> 'type', 'workout') = 'workout'
        and x.data -> 'workout' ? 'end'
      group by x.user_id
    )
    select
      u.email::text,
      coalesce(u.raw_user_meta_data ->> 'display_name', u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name')::text,
      u.created_at,
      u.last_sign_in_at,
      coalesce((select string_agg(distinct i.provider, ', ') from auth.identities i where i.user_id = u.id), '')::text,
      a.updated_at,
      a.data -> 'clientSeen',
      coalesce(w.n, 0),
      w.last_end,
      act.last_ms,
      coalesce(act.devices, 0),
      (st.data ->> 'appBuild')::text,
      m.migrated_at
    from auth.users u
    left join public.app_state a on a.id = u.id
    left join w on w.user_id = u.id
    left join act on act.user_id = u.id
    left join public.mk2_settings st on st.user_id = u.id and st.id = 'settings' and not st.deleted
    left join public.mk2_migration m on m.user_id = u.id
    order by greatest(coalesce(act.last_ms, 0), coalesce(extract(epoch from a.updated_at) * 1000, 0)::bigint) desc;
end;
$$;

revoke all on function public.mk2_admin_stats() from public, anon;
grant execute on function public.mk2_admin_stats() to authenticated;
