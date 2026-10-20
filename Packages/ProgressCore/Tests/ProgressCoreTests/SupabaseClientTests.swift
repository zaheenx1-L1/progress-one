import XCTest
@testable import ProgressCore

final class FakeTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [HTTPRequest] = []
    private let handler: @Sendable (HTTPRequest) -> HTTPResponse

    init(handler: @escaping @Sendable (HTTPRequest) -> HTTPResponse) {
        self.handler = handler
    }

    var requests: [HTTPRequest] {
        lock.withLock { _requests }
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        lock.withLock { _requests.append(request) }
        return handler(request)
    }
}

final class SupabaseClientTests: XCTestCase {
    let config = SupabaseConfig(url: URL(string: "https://abc.supabase.co")!, anonKey: "anon-key")
    let rowJSON = """
    [{"id":"6f1c2d3e-0000-4000-8000-000000000001","user_id":"11111111-1111-4111-8111-111111111111",
      "version":3,"created_at":"2026-10-19T10:00:00+00:00","updated_at":"2026-10-20T04:38:56.692546+00:00",
      "deleted_at":null,"title":"Follow up","priority":3,"due_at":"2026-10-21T06:00:00+00:00"}]
    """

    func testConfigCleansPastedURL() {
        let config = SupabaseConfig(urlText: "  abc.supabase.co/ ", anonKey: " key ")
        XCTAssertEqual(config?.url.absoluteString, "https://abc.supabase.co")
        XCTAssertEqual(config?.anonKey, "key")
        XCTAssertNil(SupabaseConfig(urlText: "", anonKey: "key"))
    }

    func testUpsertSendsBaseVersionAndNoServerColumns() async throws {
        let json = rowJSON
        let transport = FakeTransport { _ in HTTPResponse(status: 201, body: Data(json.utf8)) }
        let backend = SupabaseBackend(config: config, transport: transport) { "token-1" }
        let id = UUID(uuidString: "6f1c2d3e-0000-4000-8000-000000000001")!

        let row = try await backend.upsert(
            table: "tasks", id: id, baseVersion: 2, deletedAt: nil,
            fields: ["title": .string("Follow up"), "user_id": .string("spoofed"), "updated_at": .string("x")]
        )

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.url.absoluteString, "https://abc.supabase.co/rest/v1/tasks?on_conflict=id")
        XCTAssertEqual(request.headers["Authorization"], "Bearer token-1")
        XCTAssertEqual(request.headers["apikey"], "anon-key")
        XCTAssertEqual(request.headers["Prefer"], "resolution=merge-duplicates,return=representation")
        let body = try JSONDecoder().decode([String: JSONValue].self, from: request.body!)
        XCTAssertEqual(body["base_version"], .number(2))
        XCTAssertNil(body["version"], "the server assigns versions")
        XCTAssertEqual(body["id"], .string("6f1c2d3e-0000-4000-8000-000000000001"))
        XCTAssertNil(body["user_id"], "the server sets the owner")
        XCTAssertNil(body["updated_at"], "the server sets timestamps")

        XCTAssertEqual(row.version, 3)
        XCTAssertEqual(row.updatedAtRaw, "2026-10-20T04:38:56.692546+00:00")
        XCTAssertEqual(row.fields["title"], .string("Follow up"))
        XCTAssertNil(row.fields["user_id"])
    }

    func testVersionConflictIsRecognised() async throws {
        let transport = FakeTransport { _ in
            HTTPResponse(status: 409, body: Data(#"{"code":"PT409","message":"version_conflict"}"#.utf8))
        }
        let backend = SupabaseBackend(config: config, transport: transport) { "t" }
        do {
            _ = try await backend.upsert(table: "tasks", id: UUID(), baseVersion: 1, deletedAt: nil, fields: [:])
            XCTFail("expected a conflict")
        } catch let error as SyncError {
            XCTAssertEqual(error, .versionConflict)
        }
    }

    func testOtherConflictIsAServerError() async throws {
        let transport = FakeTransport { _ in
            HTTPResponse(status: 409, body: Data(#"{"code":"23505","message":"duplicate key"}"#.utf8))
        }
        let backend = SupabaseBackend(config: config, transport: transport) { "t" }
        do {
            _ = try await backend.upsert(table: "tasks", id: UUID(), baseVersion: 1, deletedAt: nil, fields: [:])
            XCTFail("expected an error")
        } catch let error as SyncError {
            XCTAssertEqual(error, .server(status: 409, message: "duplicate key"))
        }
    }

    func testExpiredSessionIsUnauthorized() async throws {
        let transport = FakeTransport { _ in HTTPResponse(status: 401, body: Data("{}".utf8)) }
        let backend = SupabaseBackend(config: config, transport: transport) { "t" }
        do {
            _ = try await backend.fetch(table: "tasks", id: UUID())
            XCTFail("expected an error")
        } catch let error as SyncError {
            XCTAssertEqual(error, .unauthorized)
        }
    }

    func testChangesQueryUsesKeysetCursor() throws {
        let cursor = PullCursor(updatedAtRaw: "2026-10-20T04:38:56.692546+00:00", id: UUID(uuidString: "6F1C2D3E-0000-4000-8000-000000000001")!)
        let query = SupabaseBackend.changesQuery(after: cursor, limit: 500)
        XCTAssertTrue(query.hasPrefix("select=*&order=updated_at.asc,id.asc&limit=500&or="))
        let encoded = String(query.split(separator: "=", maxSplits: 4).last!)
        XCTAssertEqual(
            encoded.removingPercentEncoding,
            #"(updated_at.gt."2026-10-20T04:38:56.692546+00:00",and(updated_at.eq."2026-10-20T04:38:56.692546+00:00",id.gt.6f1c2d3e-0000-4000-8000-000000000001))"#
        )
        XCTAssertFalse(encoded.contains("+"), "a raw + would be read as a space")
        XCTAssertNotNil(URL(string: "https://abc.supabase.co/rest/v1/tasks?" + query))
    }

    func testFirstPullHasNoCursorFilter() {
        XCTAssertEqual(SupabaseBackend.changesQuery(after: nil, limit: 10), "select=*&order=updated_at.asc,id.asc&limit=10")
    }

    func testSignInParsesSession() async throws {
        let body = """
        {"access_token":"acc","token_type":"bearer","expires_in":3600,"expires_at":1800000000,
         "refresh_token":"ref","user":{"id":"11111111-1111-4111-8111-111111111111","email":"me@example.com"}}
        """
        let transport = FakeTransport { _ in HTTPResponse(status: 200, body: Data(body.utf8)) }
        let auth = SupabaseAuthClient(config: config, transport: transport)

        let session = try await auth.signIn(email: "me@example.com", password: "secret123")

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url.absoluteString, "https://abc.supabase.co/auth/v1/token?grant_type=password")
        XCTAssertEqual(request.headers["apikey"], "anon-key")
        XCTAssertEqual(session.accessToken, "acc")
        XCTAssertEqual(session.refreshToken, "ref")
        XCTAssertEqual(session.expiresAt, Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertEqual(session.email, "me@example.com")
    }

    func testSignUpNeedingEmailConfirmation() async throws {
        let body = #"{"id":"11111111-1111-4111-8111-111111111111","email":"me@example.com"}"#
        let transport = FakeTransport { _ in HTTPResponse(status: 200, body: Data(body.utf8)) }
        let result = try await SupabaseAuthClient(config: config, transport: transport).signUp(email: "me@example.com", password: "secret123")
        XCTAssertEqual(result, .confirmationRequired)
    }

    func testWrongPasswordIsInvalidCredentials() async throws {
        let body = #"{"error":"invalid_grant","error_description":"Invalid login credentials"}"#
        let transport = FakeTransport { _ in HTTPResponse(status: 400, body: Data(body.utf8)) }
        do {
            _ = try await SupabaseAuthClient(config: config, transport: transport).signIn(email: "a@b.c", password: "x")
            XCTFail("expected an error")
        } catch let error as AuthError {
            XCTAssertEqual(error, .invalidCredentials("Invalid login credentials"))
        }
    }
}
