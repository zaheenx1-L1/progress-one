# Sync strategy

Spec Part 3.3–3.4: automatic two-way sync, offline-first, visible status, no silent overwrites, no duplicates.

## Record shape

Every synced table has these columns, maintained by the `p1_sync_stamp` trigger:

| Column | Set by | Meaning |
|---|---|---|
| `id` | device | UUID, created offline. Fixed UUIDs for the four default workspaces so every device creates the same record. |
| `user_id` | server | Owner, from the signed-in user. Row-level security only shows a user their own rows. |
| `version` | server | Starts at 1, +1 on every change. |
| `base_version` | device | The version the device's edit started from. |
| `updated_at` | server | `clock_timestamp()` of the last change. Drives the pull feed. |
| `deleted_at` | device | Soft delete, so deletions sync. |

Locally each SwiftData model also stores `syncBaseVersion`, `syncIsDirty`, `syncRevision` (increments per local edit), and `syncConflict` (the other device's copy while waiting for a decision).

## One sync pass (`SyncEngine.sync`)

1. **Push**, per table in order (workspaces, then tasks): for every dirty record not in conflict, upsert with `base_version`.
   - Accepted: store the new version; clear dirty only if no edit happened during the push (`syncRevision` check).
   - Rejected with `version_conflict` (HTTP 409): fetch the server copy. If it has the same content (lost response, or both devices created the same default), adopt it quietly. Otherwise store it as a **conflict**.
2. **Pull**, per table: read rows changed since the saved cursor, ordered by `(updated_at, id)`, 500 per page, using keyset pagination so rows sharing a timestamp are never skipped.
   - New to this device: insert. Newer and no local edit: apply. Same or older: ignore. Newer while the device has an unsent edit: **conflict**.

The database enforces the version rule, so even a buggy or old app version cannot overwrite a newer row.

## When it runs

- 2 seconds after any local edit (edits in a burst become one sync).
- When the app comes to the front, then every 60 seconds while open.
- When the network comes back.
- On demand: pull to refresh on iPhone, **⇧⌘R** or **Sync → Sync Now** on Mac, or **Sync now** in Sync Status.

iOS does not allow continuous background work, so the iPhone syncs when the app is open (spec Part 33 says not to promise more).

## Conflicts

A conflict never loses data: the device keeps its own edit, and the other copy is stored alongside it. **Sync Status → Needs your decision** shows both versions side by side with **Keep this device's** and **Keep other device's**. Keeping this device's version re-bases the edit on the server version and sends it; keeping the other replaces the local copy.

## Status shown to the user

| State | When |
|---|---|
| On this device only | Not signed in. Edits are kept and sent after sign-in. |
| Synced | Last pass succeeded, nothing waiting. |
| Syncing… | A pass is running. |
| Offline | No network, or the server could not be reached. |
| N changes waiting | Local edits not yet sent. |
| N conflicts need you | Records waiting for a decision. |
| Sync problem | Server error or expired sign-in, with the message. |

## Adding a new synced entity

1. Add a table to a new migration with the sync columns, and add it to the `foreach` block so it gets the trigger, index and policies.
2. Add a SwiftData model adopting `SyncedModel` with `syncFields()` and `applySyncFields(_:)`.
3. Add it to the schema in `AppEnvironment`, and to `SwiftDataLocalStore.tables`, `allRecords`, `find` and `insertNew`.
4. Add it to the database integration test.
