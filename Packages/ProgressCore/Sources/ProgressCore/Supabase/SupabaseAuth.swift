import Foundation

/// The Supabase project the app talks to. Both values are shown in the Supabase dashboard
/// under Project Settings → API. The anon key is designed to be public: row-level security
/// on the server keeps each user's data private.
public struct SupabaseConfig: Sendable, Equatable, Codable {
    public var url: URL
    public var anonKey: String

    public init(url: URL, anonKey: String) {
        self.url = url
        self.anonKey = anonKey
    }

    /// Accepts what a person pastes: trims spaces and a trailing slash, adds https:// if missing.
    public init?(urlText: String, anonKey: String) {
        var text = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasSuffix("/") { text.removeLast() }
        if !text.lowercased().hasPrefix("http") { text = "https://" + text }
        let key = anonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: text), url.host != nil, !key.isEmpty else { return nil }
        self.init(url: url, anonKey: key)
    }
}

public struct AuthSession: Sendable, Equatable, Codable {
    public var accessToken: String
    public var refreshToken: String
    public var expiresAt: Date
    public var userID: UUID
    public var email: String?

    public init(accessToken: String, refreshToken: String, expiresAt: Date, userID: UUID, email: String?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.userID = userID
        self.email = email
    }

    public func needsRefresh(now: Date = Date()) -> Bool {
        expiresAt.timeIntervalSince(now) < 120
    }
}

public enum SignUpResult: Sendable, Equatable {
    case signedIn(AuthSession)
    /// The Supabase project requires email confirmation before the first sign-in.
    case confirmationRequired
}

public enum AuthError: Error, Equatable, Sendable {
    case invalidCredentials(String)
    case offline
    case server(String)
}

/// Email and password sign-in against Supabase Auth.
public struct SupabaseAuthClient: Sendable {
    private let config: SupabaseConfig
    private let transport: any HTTPTransport

    public init(config: SupabaseConfig, transport: any HTTPTransport = URLSessionTransport()) {
        self.config = config
        self.transport = transport
    }

    public func signIn(email: String, password: String) async throws -> AuthSession {
        let response = try await post(path: "token", query: "grant_type=password", body: ["email": email, "password": password])
        guard let session = try Self.parseSession(response.body) else {
            throw AuthError.server("Sign-in returned no session")
        }
        return session
    }

    public func signUp(email: String, password: String) async throws -> SignUpResult {
        let response = try await post(path: "signup", query: nil, body: ["email": email, "password": password])
        if let session = try Self.parseSession(response.body) {
            return .signedIn(session)
        }
        return .confirmationRequired
    }

    public func refresh(_ session: AuthSession) async throws -> AuthSession {
        let response = try await post(path: "token", query: "grant_type=refresh_token", body: ["refresh_token": session.refreshToken])
        guard let refreshed = try Self.parseSession(response.body) else {
            throw AuthError.server("Refresh returned no session")
        }
        return refreshed
    }

    private func post(path: String, query: String?, body: [String: String]) async throws -> HTTPResponse {
        var text = config.url.absoluteString + "/auth/v1/" + path
        if let query { text += "?" + query }
        let request = HTTPRequest(
            method: "POST",
            url: URL(string: text)!,
            headers: ["apikey": config.anonKey, "Content-Type": "application/json"],
            body: try JSONEncoder().encode(body)
        )
        let response: HTTPResponse
        do {
            response = try await transport.send(request)
        } catch {
            throw AuthError.offline
        }
        guard (200..<300).contains(response.status) else {
            let message = Self.errorMessage(response.body) ?? "Error \(response.status)"
            if response.status == 400 || response.status == 401 || response.status == 422 {
                throw AuthError.invalidCredentials(message)
            }
            throw AuthError.server(message)
        }
        return response
    }

    static func parseSession(_ data: Data) throws -> AuthSession? {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard let access = object["access_token"] as? String,
              let refresh = object["refresh_token"] as? String,
              let user = object["user"] as? [String: Any],
              let idText = user["id"] as? String,
              let userID = UUID(uuidString: idText) else {
            return nil
        }
        let expiresAt: Date
        if let epoch = object["expires_at"] as? Double {
            expiresAt = Date(timeIntervalSince1970: epoch)
        } else if let seconds = object["expires_in"] as? Double {
            expiresAt = Date().addingTimeInterval(seconds)
        } else {
            expiresAt = Date().addingTimeInterval(3600)
        }
        return AuthSession(accessToken: access, refreshToken: refresh, expiresAt: expiresAt, userID: userID, email: user["email"] as? String)
    }

    static func errorMessage(_ data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        for key in ["msg", "message", "error_description", "error"] {
            if let text = object[key] as? String, !text.isEmpty { return text }
        }
        return nil
    }
}
