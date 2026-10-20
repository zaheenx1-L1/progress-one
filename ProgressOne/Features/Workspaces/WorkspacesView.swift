import SwiftUI
import SwiftData
import ProgressCore

/// Workspaces (spec Part 6): create, rename, archive, and open each one's tasks.
struct WorkspacesView: View {
    @Environment(\.modelContext) private var context
    @Environment(SyncCoordinator.self) private var sync
    @Query(sort: \Workspace.sortOrder) private var workspaces: [Workspace]
    @Query private var tasks: [TaskItem]

    @State private var editing: Workspace?
    @State private var showingArchived = false

    var body: some View {
        List {
            Section {
                ForEach(workspaces.filter(\.isActive)) { workspace in
                    NavigationLink {
                        TaskListScreen(initialBucket: .all, workspaceID: workspace.id)
                    } label: {
                        row(workspace)
                    }
                    .contextMenu { menu(for: workspace) }
                    .swipeActions { Button("Edit") { editing = workspace }.tint(.blue) }
                }
            }
            let archived = workspaces.filter { $0.archivedAt != nil && !$0.isTrashed }
            if !archived.isEmpty {
                Section("Archived") {
                    ForEach(archived) { workspace in
                        row(workspace)
                            .foregroundStyle(.secondary)
                            .contextMenu { menu(for: workspace) }
                            .swipeActions { Button("Restore") { setArchived(workspace, false) } }
                    }
                }
            }
        }
        .navigationTitle("Workspaces")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let workspace = Workspace(id: UUID())
                    workspace.sortOrder = (workspaces.map(\.sortOrder).max() ?? 0) + 1
                    // Not queued for sync until the user saves it.
                    workspace.syncIsDirty = false
                    context.insert(workspace)
                    editing = workspace
                } label: {
                    Label("New Workspace", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editing) { workspace in
            WorkspaceEditor(workspace: workspace)
        }
    }

    private func row(_ workspace: Workspace) -> some View {
        let openCount = tasks.filter { $0.workspaceID == workspace.id && $0.status.isOpen && !$0.isTrashed }.count
        return HStack(spacing: 12) {
            Image(systemName: workspace.symbol)
                .foregroundStyle(Color(hex: workspace.colorHex))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(workspace.name)
                Text(workspace.kind == .personal ? "Personal" : "Business")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if workspace.isPrivate {
                Image(systemName: "lock").foregroundStyle(.secondary).accessibilityLabel("Private")
            }
            Text("\(openCount) open").font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func menu(for workspace: Workspace) -> some View {
        Button("Edit…") { editing = workspace }
        if workspace.archivedAt == nil {
            Button("Archive") { setArchived(workspace, true) }
        } else {
            Button("Restore") { setArchived(workspace, false) }
        }
    }

    private func setArchived(_ workspace: Workspace, _ archived: Bool) {
        workspace.archivedAt = archived ? .now : nil
        workspace.markEdited()
        try? context.save()
        sync.requestSync()
    }
}

struct WorkspaceEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncCoordinator.self) private var sync

    let workspace: Workspace

    @State private var name = ""
    @State private var kind: WorkspaceKind = .business
    @State private var symbol = "briefcase"
    @State private var colorHex = "#0A84FF"
    @State private var isPrivate = false

    private static let symbols = ["briefcase", "wrench.and.screwdriver", "graduationcap", "building.2", "house", "person.crop.circle", "heart", "star", "book", "dumbbell"]
    private static let colors = ["#0A84FF", "#5E5CE6", "#30D158", "#FF9F0A", "#FF375F", "#64D2FF", "#BF5AF2", "#8E8E93"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $kind) {
                        Text("Business").tag(WorkspaceKind.business)
                        Text("Personal").tag(WorkspaceKind.personal)
                    }
                    Toggle("Private", isOn: $isPrivate)
                } footer: {
                    Text("Private workspaces are kept out of business views and shared reports.")
                }
                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 12) {
                        ForEach(Self.symbols, id: \.self) { item in
                            Button {
                                symbol = item
                            } label: {
                                Image(systemName: item)
                                    .frame(width: 36, height: 36)
                                    .background(symbol == item ? Color(hex: colorHex).opacity(0.25) : .clear, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item)
                        }
                    }
                }
                Section("Color") {
                    HStack(spacing: 12) {
                        ForEach(Self.colors, id: \.self) { item in
                            Button {
                                colorHex = item
                            } label: {
                                Circle()
                                    .fill(Color(hex: item))
                                    .frame(width: 26, height: 26)
                                    .overlay { if colorHex == item { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white) } }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isUnsavedNew ? "New Workspace" : "Edit Workspace")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isUnsavedNew { context.delete(workspace) }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                name = isUnsavedNew ? "" : workspace.name
                kind = workspace.kind
                symbol = workspace.symbol
                colorHex = workspace.colorHex
                isPrivate = workspace.isPrivate
            }
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 460)
        #endif
    }

    private var isUnsavedNew: Bool {
        workspace.syncBaseVersion == 0 && workspace.syncRevision == 1 && !workspace.syncIsDirty && workspace.name == "New workspace"
    }

    private func save() {
        workspace.name = name.trimmingCharacters(in: .whitespaces)
        workspace.kind = kind
        workspace.symbol = symbol
        workspace.colorHex = colorHex
        workspace.isPrivate = isPrivate
        workspace.markEdited()
        try? context.save()
        sync.requestSync()
        dismiss()
    }
}
