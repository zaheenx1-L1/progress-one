import SwiftUI
import ProgressCore

/// Shows the sync state and lets the user settle conflicts (spec Part 3.4).
struct SyncStatusView: View {
    @Environment(SyncCoordinator.self) private var sync
    @Environment(AuthStore.self) private var auth
    @State private var showingAccount = false

    var body: some View {
        let state = sync.displayState
        List {
            Section {
                Label(state.title, systemImage: state.symbol).font(.headline)
                if case .error(let message) = state {
                    Text(message).foregroundStyle(.orange)
                }
                if let last = sync.lastSuccess {
                    LabeledContent("Last synced") {
                        Text(last, format: .relative(presentation: .named))
                    }
                }
                LabeledContent("Changes waiting to send", value: "\(sync.pendingCount)")
                LabeledContent("Connection", value: sync.isOnline ? "Online" : "No connection")
                if auth.mode == .signedIn {
                    Button {
                        Task { await sync.syncNow() }
                    } label: {
                        Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(sync.isSyncing)
                } else {
                    Text("Sign in to keep your iPhone and Mac in sync. Everything you've added so far will be sent when you do.")
                        .foregroundStyle(.secondary)
                    Button("Sign in to sync") { showingAccount = true }
                }
            }

            let conflicts = sync.conflicts().map { ConflictItem(id: $0.id, model: $0) }
            if !conflicts.isEmpty {
                Section {
                    ForEach(conflicts) { item in
                        ConflictRow(model: item.model)
                    }
                } header: {
                    Text("Needs your decision")
                } footer: {
                    Text("These were changed on both devices before they could sync. Choose which version to keep. The other version is replaced.")
                }
            }
        }
        .navigationTitle("Sync Status")
        .onAppear { sync.refreshCounts() }
        .sheet(isPresented: $showingAccount) { AccountSetupView() }
    }
}

private struct ConflictItem: Identifiable {
    let id: UUID
    let model: any SyncedModel
}

private struct ConflictRow: View {
    @Environment(SyncCoordinator.self) private var sync
    let model: any SyncedModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(kindName).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 16) {
                version(title: "This device", text: summary(model.syncFields()), deleted: model.isTrashed)
                version(title: "Other device", text: summary(model.conflictCopy?.fields ?? [:]), deleted: model.conflictCopy?.deletedAt != nil)
            }
            HStack {
                Button("Keep this device's") { sync.resolve(model, keepThisDevice: true) }
                Button("Keep other device's") { sync.resolve(model, keepThisDevice: false) }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }

    private var kindName: String {
        type(of: model).syncTable == Workspace.syncTable ? "Workspace" : "Task"
    }

    private func version(title: String, text: String, deleted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.bold())
            Text(deleted ? "Deleted" : text).font(.callout)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The fields a person recognises, in a readable line.
    private func summary(_ fields: [String: JSONValue]) -> String {
        var parts: [String] = []
        if let name = fields["title"]?.stringValue ?? fields["name"]?.stringValue { parts.append(name) }
        if let status = fields["status"]?.stringValue.flatMap(TaskStatus.init(rawValue:)) { parts.append(status.title) }
        if let due = fields["due_at"]?.dateValue { parts.append("due " + due.formatted(date: .abbreviated, time: .shortened)) }
        return parts.isEmpty ? "(no details)" : parts.joined(separator: " · ")
    }
}
