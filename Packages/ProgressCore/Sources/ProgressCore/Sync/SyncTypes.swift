import Foundation

/// A record as the server stores it.
///
/// `version` and `updatedAt` are assigned by the server only (see `supabase/migrations`).
/// `updatedAtRaw` keeps the server's exact text so pull cursors never lose precision.
public struct RemoteRow: Sendable, Equatable, Codable {
    public var id: UUID
    public var version: Int
    public var updatedAtRaw: String
    public var deletedAt: Date?
    public var fields: [String: JSONValue]

    public init(id: UUID, version: Int, updatedAtRaw: String, deletedAt: Date?, fields: [String: JSONValue]) {
        self.id = id
        self.version = version
        self.updatedAtRaw = updatedAtRaw
        self.deletedAt = deletedAt
        self.fields = fields
    }

    public var updatedAt: Date? { PostgresTimestamp.parse(updatedAtRaw) }
}

/// A record as one device holds it.
public struct LocalRecord: Sendable, Equatable {
    public var id: UUID
    /// The server version this device last saw. 0 means the server has never had it.
    public var baseVersion: Int
    public var isDirty: Bool
    /// Increases on every local edit, so a push can tell if the record changed while it was in flight.
    public var localRevision: Int
    public var deletedAt: Date?
    public var fields: [String: JSONValue]

    public init(id: UUID, baseVersion: Int, isDirty: Bool, localRevision: Int, deletedAt: Date?, fields: [String: JSONValue]) {
        self.id = id
        self.baseVersion = baseVersion
        self.isDirty = isDirty
        self.localRevision = localRevision
        self.deletedAt = deletedAt
        self.fields = fields
    }
}

/// The sync state of one local record, enough to decide what to do with an incoming change.
public struct LocalSyncState: Sendable, Equatable {
    public var baseVersion: Int
    public var isDirty: Bool
    /// The record is already waiting on the user's conflict decision.
    public var hasConflict: Bool

    public init(baseVersion: Int, isDirty: Bool, hasConflict: Bool = false) {
        self.baseVersion = baseVersion
        self.isDirty = isDirty
        self.hasConflict = hasConflict
    }
}

/// Position in a table's change feed: rows are read in (updated_at, id) order.
public struct PullCursor: Sendable, Equatable, Codable {
    public var updatedAtRaw: String
    public var id: UUID

    public init(updatedAtRaw: String, id: UUID) {
        self.updatedAtRaw = updatedAtRaw
        self.id = id
    }
}

public enum SyncError: Error, Equatable, Sendable {
    /// The server has a newer version than the one this device edited.
    case versionConflict
    /// The network or server could not be reached.
    case offline
    /// The session expired and could not be refreshed.
    case unauthorized
    case server(status: Int, message: String)
    case invalidResponse(String)
}

/// Where the device's local database is reached from the sync engine.
public protocol LocalStore: Sendable {
    /// Records with unsent edits, excluding records waiting on the user's conflict decision.
    func dirtyRecords(table: String) async throws -> [LocalRecord]
    func syncState(table: String, id: UUID) async throws -> LocalSyncState?
    /// Overwrites the local record with the server's copy and clears dirty and conflict flags.
    func applyRemote(_ row: RemoteRow, table: String) async throws
    /// Records a successful push. The dirty flag clears only if `pushedRevision` is still the latest local edit.
    func markPushed(table: String, id: UUID, version: Int, pushedRevision: Int) async throws
    /// Keeps the local edit and stores the server copy so the user can choose between them.
    func markConflict(table: String, id: UUID, remote: RemoteRow) async throws
    func pullCursor(table: String) async throws -> PullCursor?
    func setPullCursor(_ cursor: PullCursor, table: String) async throws
}

/// Where the cloud database is reached from the sync engine.
public protocol RemoteBackend: Sendable {
    /// Inserts or updates a row. `baseVersion` must equal the server's current version, otherwise `SyncError.versionConflict`.
    func upsert(table: String, id: UUID, baseVersion: Int, deletedAt: Date?, fields: [String: JSONValue]) async throws -> RemoteRow
    func fetch(table: String, id: UUID) async throws -> RemoteRow?
    /// Rows changed after `cursor`, in (updated_at, id) order.
    func changes(table: String, after cursor: PullCursor?, limit: Int) async throws -> [RemoteRow]
}
