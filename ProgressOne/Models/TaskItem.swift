import Foundation
import SwiftData
import ProgressCore

/// A task (spec Part 12). Named `TaskItem` to avoid clashing with Swift's `Task`.
@Model
final class TaskItem: SyncedModel {
    static var syncTable: String { "tasks" }

    @Attribute(.unique) var id: UUID
    var workspaceID: UUID?
    var title: String
    var notes: String
    var statusRaw: String
    var priorityRaw: Int
    var dueAt: Date?
    var completedAt: Date?
    var sortOrder: Double

    var syncBaseVersion: Int
    var syncIsDirty: Bool
    var syncRevision: Int
    var syncDeletedAt: Date?
    var syncConflict: Data?
    var lastModified: Date

    init(id: UUID) {
        self.id = id
        self.workspaceID = nil
        self.title = ""
        self.notes = ""
        self.statusRaw = TaskStatus.todo.rawValue
        self.priorityRaw = TaskPriority.medium.rawValue
        self.dueAt = nil
        self.completedAt = nil
        self.sortOrder = Date.now.timeIntervalSince1970
        self.syncBaseVersion = 0
        self.syncIsDirty = true
        self.syncRevision = 1
        self.syncDeletedAt = nil
        self.syncConflict = nil
        self.lastModified = .now
    }

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .todo }
        set {
            statusRaw = newValue.rawValue
            completedAt = newValue == .done ? (completedAt ?? .now) : nil
        }
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    func syncFields() -> [String: JSONValue] {
        [
            "workspace_id": .uuid(workspaceID),
            "title": .string(title),
            "notes": .string(notes),
            "status": .string(statusRaw),
            "priority": .int(priorityRaw),
            "due_at": .date(dueAt),
            "completed_at": .date(completedAt),
            "sort_order": .number(sortOrder),
        ]
    }

    func applySyncFields(_ fields: [String: JSONValue]) {
        workspaceID = fields["workspace_id"]?.uuidValue
        title = fields["title"]?.stringValue ?? title
        notes = fields["notes"]?.stringValue ?? notes
        statusRaw = fields["status"]?.stringValue ?? statusRaw
        priorityRaw = fields["priority"]?.intValue ?? priorityRaw
        dueAt = fields["due_at"]?.dateValue
        completedAt = fields["completed_at"]?.dateValue
        sortOrder = fields["sort_order"]?.doubleValue ?? sortOrder
    }
}
