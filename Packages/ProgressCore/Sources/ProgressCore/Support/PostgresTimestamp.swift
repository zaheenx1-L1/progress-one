import Foundation

/// Parses and formats the timestamp strings Postgres (via PostgREST) sends and accepts.
///
/// Postgres returns microsecond precision and `+00:00` offsets, which Foundation's
/// ISO-8601 formatter does not reliably handle on every platform, so this is done by hand.
public enum PostgresTimestamp {
    /// Formats in UTC with millisecond precision, e.g. `2026-10-20T04:38:56.692Z`.
    public static func format(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let totalMillis = (date.timeIntervalSince1970 * 1000).rounded()
        let wholeSeconds = (totalMillis / 1000).rounded(.down)
        let millis = Int(totalMillis - wholeSeconds * 1000)
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date(timeIntervalSince1970: wholeSeconds))
        return "\(pad(parts.year!, 4))-\(pad(parts.month!, 2))-\(pad(parts.day!, 2))"
            + "T\(pad(parts.hour!, 2)):\(pad(parts.minute!, 2)):\(pad(parts.second!, 2)).\(pad(millis, 3))Z"
    }

    private static func pad(_ value: Int, _ width: Int) -> String {
        let text = String(value)
        return String(repeating: "0", count: max(0, width - text.count)) + text
    }

    /// Accepts `YYYY-MM-DD[T ]HH:MM[:SS[.fraction]][Z|±HH[:MM]]`, or a bare `YYYY-MM-DD` (read as UTC midnight).
    public static func parse(_ text: String) -> Date? {
        let chars = Array(text.trimmingCharacters(in: .whitespaces))
        var index = 0

        func number(_ length: Int) -> Int? {
            guard index + length <= chars.count else { return nil }
            var value = 0
            for offset in 0..<length {
                guard let digit = chars[index + offset].wholeNumberValue else { return nil }
                value = value * 10 + digit
            }
            index += length
            return value
        }

        func expect(_ character: Character) -> Bool {
            guard index < chars.count, chars[index] == character else { return false }
            index += 1
            return true
        }

        guard let year = number(4), expect("-"), let month = number(2), expect("-"), let day = number(2) else {
            return nil
        }

        var hour = 0, minute = 0, second = 0
        var fraction = 0.0
        var offsetSeconds = 0

        if index < chars.count {
            guard chars[index] == "T" || chars[index] == " " else { return nil }
            index += 1
            guard let h = number(2), expect(":"), let m = number(2) else { return nil }
            hour = h
            minute = m
            if expect(":") {
                guard let s = number(2) else { return nil }
                second = s
                if expect(".") {
                    var digits = ""
                    while index < chars.count, chars[index].isNumber {
                        digits.append(chars[index])
                        index += 1
                    }
                    guard !digits.isEmpty else { return nil }
                    fraction = Double("0." + digits) ?? 0
                }
            }
            if index < chars.count {
                let sign = chars[index]
                if sign == "Z" || sign == "z" {
                    index += 1
                } else if sign == "+" || sign == "-" {
                    index += 1
                    guard let offsetHours = number(2) else { return nil }
                    var offsetMinutes = 0
                    if expect(":") {
                        guard let value = number(2) else { return nil }
                        offsetMinutes = value
                    } else if let value = number(2) {
                        offsetMinutes = value
                    }
                    offsetSeconds = (offsetHours * 3600 + offsetMinutes * 60) * (sign == "-" ? -1 : 1)
                } else {
                    return nil
                }
            }
        }

        guard index == chars.count else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        guard let base = calendar.date(from: components) else { return nil }
        return base.addingTimeInterval(fraction - Double(offsetSeconds))
    }
}
