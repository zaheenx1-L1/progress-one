import Foundation
import SwiftData
import ProgressCore

/// A business or personal area of life (spec Part 6).
@Model
final class Workspace: SyncedModel {
    static var syncTable: String { "workspaces" }

    @Attribute(.unique) var id: UUID
    var name: String
    var kindRaw: String
    var symbol: String
    var colorHex: String
    var sortOrder: Int
    var isPrivate: Bool
    var archivedAt: Date?

    var syncBaseVersion: Int
    var syncIsDirty: Bool
    var syncRevision: Int
    var syncDeletedAt: Date?
    var syncConflict: Data?
    var lastModified: Date

    init(id: UUID) {
        self.id = id
        self.name = "New workspace"
        self.kindRaw = WorkspaceKind.business.rawValue
        self.symbol = "briefcase"
        self.colorHex = "#0A84FF"
        self.sortOrder = 100
        self.isPrivate = false
        self.archivedAt = nil
        self.syncBaseVersion = 0
        self.syncIsDirty = true
        self.syncRevision = 1
        self.syncDeletedAt = nil
        self.syncConflict = nil
        self.lastModified = .now
    }

    static func make(from seed: WorkspaceSeed) -> Workspace {
        let workspace = Workspace(id: seed.id)
        workspace.name = seed.name
        workspace.kindRaw = seed.kind.rawValue
        workspace.symbol = seed.symbol
        workspace.colorHex = seed.colorHex
        workspace.sortOrder = seed.sortOrder
        workspace.isPrivate = seed.isPrivate
        // Every device creates the same defaults, so they are not sent until edited.
        workspace.syncIsDirty = false
        return workspace
    }

    var kind: WorkspaceKind {
        get { WorkspaceKind(rawValue: kindRaw) ?? .business }
        set { kindRaw = newValue.rawValue }
    }

    var isActive: Bool { archivedAt == nil && !isTrashed }

    func syncFields() -> [String: JSONValue] {
        [
            "name": .string(name),
            "kind": .string(kindRaw),
            "symbol": .string(symbol),
            "color_hex": .string(colorHex),
            "sort_order": .int(sortOrder),
            "is_private": .bool(isPrivate),
            "archived_at": .date(archivedAt),
        ]
    }

    func applySyncFields(_ fields: [String: JSONValue]) {
        name = fields["name"]?.stringValue ?? name
        kindRaw = fields["kind"]?.stringValue ?? kindRaw
        symbol = fields["symbol"]?.stringValue ?? symbol
        colorHex = fields["color_hex"]?.stringValue ?? colorHex
        sortOrder = fields["sort_order"]?.intValue ?? sortOrder
        isPrivate = fields["is_private"]?.boolValue ?? isPrivate
        archivedAt = fields["archived_at"]?.dateValue
    }
}
