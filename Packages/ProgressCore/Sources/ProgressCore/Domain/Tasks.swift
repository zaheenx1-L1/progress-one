import Foundation

public enum TaskStatus: String, Sendable, CaseIterable, Codable {
    case todo
    case inProgress = "in_progress"
    case done
    case cancelled

    /// Spec Part 12: a task stays visible until it is completed, cancelled, or rescheduled.
    public var isOpen: Bool { self == .todo || self == .inProgress }

    public var title: String {
        switch self {
        case .todo: "To do"
        case .inProgress: "In progress"
        case .done: "Done"
        case .cancelled: "Cancelled"
        }
    }
}

public enum TaskPriority: Int, Sendable, CaseIterable, Codable, Comparable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4

    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool { lhs.rawValue < rhs.rawValue }

    public var title: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .critical: "Critical"
        }
    }
}

/// The list views from spec Part 12 that Step 1 provides.
public enum TaskBucket: String, Sendable, CaseIterable, Identifiable {
    case today
    case overdue
    case upcoming
    case someday
    case completed
    case all

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .today: "Today"
        case .overdue: "Overdue"
        case .upcoming: "Upcoming"
        case .someday: "No date"
        case .completed: "Completed"
        case .all: "All tasks"
        }
    }

    /// Whether a task belongs in this bucket. `calendar` carries the user's time zone.
    public func contains(status: TaskStatus, dueAt: Date?, now: Date, calendar: Calendar) -> Bool {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        switch self {
        case .all:
            return true
        case .completed:
            return status == .done
        case .overdue:
            guard status.isOpen, let dueAt else { return false }
            return dueAt < startOfToday
        case .today:
            // Overdue open tasks also show on Today, so unfinished work never disappears.
            guard status.isOpen, let dueAt else { return false }
            return dueAt < startOfTomorrow
        case .upcoming:
            guard status.isOpen, let dueAt else { return false }
            return dueAt >= startOfTomorrow
        case .someday:
            return status.isOpen && dueAt == nil
        }
    }
}
