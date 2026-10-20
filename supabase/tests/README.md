# Database tests

`Packages/ProgressCore/Tests/ProgressCoreTests/DatabaseIntegrationTests.swift` runs the real
sync engine against Postgres + PostgREST with the migrations applied. It checks two-device
sync, paging, stale-write rejection, conflict resolution, soft delete, and that row-level
security keeps one user's rows away from another.

It is skipped unless these variables are set:

| Variable | Value |
|---|---|
| `P1_INTEGRATION_URL` | PostgREST base URL, e.g. `http://127.0.0.1:3300` |
| `P1_TOKEN_A`, `P1_TOKEN_B` | HS256 JWTs signed with PostgREST's `jwt-secret`, `role: authenticated`, `sub` set to the two user ids in `local_supabase_stub.sql` |

Local setup (Postgres 16 or newer, PostgREST 12):

```sh
createdb p1
psql -d p1 -f supabase/tests/local_supabase_stub.sql   # local only, never on Supabase
psql -d p1 -f supabase/migrations/0001_foundation.sql
postgrest postgrest.conf    # db-uri for role "authenticator", db-anon-role = "anon"
cd Packages/ProgressCore && swift test
```
