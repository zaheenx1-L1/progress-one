import Foundation

/// The outcome of one sync pass, shown to the user as the sync status.
public struct SyncReport: Sendable, Equatable {
    public var pushed = 0
    public var pulled = 0
    public var newConflicts = 0
    public var error: SyncError?

    public init() {}

    public var succeeded: Bool { error == nil }
}

/// Two-way sync between one device's local store and the cloud.
///
/// Each pass pushes this device's unsent edits, then pulls everything that changed on the
/// server since the last pass. The server rejects an edit made against an old version, so a
/// record changed on two devices becomes a visible conflict instead of a silent overwrite.
public actor SyncEngine {
    private let tables: [String]
    private let local: any LocalStore
    private let remote: any RemoteBackend
    private let pageSize: Int
    private var isRunning = false

    /// `tables` are synced in order, so list parent records (e.g. workspaces) before children.
    public init(tables: [String], local: any LocalStore, remote: any RemoteBackend, pageSize: Int = 500) {
        self.tables = tables
        self.local = local
        self.remote = remote
        self.pageSize = pageSize
    }

    public func sync() async -> SyncReport {
        var report = SyncReport()
        guard !isRunning else { return report }
        isRunning = true
        defer { isRunning = false }

        do {
            for table in tables {
                try await push(table: table, report: &report)
            }
            for table in tables {
                try await pull(table: table, report: &report)
            }
        } catch let error as SyncError {
            report.error = error
        } catch {
            report.error = .invalidResponse(String(describing: error))
        }
        return report
    }

    private func push(table: String, report: inout SyncReport) async throws {
        for record in try await local.dirtyRecords(table: table) {
            do {
                let saved = try await remote.upsert(
                    table: table,
                    id: record.id,
                    baseVersion: record.baseVersion,
                    deletedAt: record.deletedAt,
                    fields: record.fields
                )
                try await local.markPushed(table: table, id: record.id, version: saved.version, pushedRevision: record.localRevision)
                report.pushed += 1
            } catch SyncError.versionConflict {
                guard let serverCopy = try await remote.fetch(table: table, id: record.id) else {
                    throw SyncError.invalidResponse("Server reported a conflict for a record it does not have")
                }
                if ConflictPolicy.isSameContent(local: record, remote: serverCopy) {
                    try await local.markPushed(table: table, id: record.id, version: serverCopy.version, pushedRevision: record.localRevision)
                } else {
                    try await local.markConflict(table: table, id: record.id, remote: serverCopy)
                    report.newConflicts += 1
                }
            }
        }
    }

    private func pull(table: String, report: inout SyncReport) async throws {
        var cursor = try await local.pullCursor(table: table)
        while true {
            let rows = try await remote.changes(table: table, after: cursor, limit: pageSize)
            for row in rows {
                let state = try await local.syncState(table: table, id: row.id)
                switch ConflictPolicy.decide(local: state, remoteVersion: row.version) {
                case .insert, .apply:
                    try await local.applyRemote(row, table: table)
                    report.pulled += 1
                case .ignore:
                    break
                case .conflict:
                    // Refresh the stored server copy; count it only the first time.
                    try await local.markConflict(table: table, id: row.id, remote: row)
                    if state?.hasConflict != true { report.newConflicts += 1 }
                }
            }
            guard let last = rows.last else { break }
            cursor = PullCursor(updatedAtRaw: last.updatedAtRaw, id: last.id)
            try await local.setPullCursor(cursor!, table: table)
            if rows.count < pageSize { break }
        }
    }
}
