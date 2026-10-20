import Foundation
import Observation
import ProgressCore

/// Which Supabase project the app uses, and who is signed in.
@MainActor
@Observable
final class AuthStore {
    enum Mode: Equatable {
        /// First launch: nothing chosen yet.
        case welcome
        /// Using the app on this device only; nothing syncs until the user signs in.
        case localOnly
        case signedIn
    }

    private(set) var config: SupabaseConfig?
    private(set) var session: AuthSession?
    private(set) var isLocalOnly: Bool

    private var refreshTask: Task<AuthSession, Error>?

    private static let configKey = "supabase.config"
    private static let localOnlyKey = "auth.localOnly"
    private static let sessionAccount = "supabase.session"

    init() {
        let defaults = UserDefaults.standard
        config = defaults.data(forKey: Self.configKey).flatMap { try? JSONDecoder().decode(SupabaseConfig.self, from: $0) }
        session = Keychain.load(account: Self.sessionAccount).flatMap { try? JSONDecoder().decode(AuthSession.self, from: $0) }
        isLocalOnly = defaults.bool(forKey: Self.localOnlyKey)
    }

    var mode: Mode {
        if session != nil, config != nil { return .signedIn }
        return isLocalOnly ? .localOnly : .welcome
    }

    func useOnThisDeviceOnly() {
        isLocalOnly = true
        UserDefaults.standard.set(true, forKey: Self.localOnlyKey)
    }

    /// Saves the Supabase project address and key. Returns false if they don't look valid.
    func saveConfig(urlText: String, anonKey: String) -> Bool {
        guard let newConfig = SupabaseConfig(urlText: urlText, anonKey: anonKey) else { return false }
        config = newConfig
        UserDefaults.standard.set(try? JSONEncoder().encode(newConfig), forKey: Self.configKey)
        return true
    }

    func signIn(email: String, password: String) async throws {
        guard let config else { throw AuthError.server("Enter your Supabase project details first") }
        let newSession = try await SupabaseAuthClient(config: config).signIn(email: email, password: password)
        store(newSession)
    }

    /// Creates the account. Returns false when Supabase wants the email confirmed first.
    func signUp(email: String, password: String) async throws -> Bool {
        guard let config else { throw AuthError.server("Enter your Supabase project details first") }
        switch try await SupabaseAuthClient(config: config).signUp(email: email, password: password) {
        case .signedIn(let newSession):
            store(newSession)
            return true
        case .confirmationRequired:
            return false
        }
    }

    /// Signs out. Data stays on this device and keeps working offline.
    func signOut() {
        session = nil
        refreshTask = nil
        Keychain.delete(account: Self.sessionAccount)
        useOnThisDeviceOnly()
    }

    /// A current access token, refreshed first if it is about to expire.
    func validAccessToken() async throws -> String {
        guard let config, let session else { throw SyncError.unauthorized }
        guard session.needsRefresh() else { return session.accessToken }

        if let refreshTask {
            return try await refreshTask.value.accessToken
        }
        let task = Task { try await SupabaseAuthClient(config: config).refresh(session) }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            let refreshed = try await task.value
            store(refreshed)
            return refreshed.accessToken
        } catch AuthError.invalidCredentials {
            // The refresh token was revoked or expired: the user must sign in again.
            signOut()
            throw SyncError.unauthorized
        } catch AuthError.offline {
            throw SyncError.offline
        }
    }

    private func store(_ newSession: AuthSession) {
        session = newSession
        if let data = try? JSONEncoder().encode(newSession) {
            Keychain.save(data, account: Self.sessionAccount)
        }
    }
}
