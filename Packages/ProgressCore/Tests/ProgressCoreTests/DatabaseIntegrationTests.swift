import XCTest
@testable import ProgressCore

/// Runs the sync engine against a real Postgres + PostgREST with the migrations applied.
///
/// Skipped unless `P1_INTEGRATION_URL`, `P1_TOKEN_A` and `P1_TOKEN_B` are set. See
/// `supabase/tests/README.md` for how to start the local database.
final class DatabaseIntegrationTests: XCTestCase {
    var config: SupabaseConfig!
    var tokenA = ""
    var tokenB = ""

    override func setUpWithError() throws {
        let env = ProcessInfo.processInfo.environment
        guard let urlText = env["P1_INTEGRATION_URL"], let a = env["P1_TOKEN_A"], let b = env["P1_TOKEN_B"] else {
            throw XCTSkip("Set P1_INTEGRATION_URL, P1_TOKEN_A and P1_TOKEN_B to run database tests")
        }
        config = SupabaseConfig(url: URL(string: urlText)!, anonKey: "local")
        tokenA = a
        tokenB = b
    }

    func backend(_ token: String) -> SupabaseBackend {
        SupabaseBackend(config: config, restPath: "") { token }
    }

    func testTwoDevicesSyncThroughRealDatabase() async throws {
        let server = backend(tokenA)
        let mac = InMemoryLocalStore()
        let iphone = InMemoryLocalStore()
        let macSync = SyncEngine(tables: ["workspaces", "tasks"], local: mac, remote: server, pageSize: 2)
        let phoneSync = SyncEngine(tables: ["workspaces", "tasks"], local: iphone, remote: server, pageSize: 2)

        // Catch both devices up first, so earlier test runs don't affect counts.
        _ = await macSync.sync()
        _ = await phoneSync.sync()

        // Test A: created on the Mac, appears on the iPhone.
        let ids = await (0..<5).asyncMap { index in
            await mac.create(table: "tasks", fields: [
                "title": .string("Integration task \(index)"),
                "status": .string("todo"),
                "priority": .int(3),
                "due_at": .date(Date(timeIntervalSince1970: 1_792_500_000)),
            ])
        }
        let macReport = await macSync.sync()
        XCTAssertNil(macReport.error)
        XCTAssertEqual(macReport.pushed, 5)

        let phoneReport = await phoneSync.sync()
        XCTAssertNil(phoneReport.error)
        XCTAssertEqual(phoneReport.pulled, 5, "pages of 2 must not skip or repeat rows")
        let first = await iphone.entry(table: "tasks", id: ids[0])
        XCTAssertEqual(first?.record.fields["title"], .string("Integration task 0"))
        XCTAssertEqual(first?.record.fields["due_at"]?.dateValue, Date(timeIntervalSince1970: 1_792_500_000))

        // Test B: completed on the iPhone, the Mac updates.
        await iphone.edit(table: "tasks", id: ids[0]) { $0["status"] = .string("done") }
        let completeReport = await phoneSync.sync()
        XCTAssertNil(completeReport.error)
        XCTAssertEqual(completeReport.pushed, 1)
        _ = await macSync.sync()
        let onMac = await mac.entry(table: "tasks", id: ids[0])
        XCTAssertEqual(onMac?.record.fields["status"], .string("done"))
        XCTAssertEqual(onMac?.record.baseVersion, 2)

        // Test I: both devices edit the same task; the database rejects the stale edit.
        await mac.edit(table: "tasks", id: ids[1]) { $0["title"] = .string("Mac title") }
        await iphone.edit(table: "tasks", id: ids[1]) { $0["title"] = .string("iPhone title") }
        _ = await macSync.sync()
        let conflictReport = await phoneSync.sync()
        XCTAssertNil(conflictReport.error)
        XCTAssertEqual(conflictReport.newConflicts, 1)
        let serverCopy = try await server.fetch(table: "tasks", id: ids[1])
        XCTAssertEqual(serverCopy?.fields["title"], .string("Mac title"), "the database was not overwritten")

        await iphone.resolveKeepingLocal(table: "tasks", id: ids[1])
        let resolved = await phoneSync.sync()
        XCTAssertNil(resolved.error)
        XCTAssertEqual(resolved.pushed, 1)
        _ = await macSync.sync()
        let macAfter = await mac.entry(table: "tasks", id: ids[1])
        XCTAssertEqual(macAfter?.record.fields["title"], .string("iPhone title"))

        // Soft delete reaches the other device.
        await mac.delete(table: "tasks", id: ids[2])
        _ = await macSync.sync()
        _ = await phoneSync.sync()
        let deleted = await iphone.entry(table: "tasks", id: ids[2])
        XCTAssertNotNil(deleted?.record.deletedAt)
    }

    func testStaleWriteIsRejectedByDatabase() async throws {
        let server = backend(tokenA)
        let id = UUID()
        let created = try await server.upsert(table: "tasks", id: id, baseVersion: 0, deletedAt: nil, fields: ["title": .string("v1")])
        XCTAssertEqual(created.version, 1)
        let updated = try await server.upsert(table: "tasks", id: id, baseVersion: 1, deletedAt: nil, fields: ["title": .string("v2")])
        XCTAssertEqual(updated.version, 2)

        do {
            _ = try await server.upsert(table: "tasks", id: id, baseVersion: 1, deletedAt: nil, fields: ["title": .string("stale")])
            XCTFail("a write based on version 1 must be rejected once the row is at version 2")
        } catch let error as SyncError {
            XCTAssertEqual(error, .versionConflict)
        }
        let current = try await server.fetch(table: "tasks", id: id)
        XCTAssertEqual(current?.fields["title"], .string("v2"))
    }

    func testSharedDefaultWorkspaceIsOneRow() async throws {
        let seed = WorkspaceSeed.all[3]
        let fields: [String: JSONValue] = ["name": .string(seed.name), "kind": .string(seed.kind.rawValue)]
        let mac = InMemoryLocalStore()
        let iphone = InMemoryLocalStore()
        _ = await mac.create(table: "workspaces", id: seed.id, fields: fields)
        _ = await iphone.create(table: "workspaces", id: seed.id, fields: fields)
        let server = backend(tokenA)
        let macReport = await SyncEngine(tables: ["workspaces"], local: mac, remote: server).sync()
        XCTAssertNil(macReport.error)
        let phoneReport = await SyncEngine(tables: ["workspaces"], local: iphone, remote: server).sync()
        XCTAssertNil(phoneReport.error)
        XCTAssertEqual(phoneReport.newConflicts, 0)
    }

    func testOtherUsersCannotSeeOrOverwriteRows() async throws {
        let owner = backend(tokenA)
        let stranger = backend(tokenB)
        let id = UUID()
        _ = try await owner.upsert(table: "tasks", id: id, baseVersion: 0, deletedAt: nil, fields: ["title": .string("Private")])

        let seen = try await stranger.fetch(table: "tasks", id: id)
        XCTAssertNil(seen, "row-level security hides other users' rows")

        do {
            _ = try await stranger.upsert(table: "tasks", id: id, baseVersion: 1, deletedAt: nil, fields: ["title": .string("Hijacked")])
            XCTFail("a stranger must not be able to write to someone else's row")
        } catch is SyncError {
            // Expected: the database refuses the write.
        }
        let stillOwned = try await owner.fetch(table: "tasks", id: id)
        XCTAssertEqual(stillOwned?.fields["title"], .string("Private"))
    }
}

private extension Sequence {
    func asyncMap<T>(_ transform: (Element) async -> T) async -> [T] {
        var results: [T] = []
        for element in self { results.append(await transform(element)) }
        return results
    }
}
