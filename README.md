# PROGRESS ONE

**One Life. One System. Continuous Growth.**

A personal life operating system for iPhone and Mac: tasks and daily planning, business CRM, financial goals, life goals and habits, assessments, and an AI mentor, kept in sync between your devices.

The full requirements are in [`docs/spec/PROGRESS_ONE_MASTER_SPEC.txt`](docs/spec/PROGRESS_ONE_MASTER_SPEC.txt). What is built so far, and what is planned, is tracked in [`docs/FEATURE_MATRIX.md`](docs/FEATURE_MATRIX.md).

## Current stage: Step 1, foundation

Working in this version: sign-in, two-way sync with offline support and conflict resolution, workspaces, tasks, the first Today screen, and Face ID / Touch ID lock. See [`docs/IMPLEMENTATION_STATUS.md`](docs/IMPLEMENTATION_STATUS.md).

## Install

Follow [`docs/DEPLOYMENT_GUIDE.md`](docs/DEPLOYMENT_GUIDE.md). In short: Xcode 26 on the Mac, a free Supabase project, then run from Xcode on the Mac and on the iPhone.

## Project layout

| Path | What it is |
|---|---|
| `ProgressOne.xcodeproj` | The Xcode project. One app target that builds for iPhone and Mac. |
| `ProgressOne/` | App source: models, services, and screens. |
| `Packages/ProgressCore/` | Shared logic and the sync engine, with tests. |
| `supabase/migrations/` | Database schema to run in Supabase. |
| `supabase/tests/` | How to run the database integration tests locally. |
| `docs/` | Architecture, sync design, data model, roadmap, test plan, known issues. |

## Run the tests

```sh
cd Packages/ProgressCore
swift test
```

Database integration tests are skipped unless a local Postgres + PostgREST is running; see `supabase/tests/README.md`.
