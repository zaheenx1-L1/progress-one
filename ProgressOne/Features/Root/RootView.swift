import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AuthStore.self) private var auth
    @Environment(SyncCoordinator.self) private var sync
    @Environment(PreferencesStore.self) private var preferences
    @Environment(AppLock.self) private var appLock
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var environment = environment

        Group {
            if auth.mode == .welcome {
                WelcomeView()
            } else {
                MainView()
                    .sheet(isPresented: $environment.quickAddRequested) {
                        TaskEditorView(task: nil, defaultWorkspaceID: nil)
                    }
            }
        }
        .overlay {
            if appLock.isLocked {
                LockScreenView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                sync.appBecameActive()
                if appLock.isLocked { Task { await appLock.unlock() } }
            case .background:
                sync.appWentToBackground()
                if preferences.appLockEnabled { appLock.lock() }
            default:
                break
            }
        }
        .task {
            sync.appBecameActive()
            if appLock.isLocked { await appLock.unlock() }
        }
    }
}

/// iPhone: five tabs (spec Part 32). Mac: a sidebar.
struct MainView: View {
    var body: some View {
        #if os(macOS)
        MacSidebarView()
        #else
        PhoneTabView()
        #endif
    }
}

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case home, tasks, workspaces, calendar, projects, crm, finance, goals, habits, reports, mentor, sync

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Executive Home"
        case .tasks: "Tasks"
        case .workspaces: "Workspaces"
        case .calendar: "Calendar"
        case .projects: "Projects"
        case .crm: "CRM"
        case .finance: "Financial Goals"
        case .goals: "Life Goals"
        case .habits: "Habits"
        case .reports: "Reports"
        case .mentor: "AI Mentor"
        case .sync: "Sync Status"
        }
    }

    var symbol: String {
        switch self {
        case .home: "sun.max"
        case .tasks: "checklist"
        case .workspaces: "square.grid.2x2"
        case .calendar: "calendar"
        case .projects: "folder"
        case .crm: "person.2"
        case .finance: "chart.line.uptrend.xyaxis"
        case .goals: "target"
        case .habits: "repeat"
        case .reports: "chart.bar.doc.horizontal"
        case .mentor: "sparkles"
        case .sync: "arrow.triangle.2.circlepath"
        }
    }

    /// Sections that work in this build. The rest show what is planned.
    var isAvailable: Bool {
        [.home, .tasks, .workspaces, .sync].contains(self)
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .home: TodayView()
        case .tasks: TaskListScreen(initialBucket: .all, workspaceID: nil)
        case .workspaces: WorkspacesView()
        case .sync: SyncStatusView()
        case .calendar:
            PlannedFeatureView(title: title, symbol: symbol, step: "Step 2", items: ["Day, week and month views", "Drag to reschedule", "Apple Calendar and Reminders"])
        case .projects:
            PlannedFeatureView(title: title, symbol: symbol, step: "Step 2", items: ["Projects with milestones and dependencies", "Kanban and priority matrix views", "Project reports"])
        case .crm:
            PlannedFeatureView(title: title, symbol: symbol, step: "Step 3", items: ["Contacts, companies, leads and opportunities", "Greentick property and transaction records", "Follow-up lists and pipelines"])
        case .finance:
            PlannedFeatureView(title: title, symbol: symbol, step: "Step 3", items: ["iExpert and Academy revenue targets", "Greentick commission targets in AED", "Personal savings and net worth"])
        case .goals:
            PlannedFeatureView(title: title, symbol: symbol, step: "Step 2", items: ["My Life Blueprint", "Goal hierarchy from annual to daily", "Fitness, communication, reading, spiritual goals"])
        case .habits:
            PlannedFeatureView(title: title, symbol: symbol, step: "Step 2", items: ["Daily and weekly habits", "Streaks and calendar heatmaps", "Habit-to-goal links"])
        case .reports:
            PlannedFeatureView(title: title, symbol: symbol, step: "Step 4", items: ["Weekly, monthly, quarterly and annual reports", "Interactive charts", "My Life Compass", "PDF and CSV export"])
        case .mentor:
            PlannedFeatureView(title: title, symbol: symbol, step: "Step 4", items: ["Progress AI chat", "Morning briefing recommendations", "Coaching sessions grounded in your records"])
        }
    }
}

#if os(macOS)
struct MacSidebarView: View {
    @State private var selection: AppSection? = .home

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Working now") {
                    ForEach(AppSection.allCases.filter(\.isAvailable)) { section in
                        Label(section.title, systemImage: section.symbol).tag(section as AppSection?)
                    }
                }
                Section("Planned") {
                    ForEach(AppSection.allCases.filter { !$0.isAvailable }) { section in
                        Label(section.title, systemImage: section.symbol)
                            .foregroundStyle(.secondary)
                            .tag(section as AppSection?)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 230)
            .safeAreaInset(edge: .bottom) {
                SyncStatusBadge()
                    .padding(10)
            }
        } detail: {
            NavigationStack {
                (selection ?? .home).destination
            }
        }
    }
}
#else
struct PhoneTabView: View {
    var body: some View {
        TabView {
            NavigationStack { TodayView() }
                .tabItem { Label("Today", systemImage: "sun.max") }
            NavigationStack { BusinessTab() }
                .tabItem { Label("Business", systemImage: "briefcase") }
            NavigationStack { AppSection.goals.destination }
                .tabItem { Label("Goals", systemImage: "target") }
            NavigationStack { AppSection.reports.destination }
                .tabItem { Label("Progress", systemImage: "chart.bar") }
            NavigationStack { AppSection.mentor.destination }
                .tabItem { Label("AI Mentor", systemImage: "sparkles") }
        }
    }
}

/// The iPhone Business tab: workspaces and their tasks now; CRM and finance later.
struct BusinessTab: View {
    var body: some View {
        List {
            Section {
                NavigationLink { WorkspacesView() } label: { Label("Workspaces", systemImage: "square.grid.2x2") }
                NavigationLink { TaskListScreen(initialBucket: .all, workspaceID: nil) } label: { Label("All tasks", systemImage: "checklist") }
            }
            Section("Planned") {
                ForEach([AppSection.crm, .finance, .projects, .calendar]) { section in
                    NavigationLink { section.destination } label: {
                        Label(section.title, systemImage: section.symbol).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Business")
    }
}
#endif

struct LockScreenView: View {
    @Environment(AppLock.self) private var appLock

    var body: some View {
        ZStack {
            Rectangle().fill(.regularMaterial).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill").font(.system(size: 44))
                Text("Progress One is locked").font(.title2.bold())
                if let failure = appLock.lastFailure {
                    Text(failure).font(.footnote).foregroundStyle(.secondary)
                }
                Button("Unlock with \(appLock.biometryName)") {
                    Task { await appLock.unlock() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}
