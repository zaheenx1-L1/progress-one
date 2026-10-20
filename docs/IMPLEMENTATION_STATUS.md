# Implementation status

_Last updated: 2026-10-20, Step 1._

## Implemented (code written)

- Xcode project for iPhone (iOS 18+) and Mac (macOS 15+) from one codebase, with app icon.
- `ProgressCore` package: sync engine, conflict policy, Supabase Auth and PostgREST clients, timestamps, task and workspace rules, regional preferences.
- Supabase migration `0001_foundation.sql`: workspaces and tasks, server-enforced versions, row-level security.
- App: welcome and sign-in, on-this-device-only mode, Today (greeting, quick add, overdue and today lists), task list with filters, task editor, workspaces (four defaults plus create, edit, archive), sync status with conflict resolution, settings (account, app lock, time zone, currency, week start), Face ID / Touch ID lock, Mac menus and shortcuts.

## Tested

- 35 automated tests pass (Linux, Swift 6.1), including the real migration on Postgres 16 + PostgREST 12.2: two-device sync, offline queue, conflicts, paging, deletion, and privacy between users.
- The app's SwiftUI code has **not** been compiled or run yet. The CI job on GitHub's macOS runner is the first compile; then it needs a run on your iPhone and Mac.

## Pending

- Compile check in CI, and fixes if needed.
- Owner setup: Xcode 26, Supabase project, first install on both devices.
- Real-device acceptance tests A, B, H, I, J and the app lock (see TEST_PLAN.md).
- Steps 2–4 (see DEVELOPMENT_ROADMAP.md and FEATURE_MATRIX.md).

## Open issues

See KNOWN_ISSUES.md. The biggest risk is KI-1: Xcode 26 is the newest Xcode the 2018 MacBook Pro can run, which may not support installing on an iPhone updated to iOS 27.

## Next action

Merge the Step 1 pull request once CI is green, then follow DEPLOYMENT_GUIDE.md.
