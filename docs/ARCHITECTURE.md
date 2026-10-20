# Architecture

## Overview

```
┌────────────── iPhone app ─────────────┐   ┌────────────── Mac app ──────────────┐
│ SwiftUI views (tabs)                  │   │ SwiftUI views (sidebar, menus)      │
│ SwiftData local database              │   │ SwiftData local database            │
│ SyncCoordinator → SyncEngine ─────────┼─┐ │ SyncCoordinator → SyncEngine ───────┼─┐
└───────────────────────────────────────┘ │ └─────────────────────────────────────┘ │
                                          ▼                                         ▼
                       ┌──────────── Supabase (free tier) ─────────────┐
                       │ Auth (email + password)                       │
                       │ PostgREST API → Postgres                      │
                       │   row-level security: each user sees own rows │
                       │   p1_sync_stamp trigger: versions, timestamps │
                       └───────────────────────────────────────────────┘
```

One Xcode target builds both apps from the same source (`ProgressOne/`). Layout differs per platform with `#if os(...)`; models and logic are shared.

| Layer | Where | Notes |
|---|---|---|
| Domain and sync logic | `Packages/ProgressCore` | Pure Swift, no Apple-only frameworks, so it is tested on Linux in CI and against a real Postgres. |
| Local persistence | `ProgressOne/Models`, `Services/SwiftDataLocalStore.swift` | SwiftData. Every synced model adopts `SyncedModel`. |
| Sync orchestration | `Services/SyncCoordinator.swift` | When to sync, status for the UI, conflict decisions. |
| Auth | `Services/AuthStore.swift`, `ProgressCore/Supabase/SupabaseAuth.swift` | Session stored in the Keychain. |
| UI | `ProgressOne/Features` | iPhone: Today, Business, Goals, Progress, AI Mentor tabs. Mac: sidebar. |
| Server schema | `supabase/migrations` | Plain SQL, run in the Supabase SQL editor. |

## ADR-001: Supabase instead of CloudKit

**Status:** accepted 2026-10-20.

**Context.** The spec (Part 3.5) asks to choose between SwiftUI + CloudKit and SwiftUI + Supabase. The owner uses a **free Apple ID** and does not want the paid Apple Developer Program for now. CloudKit and the iCloud entitlement need the paid program, so CloudKit is not available.

**Decision.** Local SwiftData on each device, with Supabase (Postgres) as the single cloud source of truth. The owner chose this on 2026-10-20.

**Consequences.**
- Works with a free Apple ID; Supabase free tier costs nothing.
- Postgres gives real reporting queries later (spec Parts 23–27) and server-side jobs for automation (Part 33).
- The AI mentor (Part 20) can run as a Supabase Edge Function so the API key never ships in the app (Part 37).
- We maintain the sync engine ourselves. It is covered by unit tests and by integration tests against a real Postgres + PostgREST.
- Free projects pause after a week of inactivity and need a click to restore.
- Sign in with Apple and remote push notifications need the paid program; email sign-in and local notifications are used instead.
- If the owner later pays for the program, CloudKit is still not needed; Supabase stays the source of truth.

## ADR-002: One multiplatform target, Swift 5 language mode for the app

The app target supports `iphoneos iphonesimulator macosx` (iOS 18+, macOS 15+), so both apps always have the same features and data model. The app target uses Swift 5 language mode to avoid strict-concurrency churn in SwiftUI code; the core package uses Swift 6 mode with full concurrency checking.

## ADR-003: No foreign keys between synced tables

Each device works offline and may send a child row (a task) before its parent (a workspace) reaches the server. Relationships are stored as ids and checked in the app.

## Deployment targets

- iOS 18.0: the iPhone 13 Pro Max runs iOS 26 and later, so this does not limit it, and it keeps the app installable from Xcode 26.
- macOS 15.0: the highest macOS for a 2018 MacBook Pro is Sequoia 15.
