import Foundation
import SwiftData
import ProgressCore

/// A SwiftData model that syncs between devices.
///
/// Every edit made through the UI must call `markEdited()`, which queues the record for the
/// next sync. Deletions are soft (`softDelete()`) so they reach the other device.
protocol SyncedModel: PersistentModel {
    static var syncTable: String { get }

    var id: UUID { get }
    /// The server version this device last saw. 0 means never synced.
    var syncBaseVersion: Int { get set }
    var syncIsDirty: Bool { get set }
    var syncRevision: Int { get set }
    var syncDeletedAt: Date? { get set }
    /// The other device's copy, encoded `RemoteRow`, while waiting for the user's decision.
    var syncConflict: Data? { get set }
    var lastModified: Date { get set }

    init(id: UUID)

    /// This record's columns as the server stores them (without the sync columns).
    func syncFields() -> [String: JSONValue]
    func applySyncFields(_ fields: [String: JSONValue])
}

extension SyncedModel {
    func markEdited() {
        syncIsDirty = true
        syncRevision += 1
        lastModified = .now
    }

    func softDelete() {
        syncDeletedAt = .now
        markEdited()
    }

    var isTrashed: Bool { syncDeletedAt != nil }

    var conflictCopy: RemoteRow? {
        syncConflict.flatMap { try? JSONDecoder().decode(RemoteRow.self, from: $0) }
    }

    func localRecord() -> LocalRecord {
        LocalRecord(
            id: id,
            baseVersion: syncBaseVersion,
            isDirty: syncIsDirty,
            localRevision: syncRevision,
            deletedAt: syncDeletedAt,
            fields: syncFields()
        )
    }

    /// Overwrites this record with the server's copy.
    func apply(remote row: RemoteRow) {
        applySyncFields(row.fields)
        syncBaseVersion = row.version
        syncDeletedAt = row.deletedAt
        syncIsDirty = false
        syncConflict = nil
        lastModified = row.updatedAt ?? .now
    }
}
