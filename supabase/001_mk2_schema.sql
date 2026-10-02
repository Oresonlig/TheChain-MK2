-- The Chain MK2 — schema 001 (beslut 2026-10-02: tabeller per entitet, "lagom grova").
-- Körs EN gång av Niklas i Supabase → SQL Editor. Rör INGET av MK1 (app_state,
-- write_app_state_cas, admin_stats lämnas orörda). Kan köras om utan skada.
--
-- Princip:
--   * En rad = en sak som ändras som helhet (ett pass, programmet, en vägning …).
--   * Varje rad bär en stämpel (tid, räknare, enhet). Servern accepterar bara en
--     skrivning med NYARE stämpel än den lagrade = MK1:s CAS-skydd, fast per post.
--     Blind upsert finns inte.
--   * Läsning: bara egna rader (RLS). Skrivning: bara via mk2_push().
--   * `rev` = global löpnummerserie; klienten hämtar "allt nyare än rev X".

-- ── 1. Löpnummer för synk-hämtning ─────────────────────────────────────────
create sequence if not exists public.mk2_rev_seq;

-- ── 2. De sex tabellerna (samma form) ──────────────────────────────────────
--   mk2_workouts   en rad = ett pass (övningar + set som JSON i `data`)
--   mk2_program    en rad = användarens program (id 'program')
--   mk2_bodyweight en rad = en vägning (id = datum YYYY-MM-DD)
--   mk2_notes      en rad = en anteckning
--   mk2_exercises  en rad = en egen övning eller en justering av en biblioteksövning
--   mk2_settings   en rad = inställningarna (id 'settings')
do $$
declare
  t text;
begin
  foreach t in array array['mk2_workouts','mk2_program','mk2_bodyweight','mk2_notes','mk2_exercises','mk2_settings']
  loop
    execute format($f$
      create table if not exists public.%I (
        user_id       uuid    not null references auth.users(id) on delete cascade,
        id            text    not null check (length(id) between 1 and 200),
        stamp_ms      bigint  not null,
        stamp_counter integer not null default 0,
        stamp_node    text    not null check (length(stamp_node) between 1 and 100),
        deleted       boolean not null default false,
        data          jsonb,
        rev           bigint  not null default nextval('public.mk2_rev_seq'),
        primary key (user_id, id)
      )$f$, t);
    execute format('create index if not exists %I on public.%I (user_id, rev)', t || '_rev', t);
    -- RLS: varje användare ser bara sina egna rader.
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists own_rows_select on public.%I', t);
    execute format('create policy own_rows_select on public.%I for select to authenticated using (user_id = auth.uid())', t);
    -- Inga direkta skrivningar för någon klient — bara via mk2_push().
    execute format('revoke all on public.%I from anon, authenticated', t);
    execute format('grant select on public.%I to authenticated', t);
  end loop;
end $$;

-- ── 3. Skrivfunktionen ─────────────────────────────────────────────────────
-- Tar en lista rader för EN tabell. Varje rad skrivs bara om dess stämpel är
-- nyare än den lagrade. Svaret säger vilka som togs emot och vilka som var
-- inaktuella (klienten hämtar då serverns version och slår ihop).
-- `collate "C"` = samma strängjämförelse som appen (Dart), oavsett databasens språk.
create or replace function public.mk2_push(p_table text, p_rows jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid      uuid := auth.uid();
  r        jsonb;
  is_del   boolean;
  n        integer;
  accepted text[] := '{}';
  stale    text[] := '{}';
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;
  if p_table not in ('mk2_workouts','mk2_program','mk2_bodyweight','mk2_notes','mk2_exercises','mk2_settings') then
    raise exception 'unknown table %', p_table;
  end if;
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) > 500 then
    raise exception 'bad payload';
  end if;

  for r in select value from jsonb_array_elements(p_rows) loop
    is_del := coalesce((r->>'deleted')::boolean, false);
    execute format($f$
      insert into public.%I as t (user_id, id, stamp_ms, stamp_counter, stamp_node, deleted, data, rev)
      values ($1, $2, $3, $4, $5, $6, $7, nextval('public.mk2_rev_seq'))
      on conflict (user_id, id) do update
        set stamp_ms = excluded.stamp_ms,
            stamp_counter = excluded.stamp_counter,
            stamp_node = excluded.stamp_node,
            deleted = excluded.deleted,
            data = excluded.data,
            rev = excluded.rev
        where (excluded.stamp_ms, excluded.stamp_counter, excluded.stamp_node collate "C")
            > (t.stamp_ms, t.stamp_counter, t.stamp_node collate "C")
    $f$, p_table)
    using uid,
          r->>'id',
          (r->>'stamp_ms')::bigint,
          coalesce((r->>'stamp_counter')::integer, 0),
          r->>'stamp_node',
          is_del,
          case when is_del then null else r->'data' end;
    get diagnostics n = row_count;
    if n > 0 then
      accepted := accepted || (r->>'id');
    else
      stale := stale || (r->>'id');
    end if;
  end loop;

  return jsonb_build_object('accepted', to_jsonb(accepted), 'stale', to_jsonb(stale));
end;
$$;

revoke all on function public.mk2_push(text, jsonb) from public, anon;
grant execute on function public.mk2_push(text, jsonb) to authenticated;

-- ── 4. Killswitch-markering ────────────────────────────────────────────────
-- En rad per användare som flyttat till MK2 (engångsimporten skriver den).
-- Hemsidan läser den vid inloggning och visar "This account has moved to the app".
-- Ångra (tillbaka till MK1): radera raden i Supabase-dashboarden.
create table if not exists public.mk2_migration (
  user_id            uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  migrated_at        timestamptz not null default now(),
  source_app_version text
);
alter table public.mk2_migration enable row level security;
drop policy if exists own_select on public.mk2_migration;
create policy own_select on public.mk2_migration for select to authenticated using (user_id = auth.uid());
drop policy if exists own_insert on public.mk2_migration;
create policy own_insert on public.mk2_migration for insert to authenticated with check (user_id = auth.uid());
revoke all on public.mk2_migration from anon, authenticated;
grant select, insert on public.mk2_migration to authenticated;
