import SwiftUI
import SwiftData
import ProgressCore

/// A filterable task list (spec Part 12 views: Today, Overdue, Upcoming, Completed, All, by workspace).
struct TaskListScreen: View {
    @Environment(PreferencesStore.self) private var preferences
    @Query(sort: \TaskItem.sortOrder) private var allTasks: [TaskItem]
    @Query(sort: \Workspace.sortOrder) private var workspaces: [Workspace]

    @State private var bucket: TaskBucket
    @State private var workspaceID: UUID?
    @State private var editorTarget: EditorTarget?

    init(initialBucket: TaskBucket, workspaceID: UUID?) {
        _bucket = State(initialValue: initialBucket)
        _workspaceID = State(initialValue: workspaceID)
    }

    var body: some View {
        let tasks = filtered
        List {
            if tasks.isEmpty {
                ContentUnavailableView(
                    "No tasks here",
                    systemImage: "checkmark.circle",
                    description: Text("Add one with the + button.")
                )
            }
            ForEach(tasks) { task in
                TaskRow(task: task, workspace: workspace(for: task)) {
                    editorTarget = .edit(task)
                }
            }
        }
        .navigationTitle(workspaceID.flatMap { id in workspaces.first { $0.id == id }?.name } ?? bucket.title)
        .toolbar {
            ToolbarItem {
                Picker("Show", selection: $bucket) {
                    ForEach(TaskBucket.allCases) { Text($0.title).tag($0) }
                }
            }
            ToolbarItem {
                Picker("Workspace", selection: $workspaceID) {
                    Text("All workspaces").tag(UUID?.none)
                    ForEach(workspaces.filter(\.isActive)) { workspace in
                        Text(workspace.name).tag(Optional(workspace.id))
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editorTarget = .new(workspaceID: workspaceID)
                } label: {
                    Label("New Task", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editorTarget) { target in
            switch target {
            case .new(let workspaceID): TaskEditorView(task: nil, defaultWorkspaceID: workspaceID)
            case .edit(let task): TaskEditorView(task: task, defaultWorkspaceID: nil)
            }
        }
    }

    private var filtered: [TaskItem] {
        let now = Date.now
        let calendar = preferences.calendar
        return allTasks.filter { task in
            !task.isTrashed
                && (workspaceID == nil || task.workspaceID == workspaceID)
                && bucket.contains(status: task.status, dueAt: task.dueAt, now: now, calendar: calendar)
        }
        .sorted(by: TaskItem.displayOrder)
    }

    private func workspace(for task: TaskItem) -> Workspace? {
        workspaces.first { $0.id == task.workspaceID }
    }
}

enum EditorTarget: Identifiable {
    case new(workspaceID: UUID?)
    case edit(TaskItem)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let task): task.id.uuidString
        }
    }
}

extension TaskItem {
    /// Open tasks first, then by due date, then priority.
    static func displayOrder(_ a: TaskItem, _ b: TaskItem) -> Bool {
        if a.status.isOpen != b.status.isOpen { return a.status.isOpen }
        switch (a.dueAt, b.dueAt) {
        case let (x?, y?) where x != y: return x < y
        case (_?, nil): return true
        case (nil, _?): return false
        default: break
        }
        if a.priority != b.priority { return a.priority > b.priority }
        return a.sortOrder < b.sortOrder
    }
}

struct TaskRow: View {
    @Environment(\.modelContext) private var context
    @Environment(SyncCoordinator.self) private var sync
    @Environment(PreferencesStore.self) private var preferences

    let task: TaskItem
    let workspace: Workspace?
    let open: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Button(action: toggleDone) {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.status == .done ? Color.green : task.priority.color)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.status == .done ? "Mark as not done" : "Mark as done")

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title.isEmpty ? "Untitled task" : task.title)
                    .strikethrough(task.status == .done)
                    .foregroundStyle(task.status.isOpen ? .primary : .secondary)
                HStack(spacing: 6) {
                    if let workspace {
                        WorkspaceDot(colorHex: workspace.colorHex)
                        Text(workspace.name)
                    }
                    if let due = task.dueAt {
                        Text(due, format: .dateTime.day().month().hour().minute())
                            .environment(\.timeZone, preferences.regional.timeZone)
                            .foregroundStyle(isOverdue(due) ? Color.red : Color.secondary)
                    }
                    if task.status == .inProgress {
                        Text("In progress").foregroundStyle(.blue)
                    }
                    if task.syncConflict != nil {
                        Label("Conflict", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                task.softDelete()
                save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button("Edit…", action: open)
            Button(task.status == .done ? "Mark as not done" : "Mark as done", action: toggleDone)
            Divider()
            Button("Delete", role: .destructive) {
                task.softDelete()
                save()
            }
        }
    }

    private func isOverdue(_ due: Date) -> Bool {
        task.status.isOpen && due < Date.now
    }

    private func toggleDone() {
        task.status = task.status == .done ? .todo : .done
        task.markEdited()
        save()
    }

    private func save() {
        try? context.save()
        sync.requestSync()
    }
}

struct TaskEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncCoordinator.self) private var sync
    @Environment(PreferencesStore.self) private var preferences
    @Query(sort: \Workspace.sortOrder) private var workspaces: [Workspace]

    let task: TaskItem?
    let defaultWorkspaceID: UUID?

    @State private var title = ""
    @State private var notes = ""
    @State private var workspaceID: UUID?
    @State private var status: TaskStatus = .todo
    @State private var priority: TaskPriority = .medium
    @State private var hasDueDate = false
    @State private var dueAt = Date.now
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What needs doing?", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section {
                    Picker("Workspace", selection: $workspaceID) {
                        Text("None").tag(UUID?.none)
                        ForEach(workspaces.filter(\.isActive)) { workspace in
                            Label(workspace.name, systemImage: workspace.symbol).tag(Optional(workspace.id))
                        }
                    }
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases.reversed(), id: \.self) { Text($0.title).tag($0) }
                    }
                    Picker("Status", selection: $status) {
                        ForEach(TaskStatus.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                }
                Section {
                    Toggle("Due date", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Due", selection: $dueAt, displayedComponents: [.date, .hourAndMinute])
                            .environment(\.timeZone, preferences.regional.timeZone)
                    }
                }
                if let task, task.syncConflict != nil {
                    Section {
                        Label("This task was changed on another device too. Open Sync Status to choose which version to keep.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
                if task != nil {
                    Section {
                        Button("Delete Task", role: .destructive) {
                            task?.softDelete()
                            finish()
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(task == nil ? "New Task" : "Edit Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .onAppear(perform: load)
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 480)
        #endif
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let task {
            title = task.title
            notes = task.notes
            workspaceID = task.workspaceID
            status = task.status
            priority = task.priority
            hasDueDate = task.dueAt != nil
            dueAt = task.dueAt ?? .now
        } else {
            workspaceID = defaultWorkspaceID
            hasDueDate = true
            dueAt = preferences.calendar.date(bySettingHour: 18, minute: 0, second: 0, of: .now) ?? .now
        }
    }

    private func save() {
        let target: TaskItem
        if let task {
            target = task
        } else {
            target = TaskItem(id: UUID())
            context.insert(target)
        }
        target.title = title.trimmingCharacters(in: .whitespaces)
        target.notes = notes
        target.workspaceID = workspaceID
        target.status = status
        target.priority = priority
        target.dueAt = hasDueDate ? dueAt : nil
        target.markEdited()
        finish()
    }

    private func finish() {
        try? context.save()
        sync.requestSync()
        dismiss()
    }
}
