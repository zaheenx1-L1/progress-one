import Foundation
import Network
import Observation
import SwiftData
import ProgressCore

/// Decides when to sync and publishes the sync status the user sees (spec Part 3.4).
@MainActor
@Observable
final class SyncCoordinator {
    /// The six states the spec asks the app to show.
    enum DisplayState: Equatable {
        case localOnly
        case synced
        case syncing
        case offline
        case pending(Int)
        case conflicts(Int)
        case error(String)

        var title: String {
            switch self {
            case .localOnly: "On this device only"
            case .synced: "Synced"
            case .syncing: "Syncing…"
            case .offline: "Offline"
            case .pending(let count): count == 1 ? "1 change waiting" : "\(count) changes waiting"
            case .conflicts(let count): count == 1 ? "1 conflict needs you" : "\(count) conflicts need you"
            case .error: "Sync problem"
            }
        }

        var symbol: String {
            switch self {
            case .localOnly: "iphone.and.arrow.forward"
            case .synced: "checkmark.icloud"
            case .syncing: "arrow.triangle.2.circlepath.icloud"
            case .offline: "icloud.slash"
            case .pending: "icloud.and.arrow.up"
            case .conflicts: "exclamationmark.icloud"
            case .error: "xmark.icloud"
            }
        }
    }

    private(set) var isSyncing = false
    private(set) var isOnline = true
    /// The device has a connection but the last sync couldn't reach the server.
    private(set) var serverUnreachable = false
    private(set) var lastSuccess: Date?
    private(set) var lastError: String?
    private(set) var pendingCount = 0
    private(set) var conflictCount = 0

    private let context: ModelContext
    private let auth: AuthStore
    private var store: SwiftDataLocalStore?
    private var engine: SyncEngine?
    private var engineAccount: UUID?
    private var scheduled: Task<Void, Never>?
    private var heartbeat: Task<Void, Never>?
    private let monitor = NWPathMonitor()

    init(context: ModelContext, auth: AuthStore) {
        self.context = context
        self.auth = auth
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.networkChanged(online: online) }
        }
        monitor.start(queue: DispatchQueue(label: "app.progressone.network"))
        refreshCounts()
    }

    var displayState: DisplayState {
        guard auth.mode == .signedIn else { return .localOnly }
        if conflictCount > 0 { return .conflicts(conflictCount) }
        if isSyncing { return .syncing }
        if !isOnline || serverUnreachable { return .offline }
        if let lastError { return .error(lastError) }
        if pendingCount > 0 { return .pending(pendingCount) }
        return .synced
    }

    /// Call after any local edit. Waits briefly so a burst of edits becomes one sync.
    func requestSync(after delay: Duration = .seconds(2)) {
        refreshCounts()
        scheduled?.cancel()
        scheduled = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    func syncNow() async {
        guard auth.mode == .signedIn, isOnline, !isSyncing, let engine = currentEngine() else {
            refreshCounts()
            return
        }
        isSyncing = true
        let report = await engine.sync()
        isSyncing = false

        serverUnreachable = report.error == .offline
        switch report.error {
        case nil:
            lastSuccess = .now
            lastError = nil
        case .offline?:
            break
        case .unauthorized?:
            lastError = "Please sign in again."
        case .server(_, let message)?:
            lastError = message
        case .invalidResponse(let message)?:
            lastError = message
        case .versionConflict?:
            lastError = nil
        }
        refreshCounts()
    }

    /// Syncs every minute while the app is open, and immediately when it comes to the front.
    func appBecameActive() {
        requestSync(after: .milliseconds(200))
        heartbeat?.cancel()
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                await self?.syncNow()
            }
        }
    }

    func appWentToBackground() {
        heartbeat?.cancel()
        heartbeat = nil
    }

    func refreshCounts() {
        let local = localStore()
        pendingCount = local?.pendingCount() ?? 0
        conflictCount = local?.conflicts().count ?? 0
    }

    func conflicts() -> [any SyncedModel] {
        localStore()?.conflicts() ?? []
    }

    func resolve(_ model: any SyncedModel, keepThisDevice: Bool) {
        guard let local = localStore() else { return }
        if keepThisDevice {
            local.resolveKeepingThisDevice(model)
        } else {
            local.resolveKeepingOtherDevice(model)
        }
        requestSync(after: .milliseconds(200))
    }

    private func networkChanged(online: Bool) {
        let cameBack = online && !isOnline
        isOnline = online
        if cameBack { requestSync(after: .milliseconds(500)) }
    }

    private func localStore() -> SwiftDataLocalStore? {
        // Local-only mode still counts edits so the user sees them waiting once they sign in.
        let account = auth.session?.userID ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        if let store, engineAccount == account { return store }
        let newStore = SwiftDataLocalStore(context: context, accountID: account)
        store = newStore
        engine = nil
        engineAccount = account
        return newStore
    }

    private func currentEngine() -> SyncEngine? {
        guard let config = auth.config, auth.session != nil, let local = localStore() else { return nil }
        if let engine { return engine }
        let auth = self.auth
        let backend = SupabaseBackend(config: config) { try await auth.validAccessToken() }
        let newEngine = SyncEngine(tables: SwiftDataLocalStore.tables, local: local, remote: backend)
        engine = newEngine
        return newEngine
    }
}
