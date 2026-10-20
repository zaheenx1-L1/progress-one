import Foundation
import Observation
import ProgressCore

/// Settings kept on this device: region, currency, week start, and the app lock.
@MainActor
@Observable
final class PreferencesStore {
    var regional: RegionalPreferences {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(regional), forKey: Self.regionalKey) }
    }

    var appLockEnabled: Bool {
        didSet { UserDefaults.standard.set(appLockEnabled, forKey: Self.appLockKey) }
    }

    private static let regionalKey = "prefs.regional"
    private static let appLockKey = "prefs.appLock"

    init() {
        let defaults = UserDefaults.standard
        regional = defaults.data(forKey: Self.regionalKey)
            .flatMap { try? JSONDecoder().decode(RegionalPreferences.self, from: $0) } ?? .default
        appLockEnabled = defaults.bool(forKey: Self.appLockKey)
    }

    var calendar: Calendar { regional.calendar }

    static let currencies = ["AED", "USD", "EUR", "GBP", "SAR", "INR"]
}
