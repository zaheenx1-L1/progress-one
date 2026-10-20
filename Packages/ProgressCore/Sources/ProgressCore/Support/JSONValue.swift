import Foundation

/// A JSON value used to move record fields between the local store and the server
/// without the sync engine needing to know each entity's shape.
public enum JSONValue: Sendable, Equatable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}

extension JSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

public extension JSONValue {
    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var doubleValue: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        guard case .number(let value) = self, value.rounded() == value else { return nil }
        return Int(value)
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var isNull: Bool { self == .null }

    /// Interprets a string as a Postgres/ISO-8601 timestamp.
    var dateValue: Date? {
        stringValue.flatMap(PostgresTimestamp.parse)
    }

    var uuidValue: UUID? {
        stringValue.flatMap(UUID.init(uuidString:))
    }

    static func date(_ date: Date?) -> JSONValue {
        date.map { .string(PostgresTimestamp.format($0)) } ?? .null
    }

    static func uuid(_ id: UUID?) -> JSONValue {
        id.map { .string($0.uuidString.lowercased()) } ?? .null
    }

    static func int(_ value: Int) -> JSONValue {
        .number(Double(value))
    }
}
