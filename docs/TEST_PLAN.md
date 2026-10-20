# Test plan

## Automated

| Suite | Runs where | Covers |
|---|---|---|
| `SyncEngineTests` | Linux and macOS (`swift test` in `Packages/ProgressCore`) | Two simulated devices on an in-memory server with the database's version rules: acceptance tests A, B, H, I, plus conflict resolution both ways, deletion, edit-during-push, lost responses, shared defaults, paging with identical timestamps. |
| `SupabaseClientTests` | Linux and macOS | Exact requests sent to Supabase Auth and PostgREST, error mapping (409 conflict, 401), session parsing, keyset query encoding. |
| `DomainTests` | Linux and macOS | Timestamp parsing, conflict decisions, task buckets (unfinished tasks stay visible), Asia/Dubai day boundaries, configurable week start, default workspaces. |
| `DatabaseIntegrationTests` | Any machine with Postgres + PostgREST (see `supabase/tests/README.md`) | The real migration: two devices syncing, paging, stale writes rejected by the database, conflict resolution, soft delete, row-level security between two users. |
| CI app build | GitHub Actions `macos-15` | Compiles the app for iOS Simulator and macOS. |

Results for Step 1 (2026-10-20): 35 of 35 core and database tests pass on Swift 6.1 (Linux) with Postgres 16 and PostgREST 12.2.

## Manual, on the real devices (spec Part 41)

| Test | Steps | Step 1 status |
|---|---|---|
| A | Create a task on the Mac; it appears on the iPhone. | To do on devices |
| B | Complete it on the iPhone; the Mac updates. | To do on devices |
| C–G, K, L | CRM, commissions, fitness, reading, reports, annual report, privacy in exports. | Later steps |
| H | Turn on Airplane Mode on the iPhone, add and edit tasks, turn it off; changes reach the Mac. | To do on devices |
| I | Turn off Wi-Fi on both, edit the same task differently on each, reconnect; a conflict appears and either choice resolves it. | To do on devices |
| J | Quit and reopen both apps; everything is still there. | To do on devices |
| Lock | Turn on the app lock; the app asks for Face ID / Touch ID when reopened. | To do on devices |
