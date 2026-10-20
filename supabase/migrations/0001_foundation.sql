-- PROGRESS ONE: foundation schema (Step 1)
--
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste this file -> Run.
--
-- Every synced table shares the same sync columns:
--   id          uuid, created on the device so records can be made offline
--   user_id     owner, set by the server from the signed-in user
--   version     increases by 1 on every change, set by the server only
--   base_version  the version the device's edit was based on, sent by the device
--   updated_at  time of the last change, set by the server only
--   deleted_at  soft delete, so deletions reach the other device
--
-- An update must carry the version it was based on (base_version). If another device
-- changed the row first, the update is rejected with version_conflict (HTTP 409) and the
-- app asks the user which copy to keep. Nothing is silently overwritten.
--
-- base_version is a separate column because the app writes with
-- INSERT ... ON CONFLICT DO UPDATE, and Postgres passes BEFORE INSERT trigger changes
-- into EXCLUDED: the insert branch sets version = 1, so version cannot carry the base.
--
-- Synced tables deliberately have no foreign keys between them: each device works
-- offline and may send a child row before its parent arrives.

create or replace function public.p1_sync_stamp()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    new.version := 1;
    new.user_id := auth.uid();
    new.created_at := clock_timestamp();
  else
    if new.base_version is distinct from old.version then
      raise exception 'version_conflict'
        using errcode = 'PT409',
              detail = format('server version %s, client based on %s', old.version, new.base_version);
    end if;
    new.version := old.version + 1;
    new.user_id := old.user_id;
    new.created_at := old.created_at;
  end if;
  -- clock_timestamp (not now) so rows written in one transaction still get distinct times.
  new.updated_at := clock_timestamp();
  return new;
end;
$$;

-- Workspaces (spec Part 6) ---------------------------------------------------

create table if not exists public.workspaces (
  id          uuid primary key,
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  version     integer not null default 0,
  base_version integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz,

  name        text not null,
  kind        text not null default 'business' check (kind in ('business', 'personal')),
  symbol      text not null default 'briefcase',
  color_hex   text not null default '#0A84FF',
  sort_order  integer not null default 0,
  is_private  boolean not null default false,
  archived_at timestamptz
);

-- Tasks (spec Part 12) -------------------------------------------------------

create table if not exists public.tasks (
  id           uuid primary key,
  user_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  version      integer not null default 0,
  base_version integer not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz,

  workspace_id uuid,
  title        text not null,
  notes        text not null default '',
  status       text not null default 'todo' check (status in ('todo', 'in_progress', 'done', 'cancelled')),
  priority     integer not null default 2 check (priority between 1 and 4),
  due_at       timestamptz,
  completed_at timestamptz,
  sort_order   double precision not null default 0
);

-- Shared setup for every synced table ----------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array['workspaces', 'tasks'] loop
    execute format('create index if not exists %I on public.%I (user_id, updated_at, id)', t || '_sync_idx', t);

    execute format('drop trigger if exists p1_sync_stamp on public.%I', t);
    execute format('create trigger p1_sync_stamp before insert or update on public.%I
                    for each row execute function public.p1_sync_stamp()', t);

    execute format('alter table public.%I enable row level security', t);

    execute format('drop policy if exists "own rows: read" on public.%I', t);
    execute format('create policy "own rows: read" on public.%I for select to authenticated
                    using (user_id = auth.uid())', t);

    execute format('drop policy if exists "own rows: insert" on public.%I', t);
    execute format('create policy "own rows: insert" on public.%I for insert to authenticated
                    with check (user_id = auth.uid())', t);

    execute format('drop policy if exists "own rows: update" on public.%I', t);
    execute format('create policy "own rows: update" on public.%I for update to authenticated
                    using (user_id = auth.uid()) with check (user_id = auth.uid())', t);

    -- No delete policy: the app soft-deletes with deleted_at so the deletion syncs.
    execute format('revoke all on public.%I from anon', t);
    execute format('grant select, insert, update on public.%I to authenticated', t);
  end loop;
end;
$$;
