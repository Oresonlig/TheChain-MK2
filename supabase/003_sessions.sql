-- The Chain MK2 — schema 003: en inloggning i taget (Niklas 2026-10-06).
-- Körs EN gång i Supabase → SQL Editor. Kan köras om utan skada. Bara LÄSNING:
-- listar den inloggade användarens ANDRA inloggningar (inte den som frågar).
-- Appen frågar direkt efter inloggning: finns andra → varning + val. Själva
-- utloggningen av de andra görs av Supabase (signOut scope=others), inte här.

create or replace function public.mk2_other_sessions()
returns table (
  user_agent  text,
  last_active timestamptz
)
language sql
security definer
set search_path = ''
stable
as $$
  select s.user_agent,
         -- refreshed_at är "timestamp" (UTC) i auth-schemat, de andra timestamptz.
         coalesce(s.refreshed_at::timestamptz, s.updated_at, s.created_at) as last_active
  from auth.sessions s
  where s.user_id = auth.uid()
    and s.id is distinct from nullif(auth.jwt() ->> 'session_id', '')::uuid
    and (s.not_after is null or s.not_after > now())
  order by 2 desc;
$$;

revoke all on function public.mk2_other_sessions() from public, anon;
grant execute on function public.mk2_other_sessions() to authenticated;
