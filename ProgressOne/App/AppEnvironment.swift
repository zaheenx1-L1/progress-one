import Foundation
import Observation
import SwiftData
import ProgressCore

/// Owns the app's long-lived services and the local database.
@MainActor
@Observable
final class AppEnvironment {
    let container: ModelContainer
    let auth: AuthStore
    let sync: SyncCoordinator
    let preferences: PreferencesStore
    let appLock: AppLock

    /// Set by the menu command or toolbar button to open the quick-add sheet.
    var quickAddRequested = false
    /// Set if the database could not be opened, so the app runs in memory and says so.
    private(set) var storageWarning: String?

    init() {
        let schema = Schema([Workspace.self, TaskItem.self])
        let container: ModelContainer
        var warning: String?
        do {
            container = try ModelContainer(for: schema, configurations: ModelConfiguration("ProgressOne", schema: schema, cloudKitDatabase: .none))
        } catch {
            warning = "Your data could not be opened and changes won't be saved: \(error.localizedDescription)"
            container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
        self.container = container

        let auth = AuthStore()
        self.auth = auth
        self.preferences = PreferencesStore()
        self.appLock = AppLock()
        Self.seedWorkspacesIfNeeded(in: container.mainContext)
        self.sync = SyncCoordinator(context: container.mainContext, auth: auth)
        self.storageWarning = warning
        if preferences.appLockEnabled { appLock.lock() }
    }

    private static func seedWorkspacesIfNeeded(in context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Workspace>())) ?? 0
        guard existing == 0 else { return }
        for seed in WorkspaceSeed.all {
            context.insert(Workspace.make(from: seed))
        }
        try? context.save()
    }
}
