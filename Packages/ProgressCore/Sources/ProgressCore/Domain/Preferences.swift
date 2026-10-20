import Foundation

/// User-level settings from spec Parts 10 and 38: Asia/Dubai, AED, and a configurable first day of week.
public struct RegionalPreferences: Sendable, Equatable, Codable {
    public var timeZoneIdentifier: String
    public var currencyCode: String
    /// 1 = Sunday … 7 = Saturday, as in `Calendar.firstWeekday`.
    public var firstWeekday: Int

    public static let `default` = RegionalPreferences(timeZoneIdentifier: "Asia/Dubai", currencyCode: "AED", firstWeekday: 2)

    public init(timeZoneIdentifier: String, currencyCode: String, firstWeekday: Int) {
        self.timeZoneIdentifier = timeZoneIdentifier
        self.currencyCode = currencyCode
        self.firstWeekday = firstWeekday
    }

    public var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? TimeZone(identifier: "Asia/Dubai")!
    }

    public var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    /// The week containing `date`, as a half-open interval in the user's time zone.
    public func week(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date)!
    }

    public func month(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .month, for: date)!
    }
}
