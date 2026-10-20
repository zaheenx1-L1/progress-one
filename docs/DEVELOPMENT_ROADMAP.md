# Development roadmap

The spec's ten milestones (Part 42), grouped into four steps agreed with the owner on 2026-10-20. Each step ends with working software on both devices.

## Step 1: Foundation (spec M1 + M2) — in review

- Feature traceability matrix, architecture decisions, sync design, data model, install guide.
- Xcode project: one app for iPhone and Mac. Shared core package with tests.
- Supabase schema with row-level security and server-enforced versions.
- Email sign-in, local database, two-way sync with offline queue and conflict resolution, sync status screen.
- Workspaces (the four defaults plus create, edit, archive), tasks (create, edit, complete, delete, filters), Today screen with quick add, Face ID / Touch ID lock, region settings.
- Proof: acceptance tests A, B, H, I, J simulated in tests against a real Postgres; to be repeated on the real devices.

## Step 2: First full daily system (spec M3 + core of M6)

- Daily Command Center: morning briefing, daily timeline, priority engine with explanations, evening review.
- Tasks complete: recurrence, checklists, dependencies, time tracking, Kanban and priority matrix.
- Projects with milestones. Calendar day/week/month with Apple Calendar and Reminders.
- My Life Blueprint, goal categories, goal hierarchy (annual → daily), goal wizard (manual), habits with streaks and heatmaps.
- Synced user profile and preferences.

## Step 3: Business and money (spec M4 + M5)

- Unified CRM: contacts, companies, leads, opportunities, pipelines, follow-up lists, call/email/WhatsApp links.
- Greentick: properties, transactions, commission tracking (expected vs earned vs received), AED targets.
- iExpert Technologies and Training Academy dashboards and targets.
- Personal finance goals; consolidated executive dashboard without double counting.

## Step 4: Life modules, assessments, AI and automation (spec rest of M6, M7–M10)

- Fitness (with optional Apple Health), communication practice and assessments, reading library, learning content and programs, spiritual routines, family and personal life, growth journey.
- Weekly, monthly, quarterly and annual reports; chart engine; My Life Compass; PDF/CSV export.
- Progress AI mentor via a Supabase Edge Function (needs owner's API cost decision).
- Automation rules, notifications with quiet hours, widgets and Siri shortcuts.
- Final QA: all acceptance tests A–L on the real iPhone and MacBook, security review, backup and restore check.
