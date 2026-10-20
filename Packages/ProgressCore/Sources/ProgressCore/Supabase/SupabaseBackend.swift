import Foundation

/// The sync engine's view of the Supabase database, through its PostgREST API.
///
/// Every synced table has the columns `id`, `user_id`, `version`, `base_version`, `created_at`,
/// `updated_at` and `deleted_at`, maintained by the `p1_sync_stamp` trigger in `supabase/migrations`.
public struct SupabaseBackend: RemoteBackend {
    /// Columns the server owns. They are never sent, and are not part of a record's fields.
    static let serverColumns: Set<String> = ["id", "user_id", "version", "base_version", "created_at", "updated_at", "deleted_at"]

    private let config: SupabaseConfig
    private let transport: any HTTPTransport
    private let accessToken: @Sendable () async throws -> String
    private let restPath: String

    /// `restPath` is where PostgREST is mounted: `/rest/v1` on Supabase, empty for a bare local PostgREST.
    public init(
        config: SupabaseConfig,
        transport: any HTTPTransport = URLSessionTransport(),
        restPath: String = "/rest/v1",
        accessToken: @escaping @Sendable () async throws -> String
    ) {
        self.config = config
        self.transport = transport
        self.restPath = restPath
        self.accessToken = accessToken
    }

    public func upsert(table: String, id: UUID, baseVersion: Int, deletedAt: Date?, fields: [String: JSONValue]) async throws -> RemoteRow {
        var body = fields.filter { !Self.serverColumns.contains($0.key) }
        body["id"] = .uuid(id)
        body["base_version"] = .int(baseVersion)
        body["deleted_at"] = .date(deletedAt)

        let response = try await send(
            method: "POST",
            table: table,
            query: "on_conflict=id",
            prefer: "resolution=merge-duplicates,return=representation",
            body: try JSONEncoder().encode(body)
        )
        guard let row = try Self.parseRows(response.body).first else {
            throw SyncError.invalidResponse("Upsert returned no row")
        }
        return row
    }

    public func fetch(table: String, id: UUID) async throws -> RemoteRow? {
        let response = try await send(method: "GET", table: table, query: "select=*&id=eq.\(id.uuidString.lowercased())")
        return try Self.parseRows(response.body).first
    }

    public func changes(table: String, after cursor: PullCursor?, limit: Int) async throws -> [RemoteRow] {
        let response = try await send(method: "GET", table: table, query: Self.changesQuery(after: cursor, limit: limit))
        return try Self.parseRows(response.body)
    }

    /// Keyset pagination on (updated_at, id), so rows sharing a timestamp are never skipped.
    static func changesQuery(after cursor: PullCursor?, limit: Int) -> String {
        var query = "select=*&order=updated_at.asc,id.asc&limit=\(limit)"
        if let cursor {
            let stamp = "\"\(cursor.updatedAtRaw)\""
            let id = cursor.id.uuidString.lowercased()
            let filter = "(updated_at.gt.\(stamp),and(updated_at.eq.\(stamp),id.gt.\(id)))"
            query += "&or=" + percentEncode(filter)
        }
        return query
    }

    static func percentEncode(_ text: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }

    private func send(method: String, table: String, query: String, prefer: String? = nil, body: Data? = nil) async throws -> HTTPResponse {
        let token: String
        do {
            token = try await accessToken()
        } catch AuthError.offline {
            throw SyncError.offline
        } catch let error as SyncError {
            throw error
        } catch {
            throw SyncError.unauthorized
        }

        var headers = [
            "apikey": config.anonKey,
            "Authorization": "Bearer \(token)",
            "Accept": "application/json",
        ]
        if body != nil { headers["Content-Type"] = "application/json" }
        if let prefer { headers["Prefer"] = prefer }

        let url = URL(string: "\(config.url.absoluteString)\(restPath)/\(table)?\(query)")!
        let response = try await transport.send(HTTPRequest(method: method, url: url, headers: headers, body: body))

        switch response.status {
        case 200..<300:
            return response
        case 401, 403:
            throw SyncError.unauthorized
        case 409 where String(decoding: response.body, as: UTF8.self).contains("version_conflict"):
            throw SyncError.versionConflict
        default:
            let message = SupabaseAuthClient.errorMessage(response.body) ?? String(decoding: response.body, as: UTF8.self)
            throw SyncError.server(status: response.status, message: message)
        }
    }

    static func parseRows(_ data: Data) throws -> [RemoteRow] {
        let objects: [[String: JSONValue]]
        do {
            objects = try JSONDecoder().decode([[String: JSONValue]].self, from: data)
        } catch {
            throw SyncError.invalidResponse("Expected a list of rows")
        }
        return try objects.map { object in
            guard let id = object["id"]?.uuidValue,
                  let version = object["version"]?.intValue,
                  let updatedAt = object["updated_at"]?.stringValue else {
                throw SyncError.invalidResponse("Row is missing id, version or updated_at")
            }
            return RemoteRow(
                id: id,
                version: version,
                updatedAtRaw: updatedAt,
                deletedAt: object["deleted_at"]?.dateValue,
                fields: object.filter { !serverColumns.contains($0.key) }
            )
        }
    }
}
