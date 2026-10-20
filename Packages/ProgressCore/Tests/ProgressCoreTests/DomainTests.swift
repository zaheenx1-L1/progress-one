import XCTest
@testable import ProgressCore

final class DomainTests: XCTestCase {
    func testPostgresTimestampVariants() throws {
        let expected = Date(timeIntervalSince1970: 1_792_471_136.692546)
        let micro = try XCTUnwrap(PostgresTimestamp.parse("2026-10-20T04:38:56.692546+00:00"))
        XCTAssertEqual(micro.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 0.000001)

        let dubai = try XCTUnwrap(PostgresTimestamp.parse("2026-10-20T08:38:56.692546+04:00"))
        XCTAssertEqual(dubai.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 0.000001)

        XCTAssertNotNil(PostgresTimestamp.parse("2026-10-20T04:38:56Z"))
        XCTAssertNotNil(PostgresTimestamp.parse("2026-10-20 04:38:56+00"))
        XCTAssertNotNil(PostgresTimestamp.parse("2026-10-20"))
        XCTAssertNil(PostgresTimestamp.parse("20 Oct 2026"))
        XCTAssertNil(PostgresTimestamp.parse("2026-10-20T04:38:56+0"))
    }

    func testTimestampRoundTrip() throws {
        let date = Date(timeIntervalSince1970: 1_792_471_136.692)
        let text = PostgresTimestamp.format(date)
        XCTAssertEqual(text, "2026-10-20T04:38:56.692Z")
        let parsed = try XCTUnwrap(PostgresTimestamp.parse(text))
        XCTAssertEqual(parsed.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
    }

    func testJSONValueRoundTrip() throws {
        let value: JSONValue = .object(["a": .number(1), "b": .array([.string("x"), .null, .bool(true)])])
        let data = try JSONEncoder().encode(value)
        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: data), value)
        XCTAssertEqual(JSONValue.number(3).intValue, 3)
        XCTAssertNil(JSONValue.number(3.5).intValue)
    }

    func testConflictDecisions() {
        XCTAssertEqual(ConflictPolicy.decide(local: nil, remoteVersion: 1), .insert)
        XCTAssertEqual(ConflictPolicy.decide(local: .init(baseVersion: 2, isDirty: false), remoteVersion: 2), .ignore)
        XCTAssertEqual(ConflictPolicy.decide(local: .init(baseVersion: 2, isDirty: true), remoteVersion: 2), .ignore)
        XCTAssertEqual(ConflictPolicy.decide(local: .init(baseVersion: 2, isDirty: false), remoteVersion: 3), .apply)
        XCTAssertEqual(ConflictPolicy.decide(local: .init(baseVersion: 2, isDirty: true), remoteVersion: 3), .conflict)
    }

    func testSameContentToleratesTimestampFormatting() {
        let local = LocalRecord(id: UUID(), baseVersion: 0, isDirty: true, localRevision: 1, deletedAt: nil,
                                fields: ["due_at": .string("2026-10-21T06:00:00.000Z"), "title": .string("A")])
        let remote = RemoteRow(id: local.id, version: 1, updatedAtRaw: "x", deletedAt: nil,
                               fields: ["due_at": .string("2026-10-21T06:00:00+00:00"), "title": .string("A")])
        XCTAssertTrue(ConflictPolicy.isSameContent(local: local, remote: remote))

        var changed = remote
        changed.fields["title"] = .string("B")
        XCTAssertFalse(ConflictPolicy.isSameContent(local: local, remote: changed))
    }

    func testUnfinishedTasksStayVisible() throws {
        let prefs = RegionalPreferences.default
        let calendar = prefs.calendar
        // 2026-10-20 10:00 in Dubai.
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 10)))
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!

        XCTAssertTrue(TaskBucket.overdue.contains(status: .todo, dueAt: yesterday, now: now, calendar: calendar))
        XCTAssertTrue(TaskBucket.today.contains(status: .todo, dueAt: yesterday, now: now, calendar: calendar), "overdue work also shows today")
        XCTAssertTrue(TaskBucket.today.contains(status: .inProgress, dueAt: now, now: now, calendar: calendar))
        XCTAssertFalse(TaskBucket.today.contains(status: .done, dueAt: now, now: now, calendar: calendar))
        XCTAssertFalse(TaskBucket.overdue.contains(status: .cancelled, dueAt: yesterday, now: now, calendar: calendar))
        XCTAssertTrue(TaskBucket.upcoming.contains(status: .todo, dueAt: tomorrow, now: now, calendar: calendar))
        XCTAssertTrue(TaskBucket.someday.contains(status: .todo, dueAt: nil, now: now, calendar: calendar))
        XCTAssertTrue(TaskBucket.completed.contains(status: .done, dueAt: nil, now: now, calendar: calendar))
    }

    func testDubaiDayBoundary() throws {
        let calendar = RegionalPreferences.default.calendar
        // 21:30 UTC on Oct 20 is already 01:30 on Oct 21 in Dubai, so a task due then is not "today" on the 20th.
        let nowDubai = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 23)))
        let dueUTC = try XCTUnwrap(PostgresTimestamp.parse("2026-10-20T21:30:00Z"))
        XCTAssertFalse(TaskBucket.today.contains(status: .todo, dueAt: dueUTC, now: nowDubai, calendar: calendar))
        XCTAssertTrue(TaskBucket.upcoming.contains(status: .todo, dueAt: dueUTC, now: nowDubai, calendar: calendar))
    }

    func testWeekStartsOnConfiguredDay() throws {
        var prefs = RegionalPreferences.default
        let wednesday = try XCTUnwrap(prefs.calendar.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 12)))

        prefs.firstWeekday = 2 // Monday
        XCTAssertEqual(prefs.calendar.component(.weekday, from: prefs.week(containing: wednesday).start), 2)

        prefs.firstWeekday = 1 // Sunday
        XCTAssertEqual(prefs.calendar.component(.weekday, from: prefs.week(containing: wednesday).start), 1)
        XCTAssertEqual(prefs.week(containing: wednesday).duration, 7 * 24 * 3600)
    }

    func testSeedWorkspacesMatchSpec() {
        XCTAssertEqual(WorkspaceSeed.all.map(\.name), ["iExpert Technologies", "iExpert Training Academy", "Greentick Real Estate", "Personal Life"])
        XCTAssertEqual(Set(WorkspaceSeed.all.map(\.id)).count, 4)
        XCTAssertEqual(WorkspaceSeed.all.filter(\.isPrivate).map(\.kind), [.personal])
    }
}
