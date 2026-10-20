import XCTest
@testable import ProgressCore

/// Simulates the spec's cross-device acceptance tests (Part 41) with two in-memory devices
/// sharing one in-memory server that follows the same version rules as the real database.
final class SyncEngineTests: XCTestCase {
    let table = "tasks"
    var server: InMemoryBackend!
    var mac: InMemoryLocalStore!
    var iphone: InMemoryLocalStore!
    var macSync: SyncEngine!
    var iphoneSync: SyncEngine!

    override func setUp() async throws {
        server = InMemoryBackend()
        mac = InMemoryLocalStore()
        iphone = InMemoryLocalStore()
        macSync = SyncEngine(tables: [table], local: mac, remote: server, pageSize: 50)
        iphoneSync = SyncEngine(tables: [table], local: iphone, remote: server, pageSize: 50)
    }

    // Test A: create a task on the MacBook and it appears on the iPhone.
    func testTaskCreatedOnMacAppearsOnIPhone() async throws {
        let id = await mac.create(table: table, fields: ["title": .string("Call Greentick buyer"), "status": .string("todo")])

        let macReport = await macSync.sync()
        XCTAssertNil(macReport.error)
        XCTAssertEqual(macReport.pushed, 1)

        let phoneReport = await iphoneSync.sync()
        XCTAssertNil(phoneReport.error)
        let onPhone = await iphone.entry(table: table, id: id)
        XCTAssertEqual(onPhone?.record.fields["title"], .string("Call Greentick buyer"))
        XCTAssertEqual(onPhone?.record.isDirty, false)
    }

    // Test B: complete that task on the iPhone and the MacBook updates.
    func testTaskCompletedOnIPhoneUpdatesMac() async throws {
        let id = await mac.create(table: table, fields: ["title": .string("Send proposal"), "status": .string("todo")])
        _ = await macSync.sync()
        _ = await iphoneSync.sync()

        await iphone.edit(table: table, id: id) { $0["status"] = .string("done") }
        let phoneReport = await iphoneSync.sync()
        XCTAssertEqual(phoneReport.pushed, 1)

        _ = await macSync.sync()
        let onMac = await mac.entry(table: table, id: id)
        XCTAssertEqual(onMac?.record.fields["status"], .string("done"))
        XCTAssertEqual(onMac?.record.baseVersion, 2)
    }

    // Test H: edit offline, then sync correctly when the connection returns.
    func testOfflineEditSyncsWhenOnline() async throws {
        let id = await iphone.create(table: table, fields: ["title": .string("Read 20 pages")])
        await server.setOffline(true)

        let offlineReport = await iphoneSync.sync()
        XCTAssertEqual(offlineReport.error, .offline)
        let pending = await iphone.dirtyRecords(table: table)
        XCTAssertEqual(pending.map(\.id), [id], "the edit must stay queued while offline")

        await server.setOffline(false)
        let onlineReport = await iphoneSync.sync()
        XCTAssertNil(onlineReport.error)
        XCTAssertEqual(onlineReport.pushed, 1)
        let onServer = await server.row(table: table, id: id)
        XCTAssertEqual(onServer?.fields["title"], .string("Read 20 pages"))
    }

    // Test I: the same record edited on both devices becomes a visible conflict, not a silent overwrite.
    func testConcurrentEditsBecomeAConflict() async throws {
        let id = await mac.create(table: table, fields: ["title": .string("Original")])
        _ = await macSync.sync()
        _ = await iphoneSync.sync()

        await mac.edit(table: table, id: id) { $0["title"] = .string("Edited on Mac") }
        await iphone.edit(table: table, id: id) { $0["title"] = .string("Edited on iPhone") }

        _ = await macSync.sync()
        let phoneReport = await iphoneSync.sync()
        XCTAssertEqual(phoneReport.newConflicts, 1)

        let onPhone = await iphone.entry(table: table, id: id)
        XCTAssertEqual(onPhone?.record.fields["title"], .string("Edited on iPhone"), "the local edit is kept")
        XCTAssertEqual(onPhone?.conflict?.fields["title"], .string("Edited on Mac"), "the other version is kept for the user")
        let onServer = await server.row(table: table, id: id)
        XCTAssertEqual(onServer?.fields["title"], .string("Edited on Mac"), "the server was not overwritten")

        // A conflicted record is not pushed again until the user decides.
        let again = await iphoneSync.sync()
        XCTAssertEqual(again.pushed, 0)
    }

    func testResolvingConflictKeepingLocalReachesOtherDevice() async throws {
        let id = await mac.create(table: table, fields: ["title": .string("Original")])
        _ = await macSync.sync()
        _ = await iphoneSync.sync()
        await mac.edit(table: table, id: id) { $0["title"] = .string("Mac") }
        await iphone.edit(table: table, id: id) { $0["title"] = .string("iPhone") }
        _ = await macSync.sync()
        _ = await iphoneSync.sync()

        await iphone.resolveKeepingLocal(table: table, id: id)
        let report = await iphoneSync.sync()
        XCTAssertEqual(report.pushed, 1)
        XCTAssertNil(report.error)

        _ = await macSync.sync()
        let onMac = await mac.entry(table: table, id: id)
        XCTAssertEqual(onMac?.record.fields["title"], .string("iPhone"))
    }

    func testResolvingConflictKeepingRemote() async throws {
        let id = await mac.create(table: table, fields: ["title": .string("Original")])
        _ = await macSync.sync()
        _ = await iphoneSync.sync()
        await mac.edit(table: table, id: id) { $0["title"] = .string("Mac") }
        await iphone.edit(table: table, id: id) { $0["title"] = .string("iPhone") }
        _ = await macSync.sync()
        _ = await iphoneSync.sync()

        await iphone.resolveKeepingRemote(table: table, id: id)
        let entry = await iphone.entry(table: table, id: id)
        XCTAssertEqual(entry?.record.fields["title"], .string("Mac"))
        XCTAssertEqual(entry?.record.isDirty, false)
        XCTAssertNil(entry?.conflict)
    }

    func testDeletionPropagates() async throws {
        let id = await mac.create(table: table, fields: ["title": .string("Old task")])
        _ = await macSync.sync()
        _ = await iphoneSync.sync()

        await iphone.delete(table: table, id: id)
        _ = await iphoneSync.sync()
        _ = await macSync.sync()

        let onMac = await mac.entry(table: table, id: id)
        XCTAssertNotNil(onMac?.record.deletedAt)
    }

    func testEditDuringPushStaysDirty() async throws {
        let id = await mac.create(table: table, fields: ["title": .string("First")])
        let snapshot = await mac.dirtyRecords(table: table).first!
        await mac.edit(table: table, id: id) { $0["title"] = .string("Second") }

        // The push of the first revision finishes after the second edit was made.
        await mac.markPushed(table: table, id: id, version: 1, pushedRevision: snapshot.localRevision)

        let entry = await mac.entry(table: table, id: id)
        XCTAssertEqual(entry?.record.isDirty, true, "the newer edit must still be sent")
        XCTAssertEqual(entry?.record.baseVersion, 1)
    }

    func testLostResponseDoesNotCreateFalseConflict() async throws {
        let id = await mac.create(table: table, fields: ["title": .string("Saved, but reply lost")])
        await server.setDropNextResponse(true)
        let first = await macSync.sync()
        XCTAssertEqual(first.error, .offline)

        let second = await macSync.sync()
        XCTAssertNil(second.error)
        XCTAssertEqual(second.newConflicts, 0)
        let entry = await mac.entry(table: table, id: id)
        XCTAssertEqual(entry?.record.isDirty, false)
        XCTAssertEqual(entry?.record.baseVersion, 1)
    }

    func testSameDefaultRecordOnTwoDevicesIsNotDuplicated() async throws {
        let seedID = WorkspaceSeed.all[0].id
        let fields: [String: JSONValue] = ["name": .string("iExpert Technologies")]
        _ = await mac.create(table: table, id: seedID, fields: fields)
        _ = await iphone.create(table: table, id: seedID, fields: fields)

        _ = await macSync.sync()
        let report = await iphoneSync.sync()
        XCTAssertEqual(report.newConflicts, 0)
        let count = await server.rowCount(table: table)
        XCTAssertEqual(count, 1)
    }

    func testPagingDoesNotSkipRowsSharingATimestamp() async throws {
        await server.setFrozenTimestamp("2026-10-20T04:00:00.000000+00:00")
        for index in 0..<137 {
            _ = await mac.create(table: table, fields: ["title": .string("Task \(index)")])
        }
        _ = await macSync.sync()

        let report = await iphoneSync.sync()
        XCTAssertNil(report.error)
        XCTAssertEqual(report.pulled, 137)
        let onPhone = await iphone.allEntries(table: table)
        XCTAssertEqual(onPhone.count, 137)

        // A second pass pulls nothing new.
        let again = await iphoneSync.sync()
        XCTAssertEqual(again.pulled, 0)
    }

    func testOwnPushIsNotPulledBackAsAChange() async throws {
        _ = await mac.create(table: table, fields: ["title": .string("Mine")])
        let report = await macSync.sync()
        XCTAssertEqual(report.pushed, 1)
        XCTAssertEqual(report.pulled, 0)
        XCTAssertEqual(report.newConflicts, 0)
    }
}
