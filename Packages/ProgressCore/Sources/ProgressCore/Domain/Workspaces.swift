import Foundation

public enum WorkspaceKind: String, Sendable, CaseIterable, Codable {
    case business
    case personal
}

/// The four workspaces from the spec (Part 6), created on every device on first launch.
///
/// Their ids are fixed so the same workspace on two devices is one record, not a duplicate.
public struct WorkspaceSeed: Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let kind: WorkspaceKind
    public let symbol: String
    public let colorHex: String
    public let isPrivate: Bool
    public let sortOrder: Int

    public static let all: [WorkspaceSeed] = [
        WorkspaceSeed(id: UUID(uuidString: "00000000-0000-4000-8000-0000000000a1")!, name: "iExpert Technologies", kind: .business, symbol: "wrench.and.screwdriver", colorHex: "#0A84FF", isPrivate: false, sortOrder: 0),
        WorkspaceSeed(id: UUID(uuidString: "00000000-0000-4000-8000-0000000000a2")!, name: "iExpert Training Academy", kind: .business, symbol: "graduationcap", colorHex: "#5E5CE6", isPrivate: false, sortOrder: 1),
        WorkspaceSeed(id: UUID(uuidString: "00000000-0000-4000-8000-0000000000a3")!, name: "Greentick Real Estate", kind: .business, symbol: "building.2", colorHex: "#30D158", isPrivate: false, sortOrder: 2),
        WorkspaceSeed(id: UUID(uuidString: "00000000-0000-4000-8000-0000000000a4")!, name: "Personal Life", kind: .personal, symbol: "person.crop.circle", colorHex: "#FF9F0A", isPrivate: true, sortOrder: 3),
    ]
}
