import Foundation

/// A local store kept in memory. Used by tests and previews to stand in for a device.
public actor InMemoryLocalStore: LocalStore {
    public struct Entry: Sendable, Equatable {
        public var record: LocalRecord
        public var conflict: RemoteRow?
    }

    private var tables: [String: [UUID: Entry]] = [:]
    private var cursors: [String: PullCursor] = [:]

    public init() {}

    // MARK: Local edits (what the app's UI does)

    public func create(table: String, id: UUID = UUID(), fields: [String: JSONValue]) -> UUID {
        tables[table, default: [:]][id] = Entry(
            record: LocalRecord(id: id, baseVersion: 0, isDirty: true, localRevision: 1, deletedAt: nil, fields: fields),
            conflict: nil
        )
        return id
    }

    public func edit(table: String, id: UUID, _ change: @Sendable (inout [String: JSONValue]) -> Void) {
        guard var entry = tables[table]?[id] else { return }
        change(&entry.record.fields)
        entry.record.isDirty = true
        entry.record.localRevision += 1
        tables[table]![id] = entry
    }

    public func delete(table: String, id: UUID, at date: Date = Date()) {
        guard var entry = tables[table]?[id] else { return }
        entry.record.deletedAt = date
        entry.record.isDirty = true
        entry.record.localRevision += 1
        tables[table]![id] = entry
    }

    public func entry(table: String, id: UUID) -> Entry? {
        tables[table]?[id]
    }

    public func allEntries(table: String) -> [Entry] {
        Array(tables[table, default: [:]].values)
    }

    /// Conflict resolution: keep this device's version and send it on the next sync.
    public func resolveKeepingLocal(table: String, id: UUID) {
        guard var entry = tables[table]?[id], let remote = entry.conflict else { return }
        entry.record.baseVersion = remote.version
        entry.record.isDirty = true
        entry.conflict = nil
        tables[table]![id] = entry
    }

    /// Conflict resolution: take the other device's version.
    public func resolveKeepingRemote(table: String, id: UUID) {
        guard let remote = tables[table]?[id]?.conflict else { return }
        store(remote, table: table)
    }

    // MARK: LocalStore

    public func dirtyRecords(table: String) -> [LocalRecord] {
        tables[table, default: [:]].values
            .filter { $0.record.isDirty && $0.conflict == nil }
            .map(\.record)
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    public func syncState(table: String, id: UUID) -> LocalSyncState? {
        tables[table]?[id].map {
            LocalSyncState(baseVersion: $0.record.baseVersion, isDirty: $0.record.isDirty, hasConflict: $0.conflict != nil)
        }
    }

    public func applyRemote(_ row: RemoteRow, table: String) {
        store(row, table: table)
    }

    public func markPushed(table: String, id: UUID, version: Int, pushedRevision: Int) {
        guard var entry = tables[table]?[id] else { return }
        entry.record.baseVersion = version
        if entry.record.localRevision == pushedRevision {
            entry.record.isDirty = false
        }
        tables[table]![id] = entry
    }

    public func markConflict(table: String, id: UUID, remote: RemoteRow) {
        tables[table]?[id]?.conflict = remote
    }

    public func pullCursor(table: String) -> PullCursor? {
        cursors[table]
    }

    public func setPullCursor(_ cursor: PullCursor, table: String) {
        cursors[table] = cursor
    }

    private func store(_ row: RemoteRow, table: String) {
        let revision = tables[table]?[row.id]?.record.localRevision ?? 0
        tables[table, default: [:]][row.id] = Entry(
            record: LocalRecord(
                id: row.id,
                baseVersion: row.version,
                isDirty: false,
                localRevision: revision,
                deletedAt: row.deletedAt,
                fields: row.fields
            ),
            conflict: nil
        )
    }
}

/// A server kept in memory that follows the same version rules as the Supabase database trigger.
public actor InMemoryBackend: RemoteBackend {
    private var tables: [String: [UUID: RemoteRow]] = [:]
    private var tick = 0
    /// When true, every call fails as if the device had no connection.
    public var isOffline = false
    /// When set, every write gets this timestamp, to test rows that share an `updated_at`.
    public var frozenTimestamp: String?
    /// When true, the next upsert is saved but its response is lost.
    public var dropNextResponse = false

    public init() {}

    public func setOffline(_ value: Bool) { isOffline = value }
    public func setFrozenTimestamp(_ value: String?) { frozenTimestamp = value }
    public func setDropNextResponse(_ value: Bool) { dropNextResponse = value }

    public func row(table: String, id: UUID) -> RemoteRow? { tables[table]?[id] }
    public func rowCount(table: String) -> Int { tables[table]?.count ?? 0 }

    public func upsert(table: String, id: UUID, baseVersion: Int, deletedAt: Date?, fields: [String: JSONValue]) throws -> RemoteRow {
        guard !isOffline else { throw SyncError.offline }
        let existing = tables[table]?[id]
        if let existing, existing.version != baseVersion {
            throw SyncError.versionConflict
        }
        let row = RemoteRow(
            id: id,
            version: (existing?.version ?? 0) + 1,
            updatedAtRaw: nextTimestamp(),
            deletedAt: deletedAt,
            fields: (existing?.fields ?? [:]).merging(fields) { $1 }
        )
        tables[table, default: [:]][id] = row
        if dropNextResponse {
            dropNextResponse = false
            throw SyncError.offline
        }
        return row
    }

    public func fetch(table: String, id: UUID) throws -> RemoteRow? {
        guard !isOffline else { throw SyncError.offline }
        return tables[table]?[id]
    }

    public func changes(table: String, after cursor: PullCursor?, limit: Int) throws -> [RemoteRow] {
        guard !isOffline else { throw SyncError.offline }
        let sorted = tables[table, default: [:]].values.sorted {
            ($0.updatedAtRaw, $0.id.uuidString.lowercased()) < ($1.updatedAtRaw, $1.id.uuidString.lowercased())
        }
        let after = sorted.filter { row in
            guard let cursor else { return true }
            return (row.updatedAtRaw, row.id.uuidString.lowercased()) > (cursor.updatedAtRaw, cursor.id.uuidString.lowercased())
        }
        return Array(after.prefix(limit))
    }

    private func nextTimestamp() -> String {
        if let frozenTimestamp { return frozenTimestamp }
        tick += 1
        let date = Date(timeIntervalSince1970: 1_800_000_000 + Double(tick) / 1000)
        return PostgresTimestamp.format(date)
    }
}
