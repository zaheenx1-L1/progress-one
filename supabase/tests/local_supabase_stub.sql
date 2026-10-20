-- Minimal stand-in for the parts of Supabase the migrations rely on, so they can be tested
-- against a plain local Postgres + PostgREST. Never run this on the real Supabase project.

create schema if not exists auth;

create table if not exists auth.users (
  id uuid primary key,
  email text
);

-- Same definition Supabase uses: the signed-in user's id from the request's JWT.
create or replace function auth.uid() returns uuid
language sql stable
as $$
  select nullif(
    coalesce(
      current_setting('request.jwt.claim.sub', true),
      (current_setting('request.jwt.claims', true)::jsonb ->> 'sub')
    ),
    ''
  )::uuid
$$;

do $$
begin
  if not exists (select from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select from pg_roles where rolname = 'authenticator') then
    create role authenticator login password 'authenticator' noinherit;
  end if;
end;
$$;

grant anon, authenticated to authenticator;
grant usage on schema public, auth to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;

insert into auth.users (id, email) values
  ('11111111-1111-4111-8111-111111111111', 'device-owner@example.com'),
  ('22222222-2222-4222-8222-222222222222', 'someone-else@example.com')
on conflict do nothing;
