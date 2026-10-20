import Foundation
import LocalAuthentication
import Observation

/// Face ID / Touch ID lock (spec Part 37). Falls back to the device passcode or Mac password.
@MainActor
@Observable
final class AppLock {
    private(set) var isLocked = false
    private(set) var lastFailure: String?

    var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "your passcode"
        }
    }

    func lock() {
        isLocked = true
    }

    func unlock() async {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No passcode is set on the device, so there is nothing to check against.
            isLocked = false
            return
        }
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock Progress One")
            isLocked = !success
            lastFailure = nil
        } catch {
            lastFailure = error.localizedDescription
        }
    }
}
