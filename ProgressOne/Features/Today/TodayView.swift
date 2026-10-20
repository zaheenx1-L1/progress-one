import SwiftUI
import SwiftData
import ProgressCore

/// The first version of the Daily Command Center (spec Part 11): today's and overdue tasks,
/// quick capture, and sync status. The full morning briefing comes in Step 2.
struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(SyncCoordinator.self) private var sync
    @Environment(PreferencesStore.self) private var preferences
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \TaskItem.sortOrder) private var allTasks: [TaskItem]
    @Query(sort: \Workspace.sortOrder) private var workspaces: [Workspace]

    @State private var quickTitle = ""
    @State private var editorTarget: EditorTarget?
    @FocusState private var quickFieldFocused: Bool

    var body: some View {
        let now = Date.now
        let calendar = preferences.calendar
        let live = allTasks.filter { !$0.isTrashed }
        let overdue = live.filter { TaskBucket.overdue.contains(status: $0.status, dueAt: $0.dueAt, now: now, calendar: calendar) }
            .sorted(by: TaskItem.displayOrder)
        let today = live.filter {
            TaskBucket.today.contains(status: $0.status, dueAt: $0.dueAt, now: now, calendar: calendar)
                && !TaskBucket.overdue.contains(status: $0.status, dueAt: $0.dueAt, now: now, calendar: calendar)
        }
        .sorted(by: TaskItem.displayOrder)
        let doneToday = live.filter { task in
            task.status == .done && task.completedAt.map { calendar.isDate($0, inSameDayAs: now) } == true
        }

        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting(now: now, calendar: calendar)).font(.title2.bold())
                    Text(now, format: .dateTime.weekday(.wide).day().month(.wide).year())
                        .environment(\.timeZone, preferences.regional.timeZone)
                        .foregroundStyle(.secondary)
                    HStack {
                        SyncStatusBadge()
                        Spacer()
                        Text("\(doneToday.count) done today").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                if let warning = environment.storageWarning {
                    Label(warning, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                }
            }

            Section("Quick add") {
                HStack {
                    TextField("Add a task for today", text: $quickTitle)
                        .focused($quickFieldFocused)
                        .onSubmit(addQuickTask)
                    Button("Add", action: addQuickTask)
                        .disabled(quickTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            if !overdue.isEmpty {
                Section {
                    ForEach(overdue) { row($0) }
                } header: {
                    Label("Overdue", systemImage: "exclamationmark.circle").foregroundStyle(.red)
                }
            }

            Section("Today") {
                if today.isEmpty {
                    Text(overdue.isEmpty ? "Nothing scheduled for today." : "Nothing else due today.")
                        .foregroundStyle(.secondary)
                }
                ForEach(today) { row($0) }
            }

            Section("Coming in Step 2") {
                Label("Morning briefing with your top 3 priorities", systemImage: "circle.dashed")
                Label("Daily timeline, habits and evening review", systemImage: "circle.dashed")
            }
            .foregroundStyle(.secondary)
        }
        .navigationTitle("Today")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editorTarget = .new(workspaceID: nil)
                } label: {
                    Label("New Task", systemImage: "plus")
                }
            }
            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            #endif
        }
        .refreshable { await sync.syncNow() }
        .sheet(item: $editorTarget) { target in
            switch target {
            case .new(let workspaceID): TaskEditorView(task: nil, defaultWorkspaceID: workspaceID)
            case .edit(let task): TaskEditorView(task: task, defaultWorkspaceID: nil)
            }
        }
    }

    private func row(_ task: TaskItem) -> some View {
        TaskRow(task: task, workspace: workspaces.first { $0.id == task.workspaceID }) {
            editorTarget = .edit(task)
        }
    }

    private func greeting(now: Date, calendar: Calendar) -> String {
        switch calendar.component(.hour, from: now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }

    private func addQuickTask() {
        let title = quickTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let task = TaskItem(id: UUID())
        task.title = title
        task.dueAt = preferences.calendar.date(bySettingHour: 18, minute: 0, second: 0, of: .now)
        context.insert(task)
        task.markEdited()
        try? context.save()
        quickTitle = ""
        quickFieldFocused = true
        sync.requestSync()
    }
}
