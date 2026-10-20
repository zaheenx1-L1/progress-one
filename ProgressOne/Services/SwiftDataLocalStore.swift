import Foundation
import SwiftData
import ProgressCore

/// The device's SwiftData database, as the sync engine sees it.
///
/// Runs on the main actor and uses the same context as the UI, so synced changes show
/// up on screen immediately.
@MainActor
final class SwiftDataLocalStore: LocalStore {
    /// Tables in sync order: parents before children.
    static let tables = [Workspace.syncTable, TaskItem.syncTable]

    private let context: ModelContext
    private let cursorKeyPrefix: String

    /// `accountID` keeps pull positions separate per signed-in account.
    init(context: ModelContext, accountID: UUID) {
        self.context = context
        self.cursorKeyPrefix = "sync.cursor.\(accountID.uuidString.lowercased())."
    }

    // MARK: LocalStore

    func dirtyRecords(table: String) async throws -> [LocalRecord] {
        try allRecords(table: table)
            .filter { $0.syncIsDirty && $0.syncConflict == nil }
            .map { $0.localRecord() }
    }

    func syncState(table: String, id: UUID) async throws -> LocalSyncState? {
        guard let model = try find(table: table, id: id) else { return nil }
        return LocalSyncState(baseVersion: model.syncBaseVersion, isDirty: model.syncIsDirty, hasConflict: model.syncConflict != nil)
    }

    func applyRemote(_ row: RemoteRow, table: String) async throws {
        let model = try find(table: table, id: row.id) ?? insertNew(table: table, id: row.id)
        model.apply(remote: row)
        try context.save()
    }

    func markPushed(table: String, id: UUID, version: Int, pushedRevision: Int) async throws {
        guard let model = try find(table: table, id: id) else { return }
        model.syncBaseVersion = version
        if model.syncRevision == pushedRevision {
            model.syncIsDirty = false
        }
        try context.save()
    }

    func markConflict(table: String, id: UUID, remote: RemoteRow) async throws {
        guard let model = try find(table: table, id: id) else { return }
        model.syncConflict = try JSONEncoder().encode(remote)
        try context.save()
    }

    func pullCursor(table: String) async throws -> PullCursor? {
        guard let data = UserDefaults.standard.data(forKey: cursorKeyPrefix + table) else { return nil }
        return try? JSONDecoder().decode(PullCursor.self, from: data)
    }

    func setPullCursor(_ cursor: PullCursor, table: String) async throws {
        UserDefaults.standard.set(try JSONEncoder().encode(cursor), forKey: cursorKeyPrefix + table)
    }

    // MARK: Status counts and conflict decisions

    func pendingCount() -> Int {
        Self.tables.reduce(0) { total, table in
            total + ((try? allRecords(table: table).filter { $0.syncIsDirty && $0.syncConflict == nil }.count) ?? 0)
        }
    }

    func conflicts() -> [any SyncedModel] {
        Self.tables.flatMap { table in
            (try? allRecords(table: table).filter { $0.syncConflict != nil }) ?? []
        }
    }

    /// Keep this device's version; it is sent on the next sync and replaces the other copy.
    func resolveKeepingThisDevice(_ model: any SyncedModel) {
        guard let remote = model.conflictCopy else { return }
        model.syncBaseVersion = remote.version
        model.syncConflict = nil
        model.markEdited()
        try? context.save()
    }

    /// Use the other device's version and drop this device's unsent edit.
    func resolveKeepingOtherDevice(_ model: any SyncedModel) {
        guard let remote = model.conflictCopy else { return }
        model.apply(remote: remote)
        try? context.save()
    }

    // MARK: Lookup

    private func allRecords(table: String) throws -> [any SyncedModel] {
        switch table {
        case Workspace.syncTable:
            return try context.fetch(FetchDescriptor<Workspace>())
        case TaskItem.syncTable:
            return try context.fetch(FetchDescriptor<TaskItem>())
        default:
            return []
        }
    }

    private func find(table: String, id: UUID) throws -> (any SyncedModel)? {
        let target = id
        switch table {
        case Workspace.syncTable:
            var descriptor = FetchDescriptor<Workspace>(predicate: #Predicate { $0.id == target })
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first
        case TaskItem.syncTable:
            var descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == target })
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first
        default:
            return nil
        }
    }

    private func insertNew(table: String, id: UUID) throws -> any SyncedModel {
        switch table {
        case Workspace.syncTable:
            let model = Workspace(id: id)
            context.insert(model)
            return model
        case TaskItem.syncTable:
            let model = TaskItem(id: id)
            context.insert(model)
            return model
        default:
            throw SyncError.invalidResponse("Unknown table \(table)")
        }
    }
}
