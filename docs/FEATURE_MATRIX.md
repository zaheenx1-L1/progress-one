# PROGRESS ONE — Feature Traceability Matrix

Source: PROGRESS ONE Master Development Specification (46 parts), copied in `docs/spec/`. Version 0.2, 2026-10-20 (Step 1).

**Status legend:** **Built** is fully coded, **Partial** has its first part coded with the rest planned, **Planned** is not started. Coded is not the same as confirmed: until the Tests column says otherwise, a feature has not yet been run on your devices. **Tests:** *Automated: pass* means covered by the passing test suite; *Awaiting device test* means it still needs checking on your iPhone and Mac. This file is updated at every step, and no feature is removed without a recorded decision.

## Decisions and constraints this matrix assumes

| Topic | Decision | Effect |
|---|---|---|
| Mac | 15-inch 2018 MacBook Pro (Intel). Highest macOS: Sequoia 15 | Build with Xcode 26 on Sequoia. Mac app targets macOS 15 |
| iPhone | iPhone 13 Pro Max | App targets iOS 18, so it isn't tied to the newest iOS |
| Apple account | Free Apple ID (no paid Developer Program, decided 2026-10-20) | iPhone install must be refreshed every 7 days from Xcode. No iCloud/CloudKit, remote push, or Sign in with Apple. Can be upgraded later |
| Sync | Supabase (PostgreSQL) free tier (decided 2026-10-20) | Local SwiftData store on each device, with an outbox that syncs to Supabase. One cloud source of truth |
| AI mentor | Claude API called via a Supabase Edge Function | The API key stays on the server. **Open question:** Anthropic API usage is paid per use |

## Milestones (spec Part 42) mapped to our 4-step plan

| Our step | Spec milestones | Content |
|---|---|---|
| Step 1 Foundation | M1, M2 | Blueprint docs, Xcode project, data model, auth, local store, Supabase sync, workspaces, navigation, sync test |
| Step 2 First installable app | M3 + habits/goals core from M6 | Tasks, projects, calendar, home dashboard, daily review, goals, habits |
| Step 3 Business and money | M4, M5 | CRM, Greentick, iExpert, academy, commissions, personal finance |
| Step 4 Intelligence and reports | rest of M6, M7, M8, M9, M10 | Life modules, assessments, charts, Life Compass, AI mentor, automation, notifications, deployment |

Priority: **P0** = required by the spec's non-negotiable rules, **P1** = core experience, **P2** = convenience, **P3** = later integration.

## Requirements

| ID | Part | Requirement | Priority | Milestone | Main screens | Data models | Status | Tests | Notes |
|---|---|---|---|---|---|---|---|---|---|
| F-001 | 2 | Goal cascade: identity → 10y vision → 5y → 3y → annual → quarterly → monthly → weekly → daily → actuals → assessments → AI → improvement, as the real data model | P0 | M6 | Life Blueprint, Annual/Quarterly/Monthly/Weekly Planner | LifeVision, Goal, GoalMilestone | Planned | Not tested | Core architecture; Goal.parent link plus period field |
| F-002 | 2 | Every daily activity can link to a larger goal or responsibility | P0 | M3 | Task Details, Goal Details | Task, Goal (many-to-many) | Planned | Not tested |  |
| F-003 | 3 | Native iPhone app (SwiftUI, iOS navigation, one-handed use) | P0 | M2 | All iPhone screens | — | Partial (Step 1) | Awaiting device test | Deploy target iOS 18; iPhone 13 Pro Max supports iOS 26; Shell, tabs, Today, tasks, workspaces built |
| F-004 | 3 | Face ID app lock | P1 | M2 | Settings and Privacy | UserPreferences | Built (Step 1) | Awaiting device test | LocalAuthentication; works with free Apple ID; Face ID / Touch ID / passcode lock in Settings |
| F-005 | 3 | Voice-assisted task capture | P2 | M9 | Quick Add | Task | Planned | Not tested | Speech framework, on-device |
| F-006 | 3 | Light and dark modes | P0 | M2 | All | — | Built (Step 1) | Awaiting device test | Follows the system setting |
| F-007 | 3 | Native macOS app: sidebar, multi-column, data tables, keyboard shortcuts, menus/toolbar, multiple windows | P0 | M2 | All Mac screens | — | Partial (Step 1) | Awaiting device test | Deploy target macOS 15 (2018 MacBook Pro max is Sequoia 15); Sidebar, menus, ⌘N, ⇧⌘R, Settings window built |
| F-008 | 3 | Mac drag-and-drop, document management, export and print | P1 | M7 | Reports, Attachments | Attachment, GeneratedReport | Planned | Not tested |  |
| F-009 | 3 | Automatic two-way sync of all 19 record types listed in 3.3 | P0 | M2 | Synchronization Status | SyncState + every entity | Partial (Step 1) | Automated: pass | Supabase (user decision 2026-10-20); CloudKit needs paid program; Workspaces and tasks sync; other record types added with their modules |
| F-010 | 3 | Offline-first: full read and write offline, auto-sync on reconnect | P0 | M2 | All | SyncState, local SwiftData store | Built (Step 1) | Automated: pass | Local store is the device source of truth; outbox queue; Local SwiftData store, outbox via dirty flags, sync on reconnect |
| F-011 | 3 | Visible sync states: Synced, Syncing, Offline, Pending, Conflict, Error | P0 | M2 | Synchronization Status | SyncState | Built (Step 1) | Awaiting device test | Sync Status screen and badge |
| F-012 | 3 | Conflict handling with no silent overwrite or duplicates | P0 | M2 | Synchronization Status | SyncState, AuditEvent | Built (Step 1) | Automated: pass | Per-record version + updated_at; conflicts surfaced to user; Server-enforced versions; side-by-side conflict resolution |
| F-013 | 3 | Architecture decision record: CloudKit vs Supabase | P0 | M1 | — | — | Built (Step 1) | — | Decided: Supabase/PostgreSQL, single source of truth in cloud, local cache per device; docs/ARCHITECTURE.md ADR-001 |
| F-014 | 3 | Installation and deployment package (Xcode project, targets, backend setup, migrations, signing, device install, backup) | P0 | M10 | — | — | Partial (Step 1) | — | Free Apple ID: iPhone builds expire after 7 days; docs/DEPLOYMENT_GUIDE.md, Xcode project, migration |
| F-015 | 3 | Real Mac compatibility check | P0 | M1 | — | — | Built (Step 1) | — | 15" 2018 MacBook Pro, Intel; max macOS Sequoia 15; Xcode 26; Checked against owner's model; Xcode 26 is the limit (KI-1) |
| F-016 | 4 | My Life Blueprint: 12 guided questions, answered progressively | P0 | M6 | Life Blueprint, Onboarding | LifeVision, Profile | Planned | Not tested |  |
| F-017 | 4 | Current life baseline per category (current, desired, indicators, reasons, resources, constraints, timeframe) | P0 | M6 | Life Blueprint | LifeCategory, LifeVision | Planned | Not tested |  |
| F-018 | 4 | Life Vision dashboard (vision, aspirations, priorities, annual themes, goals by category, achievements, commitments), editable | P0 | M6 | Life Blueprint | LifeVision, Goal | Planned | Not tested |  |
| F-019 | 5 | 17 configurable goal categories + unlimited custom subcategories | P0 | M6 | Life Goals | LifeCategory | Planned | Not tested |  |
| F-020 | 5 | Full goal definition (32 fields in 5.2) | P0 | M6 | Goal Creation Wizard, Goal Details | Goal, GoalMetric, Attachment | Planned | Not tested |  |
| F-021 | 5 | Measurement units (currency, %, counts, time, distance, weight, pages, books, revenue, commission, ratings, custom) | P0 | M6 | Goal Details | GoalMetric | Planned | Not tested |  |
| F-022 | 5 | AI-assisted Goal Planning Wizard with user approval before activation | P1 | M8 | Goal Creation Wizard | Goal, AIRecommendation | Planned | Not tested | Manual wizard ships in M6; AI assist in M8 |
| F-023 | 5 | Goal hierarchy: parent/sub-goals, drill-down annual → daily | P0 | M6 | Goal Details, Planners | Goal, GoalMilestone, Task | Planned | Not tested |  |
| F-024 | 5 | Separate indicators: activity completion, milestone completion, outcome achievement, schedule adherence | P0 | M6 | Goal Details | GoalProgressRecord, KPIDefinition | Planned | Not tested | No misleading single % |
| F-025 | 6 | Workspaces: iExpert Technologies, iExpert Training Academy, Greentick Real Estate, Personal Life | P0 | M2 | Workspace Selector | Workspace | Built (Step 1) | Automated: pass | Seeded on first launch; Seeded with fixed ids so devices don't duplicate them |
| F-026 | 6 | Create, rename, archive, merge-where-safe workspaces | P1 | M4 | Workspace Selector, Settings | Workspace | Partial (Step 1) | Awaiting device test | Create, rename, archive, restore built; merge not yet |
| F-027 | 6 | Separate targets, pipelines, KPIs, task categories, reports per workspace | P0 | M4 | Business Dashboard | Workspace, Pipeline, FinancialTarget | Planned | Not tested |  |
| F-028 | 6 | Consolidated executive dashboard without mixing financial concepts | P0 | M5 | Executive Home | RevenueRecord, Commission | Planned | Not tested |  |
| F-029 | 7 | iExpert Technologies tracking (revenue target/actual, pipeline, expenses, customers, repairs, conversion, partnerships, marketing) | P0 | M5 | iExpert Dashboard | RevenueRecord, ExpenseRecord, Opportunity, FinancialTarget | Planned | Not tested |  |
| F-030 | 7 | Training Academy tracking (enrollment targets, inquiries, admissions pipeline, conversion, course revenue, partnerships) | P0 | M5 | Training Academy Dashboard | Lead, Opportunity, RevenueRecord | Planned | Not tested |  |
| F-031 | 7 | Business-specific pipelines and custom fields | P1 | M4 | Opportunity Pipeline | Pipeline, DealStage, custom field JSON | Planned | Not tested |  |
| F-032 | 7 | No demo figures treated as real; all amounts user-configurable | P0 | M5 | All business screens | — | Planned | Not tested | No seeded financial data |
| F-033 | 8 | Greentick contact types (buyer, seller, landlord, tenant, developer, investor, broker, corporate, provider, other) | P0 | M4 | Contact List, Contact Profile | Contact | Planned | Not tested |  |
| F-034 | 8 | Property records with configurable fields | P0 | M4 | Property Records | Property | Planned | Not tested |  |
| F-035 | 8 | Customizable 14-stage real estate pipeline | P0 | M4 | Opportunity Pipeline | Pipeline, DealStage | Planned | Not tested |  |
| F-036 | 8 | Transactions with commission %, gross, sharing, net, earned, received, receivables, probability, dates | P0 | M4 | Transaction Management | Transaction, Commission | Planned | Not tested |  |
| F-037 | 8 | Strict separation: property value ≠ revenue, expected ≠ received, forecast ≠ income | P0 | M5 | Commission Tracking | Commission (status enum) | Planned | Not tested |  |
| F-038 | 8 | AED targets: weekly/monthly/quarterly/annual commission, closed deals, leads, pipeline, conversion; live target vs actual | P0 | M5 | Greentick Dashboard, Commission Tracking | FinancialTarget, KPIMeasurement | Planned | Not tested |  |
| F-039 | 9 | CRM entities: contacts, companies, leads, accounts, opportunities, deals, pipelines, activities, meetings, follow-ups, notes, attachments, proposals, milestones | P0 | M4 | Contact/Lead/Opportunity screens | Contact, Company, Lead, Opportunity, CRMActivity | Planned | Not tested |  |
| F-040 | 9 | CRM capabilities: qualification, lead source, probability, forecasting, lost reasons, activity log, search/filter, reports | P0 | M4 | Lead Details, Opportunity Details | Lead, Opportunity, CRMActivity | Planned | Not tested |  |
| F-041 | 9 | Call, email, WhatsApp, schedule meeting via system links (tel:, mailto:, wa.me) | P1 | M4 | Contact Profile | CRMActivity | Planned | Not tested | No reading of WhatsApp/call/email history |
| F-042 | 9 | Smart follow-up lists (today, tomorrow, overdue, high-value, inactive, pending offers, awaiting client/docs, closing soon) | P0 | M4 | Lead List, Executive Home | Opportunity.nextAction | Planned | Not tested |  |
| F-043 | 10 | Personal finance: savings, income, budgets, emergency fund, debt, investments, net worth, FI planning, purchases, custom | P0 | M5 | Personal Finance Goals | FinancialTarget, RevenueRecord, ExpenseRecord | Planned | Not tested | Private by default |
| F-044 | 10 | Every target shows target, actual, variance, %, remaining, time left, trend, forecast, required pace | P0 | M5 | Financial Goals | FinancialTarget, KPIMeasurement | Planned | Not tested |  |
| F-045 | 10 | Clear separation of business revenue/profit, commissions, personal income, savings, investments, cash, expected income | P0 | M5 | Financial Goals | money record type enum | Planned | Not tested |  |
| F-046 | 10 | AED default, multi-currency; no double counting of transfers | P0 | M5 | Settings, Financial Goals | transfer flag | Planned | Not tested |  |
| F-047 | 11 | Morning Executive Briefing (15 items in Part 11) | P0 | M3 | Morning Briefing, Executive Home | aggregates | Planned | Not tested | AI recommendation slot filled in M8 |
| F-048 | 11 | Interactive daily timeline with drag-to-reschedule | P0 | M3 | Daily Calendar | CalendarEvent, Task | Planned | Not tested |  |
| F-049 | 11 | Explainable Priority Engine (urgency, importance, deadline, goal alignment, revenue, dependencies, time) | P1 | M3 | Executive Home | Task | Planned | Not tested | Rule-based scoring with visible reasons |
| F-050 | 11 | Daily execution: start, pause, complete, notes, reschedule, outcome, link goal, follow-up, history | P0 | M3 | Task Details | Task, completion history | Planned | Not tested |  |
| F-051 | 11 | Evening Review (planned vs done, time, achievements, misses, sales activity, reflection, tomorrow) | P0 | M3 | Daily Review | PersonalReflection, Assessment | Planned | Not tested |  |
| F-052 | 12 | Task fields (19 in Part 12) incl. recurrence, checklist, dependencies, links to goal/project/contact/opportunity | P0 | M3 | Task Creation, Task Details | Task, TaskRecurrence | Planned | Not tested |  |
| F-053 | 12 | Task views: Today, Tomorrow, Week, Upcoming, Overdue, Completed, All, by Workspace/Goal/Project, Calendar, Kanban, Priority Matrix | P0 | M3 | Task List | Task | Partial (Step 1) | Automated: pass | Today, Overdue, Upcoming, No date, Completed, All, by Workspace built |
| F-054 | 12 | Projects: objectives, milestones, breakdown, dependencies, risks, completion reports | P0 | M3 | Project Management | Project, ProjectMilestone | Planned | Not tested |  |
| F-055 | 12 | Time management: estimates, tracking, focus sessions, time-blocking, quick capture, reschedule suggestions, utilization reports | P1 | M3 | Task Details, Daily Calendar | Task time entries | Planned | Not tested |  |
| F-056 | 12 | Unfinished task stays visible until completed, cancelled or rescheduled | P0 | M3 | Task List | Task | Built (Step 1) | Automated: pass | Overdue open tasks always show on Today |
| F-057 | 13 | Fitness goals (weight, consistency, walking, steps, cardio, strength, mobility, duration) | P0 | M6 | Fitness Dashboard | Goal, FitnessRecord | Planned | Not tested |  |
| F-058 | 13 | Wellness goals (sleep, hydration, nutrition, recovery, energy, stress) | P1 | M6 | Fitness Dashboard | FitnessRecord | Planned | Not tested |  |
| F-059 | 13 | Fitness charts: daily, weekly, monthly consistency, weight trend, milestones | P0 | M7 | Fitness Tracking | FitnessRecord | Planned | Not tested |  |
| F-060 | 13 | Apple Health integration (iPhone, read-only, explicit permission) | P2 | M6 | Fitness Tracking | FitnessRecord | Planned | Not tested | Verify HealthKit capability with free Apple ID |
| F-061 | 14 | Communication skill categories (14 in Part 14) | P0 | M6 | Communication Development | Skill | Planned | Not tested |  |
| F-062 | 14 | Practice exercises and practice session log | P0 | M6 | Communication Practice | PracticeSession | Planned | Not tested |  |
| F-063 | 14 | Skill assessments: baseline, self, milestone, AI feedback (labelled), history | P1 | M6 | Skill Assessments | SkillAssessment | Planned | Not tested | Audio assessment optional, with consent |
| F-064 | 15 | Book library (15 fields) | P0 | M6 | Book Library | Book | Planned | Not tested |  |
| F-065 | 15 | Reading sessions and reading goals (books/year, pages/week, minutes/day) | P0 | M6 | Reading Progress | ReadingSession, Goal | Planned | Not tested |  |
| F-066 | 15 | Reading analytics | P1 | M7 | Reading Progress | Book, ReadingSession | Planned | Not tested |  |
| F-067 | 15 | Post-book reflection that can become tasks, projects or goals | P1 | M6 | Book Library | PersonalReflection | Planned | Not tested |  |
| F-068 | 16 | Educational content records (videos, podcasts) across 18 categories | P0 | M6 | Educational Content | LearningResource | Planned | Not tested |  |
| F-069 | 16 | Share Sheet import from iPhone and Mac | P2 | M9 | Educational Content | LearningResource | Planned | Not tested | Share Extension; free account OK |
| F-070 | 16 | Structured learning paths (e.g. 90-day leadership) | P1 | M6 | Learning Programs | LearningActivity, Program | Planned | Not tested |  |
| F-071 | 17 | Custom spiritual routines, reminders, frequency goals, private journal, reviews | P0 | M6 | Spiritual Routines | SpiritualRoutine, PersonalReflection | Planned | Not tested | No assumed religion, no scores, private by default |
| F-072 | 18 | Family and personal life: responsibilities, dates, occasions, quality time, household, travel, leisure | P0 | M6 | Family and Personal Life | Task, CalendarEvent (Personal workspace) | Planned | Not tested |  |
| F-073 | 18 | Privacy boundaries so personal data stays out of business views and reports | P0 | M2 | Settings and Privacy | Workspace privacy flags | Partial (Step 1) | — | Private flag on workspaces; enforcement in reports comes with reports |
| F-074 | 19 | Habits: daily/weekly/custom recurrence, check-ins, reminders, pause/resume, notes, goal links | P0 | M6 | Habit Dashboard, Habit Details | Habit, HabitCheckin | Planned | Not tested | Delivered early in Step 2 |
| F-075 | 19 | Streaks, consistency, calendar heatmaps, trends | P0 | M6 | Habit Dashboard | HabitCheckin | Planned | Not tested |  |
| F-076 | 19 | Non-punishing design; suggest lighter schedule when overloaded | P1 | M6 | Habit Dashboard | — | Planned | Not tested |  |
| F-077 | 20 | Progress AI chat with user-controlled data access | P0 | M8 | Progress AI Chat | CoachingConversation | Planned | Not tested | Claude API via Supabase Edge Function; API key never in app. Anthropic API usage is paid — needs user decision |
| F-078 | 20 | Daily guidance, business mentorship, personal growth Q&A grounded in records | P0 | M8 | Progress AI Chat, Morning Briefing | AIRecommendation | Planned | Not tested |  |
| F-079 | 20 | Structured coaching sessions (weekly, monthly, financial, discipline, goal adjustment) | P1 | M8 | Progress AI Chat | CoachingConversation | Planned | Not tested |  |
| F-080 | 20 | Proactive recommendations from real data, de-duplicated | P1 | M8 | AI Recommendations | AIRecommendation | Planned | Not tested |  |
| F-081 | 20 | AI safety: grounded, no invented data, approvals, dismissible, can be disabled | P0 | M8 | AI Recommendations, Settings | AuditEvent | Planned | Not tested |  |
| F-082 | 20 | Coaching styles (5) | P2 | M8 | Settings | UserPreferences | Planned | Not tested |  |
| F-083 | 21 | Life Progress Engine: 10-step loop linking all modules | P0 | M6–M8 | Goal Details | Goal, Task, GoalProgressRecord | Planned | Not tested |  |
| F-084 | 21 | Trace any daily task back to its long-term objective | P0 | M6 | Task Details, Goal Details | Goal hierarchy | Planned | Not tested |  |
| F-085 | 22 | Calendar views: Today, Week, Month, Agenda, by Workspace, custom range | P0 | M3 | Daily/Weekly/Monthly Calendar | CalendarEvent | Planned | Not tested |  |
| F-086 | 22 | Scheduling of appointments, focus blocks, buffers, breaks, routines | P0 | M3 | Daily Calendar | CalendarEvent | Planned | Not tested |  |
| F-087 | 22 | Apple Calendar and Reminders sync (EventKit) | P1 | M3 | Integrations | CalendarEvent | Planned | Not tested | Free account OK |
| F-088 | 22 | Google and Outlook calendar | P3 | M9 | Integrations | CalendarEvent | Planned | Not tested | Via Apple Calendar accounts first |
| F-089 | 22 | AI smart planning with user approval | P1 | M8 | Daily Calendar | — | Planned | Not tested |  |
| F-090 | 23 | Weekly Life & Business Growth Report (21 sections), planned vs actual, editable next-week plan | P0 | M7 | Weekly Report | Assessment, GeneratedReport | Planned | Not tested |  |
| F-091 | 24 | Monthly Executive & Personal Growth Review (financial, productivity, personal, AI assessment) | P0 | M7 | Monthly Report | Assessment | Planned | Not tested | AI section in M8 |
| F-092 | 25 | Quarterly Strategic Review with goal revision and preserved history | P0 | M7 | Quarterly Review | Assessment, GoalRevision | Planned | Not tested |  |
| F-093 | 26 | My Year of Growth annual report (16 sections), no fabricated history | P0 | M7 | Annual Life Growth Report | Assessment, GeneratedReport | Planned | Not tested |  |
| F-094 | 27 | 15 chart types (line, bar, stacked, donut, rings, radar, heatmap, KPI cards, trends, timelines, target vs actual, period comparison, forecast, goal hierarchy, time allocation) | P0 | M7 | Graphical Analytics | KPIMeasurement | Planned | Not tested | Swift Charts; radar and heatmap are custom views |
| F-095 | 27 | Report periods and filters; drill into data behind any chart; accessibility labels | P0 | M7 | Graphical Analytics | — | Planned | Not tested |  |
| F-096 | 27 | Export: PDF, CSV, spreadsheet, print, share, stored history | P1 | M7 | Data Export | GeneratedReport | Planned | Not tested |  |
| F-097 | 28 | My Life Compass: 8 customizable dimensions, radar with explicit normalization, self-assessment for non-measurable areas | P0 | M7 | Life Compass | KPIDefinition, Assessment | Planned | Not tested |  |
| F-098 | 29 | Personal development programs (objective, baseline, duration, milestones, activities linked to tasks/calendar, completion assessment) | P1 | M6 | Learning Programs | Program, LearningActivity | Planned | Not tested |  |
| F-099 | 30 | My Growth Journey: lifelong timeline with filters, photos, attachments, search | P1 | M7 | Growth Journey, Achievement Timeline | Achievement, Attachment | Planned | Not tested |  |
| F-100 | 31 | Unified activity model: one real action updates every relevant view (Greentick, communication, fitness workflows) | P0 | M2–M7 | — | shared domain layer | Planned | Not tested | Acceptance tests C, D, E |
| F-101 | 32 | iPhone tabs: Today, Business, Goals, Progress, AI Mentor + global quick-add | P0 | M2 | Navigation | — | Partial (Step 1) | Awaiting device test | Tabs built; Goals, Progress, AI Mentor show planned content |
| F-102 | 32 | Mac sidebar with 17 sections | P0 | M2 | Navigation | — | Partial (Step 1) | Awaiting device test | Sidebar built; planned sections listed and labelled |
| F-103 | 32 | Design system: typography, spacing, motion, accessibility | P0 | M1 | All | — | Planned | Not tested | UI_DESIGN_SYSTEM.md |
| F-104 | 33 | Automation engine: configurable rules, approvals, history, duplicate prevention, retries, time zones | P1 | M9 | Settings | AutomationRule, AuditEvent | Planned | Not tested | Server-side jobs via Supabase cron; no false iOS background promises |
| F-105 | 34 | Notifications: 12 types, quiet hours, priority, per-device and per-category settings, snooze, history | P0 | M9 | Notifications | Notification | Planned | Not tested | Local notifications only on free account (no remote push) |
| F-106 | 35 | Universal Quick Capture (11 record types) | P0 | M3 | Quick Add | multiple | Partial (Step 1) | Awaiting device test | Quick add for tasks |
| F-107 | 35 | Global search across records | P0 | M3 | Global Search | all | Planned | Not tested |  |
| F-108 | 35 | App Intents/Siri, widgets, Lock Screen widgets, menu-bar capture, deep links | P2 | M9 | — | — | Planned | Not tested | Widgets and App Intents work on a free account |
| F-109 | 36 | Data model with all 52 core entities | P0 | M1 | — | see DATA_MODEL.md | Planned | Not tested |  |
| F-110 | 36 | Engineering standards: modular, shared iOS/macOS models, testable logic, migrations, logging, validation | P0 | M2 | — | — | Partial (Step 1) | Automated: pass | Shared core package, migrations, tests, CI |
| F-111 | 37 | Secure authentication | P0 | M2 | Login | User | Built (Step 1) | Automated: pass | Supabase email or magic link. Sign in with Apple needs paid program; Supabase email + password; session in Keychain |
| F-112 | 37 | Biometric lock, encryption in transit and at rest, Keychain, row-level security | P0 | M2 | Settings and Privacy | — | Partial (Step 1) | Automated: pass | Postgres RLS per user; Lock, HTTPS, Keychain, row-level security built |
| F-113 | 37 | Privacy controls (AI access, workspace separation, finance, spiritual, health, coaching, notifications, retention, exports) | P0 | M2–M8 | Settings and Privacy | UserPreferences | Planned | Not tested |  |
| F-114 | 37 | Data export, account deletion, backup and recovery, audit history | P1 | M10 | Data Export | AuditEvent | Planned | Not tested |  |
| F-115 | 38 | Reporting integrity: real records, timestamps, Asia/Dubai default, configurable week start, no duplicate aggregation, transparent KPI formulas, missing-data marking, correctable history | P0 | M5–M7 | All reports | AuditEvent, KPIDefinition | Partial (Step 1) | Automated: pass | Asia/Dubai default, configurable week start, server timestamps |
| F-116 | 39 | Onboarding (12 setup items) + optional 7-day guided setup | P1 | M6 | Welcome, Onboarding | Profile, UserPreferences | Partial (Step 1) | Awaiting device test | Basic setup ships in M2; Welcome and sign-in; full onboarding in Step 2 |
| F-117 | 40 | All 70 required screens | P0 | M2–M10 | see screen list | — | Planned | Not tested | Tracked per screen in later updates |
| F-118 | 41 | Unit and integration test suite (25 areas in Part 41) | P0 | every milestone | — | — | Partial (Step 1) | Automated: pass | TEST_PLAN.md; 35 tests incl. real-database integration |
| F-119 | 41 | Real-life acceptance tests A–L | P0 | M2–M10 | — | — | Partial (Step 1) | Simulated A, B, H, I pass | A, B, F, H, I, J need both real devices; Real-device runs pending |
| F-120 | 43 | Project docs: README, PRODUCT_VISION, REQUIREMENTS, FEATURE_MATRIX, ARCHITECTURE, DATA_MODEL, SYNC_STRATEGY, UI_DESIGN_SYSTEM, ROADMAP, IMPLEMENTATION_STATUS, TEST_PLAN, CHANGELOG, DEPLOYMENT_GUIDE, KNOWN_ISSUES | P0 | M1 | — | — | Partial (Step 1) | — | This file is the first one; README, FEATURE_MATRIX, ARCHITECTURE, DATA_MODEL, SYNC_STRATEGY, ROADMAP, STATUS, TEST_PLAN, CHANGELOG, DEPLOYMENT_GUIDE, KNOWN_ISSUES |

## Shared systems (features that depend on the same models)

- **Goal hierarchy** (Goal, GoalMilestone, GoalProgressRecord): life blueprint, all life modules, programs, assessments, Life Compass, AI mentor.
- **Task + CalendarEvent**: daily command center, CRM follow-ups, fitness, reading and spiritual sessions, programs, smart scheduling.
- **Money records** (RevenueRecord, ExpenseRecord, Commission, FinancialTarget): iExpert, academy, Greentick, personal finance, consolidated dashboard, all reports.
- **KPI engine** (KPIDefinition, KPIMeasurement): every chart, assessment and Life Compass dimension.
- **Sync layer** (SyncState, outbox, AuditEvent): every entity.
- **Privacy layer** (workspace flags, UserPreferences): reports, exports, AI context, notifications.

## Spec parts with no feature rows

Parts 1, 42, 44, 45 and 46 are role, process, rules and vision text. Their rules are applied across all rows above. Each of the 30 non-negotiable rules in Part 44 is covered by at least one P0 row.
