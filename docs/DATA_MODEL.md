# Data model

Spec Part 36 lists 52 core entities. This file grows as each one is built. Status: **Built** (in the app and database), **Planned** (designed, not built).

## Built in Step 1

### Workspace (`workspaces`)

| Field | Type | Notes |
|---|---|---|
| name | text | |
| kind | text | `business` or `personal` |
| symbol | text | SF Symbol name |
| color_hex | text | `#RRGGBB` |
| sort_order | integer | |
| is_private | boolean | Kept out of business views and shared reports (spec Part 18) |
| archived_at | timestamptz | Archive instead of delete |

Defaults created on first launch with fixed ids: iExpert Technologies, iExpert Training Academy, Greentick Real Estate, Personal Life (private).

### Task (`tasks`)

| Field | Type | Notes |
|---|---|---|
| workspace_id | uuid | Optional |
| title, notes | text | |
| status | text | `todo`, `in_progress`, `done`, `cancelled` |
| priority | integer | 1 low … 4 critical |
| due_at, completed_at | timestamptz | Stored in UTC, shown in the user's time zone (default Asia/Dubai) |
| sort_order | double | |

Plus the sync columns in [SYNC_STRATEGY.md](SYNC_STRATEGY.md).

## Money rule for later steps

Money will be stored as **integer minor units** (fils for AED) with a currency code, never as floating point, and every money record will carry its kind (target, forecast, expected, earned, received) so reports never mix them (spec Parts 8, 10, 38).

## Planned (Steps 2–4)

User profile and preferences, Life Category, Life Vision, Goal, Goal Milestone, Goal Metric, Goal Progress Record, Goal Revision, Task Recurrence, Project, Project Milestone, Calendar Event, Contact, Company, Lead, Opportunity, Pipeline, Deal Stage, CRM Activity, Property, Transaction, Commission, Revenue Record, Expense Record, Financial Target, Habit, Habit Check-in, Fitness Record, Skill, Skill Assessment, Practice Session, Book, Reading Session, Learning Resource, Learning Activity, Spiritual Routine, Personal Reflection, Coaching Conversation, AI Recommendation, Notification, Automation Rule, Assessment, KPI Definition, KPI Measurement, Generated Report, Attachment, Audit Event.

Regional preferences (time zone, currency, first weekday) and the app lock setting are stored per device in Step 1; they move to a synced profile in Step 2.
