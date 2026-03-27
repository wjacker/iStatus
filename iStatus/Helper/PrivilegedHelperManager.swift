import Foundation
import ServiceManagement

@MainActor
final class PrivilegedHelperManager {
    static let shared = PrivilegedHelperManager()

    private var didAttemptRegistration = false

    private init() {}

    func registerIfNeeded() {
        guard !didAttemptRegistration else { return }
        didAttemptRegistration = true

        if PrivilegedHelperEnvironment.isDevelopmentRun {
            debugLog("Privileged helper registration skipped in development run")
            return
        }

        Task.detached(priority: .utility) {
            do {
                let daemon = SMAppService.daemon(plistName: PrivilegedHelperConstants.launchdPlistName)
                let bundlePath = Bundle.main.bundleURL.path
                debugLog("Privileged helper bundle path: \(bundlePath)")
                debugLog("Privileged helper status before register: \(Self.describe(daemon.status))")

                switch daemon.status {
                case .enabled:
                    debugLog("Privileged helper already enabled")
                case .requiresApproval:
                    debugLog("Privileged helper requires approval in System Settings > Login Items")
                case .notFound:
                    debugLog("Privileged helper not found in app bundle")
                case .notRegistered:
                    debugLog("Privileged helper not registered yet")
                @unknown default:
                    debugLog("Privileged helper status is unknown")
                }

                try daemon.register()
                debugLog("Privileged helper registered; status after register: \(Self.describe(daemon.status))")
            } catch {
                debugLog("Privileged helper registration failed: \(error.localizedDescription)")
            }
        }
    }

    nonisolated private static func describe(_ status: SMAppService.Status) -> String {
        switch status {
        case .notRegistered:
            return "notRegistered"
        case .enabled:
            return "enabled"
        case .requiresApproval:
            return "requiresApproval"
        case .notFound:
            return "notFound"
        @unknown default:
            return "unknown"
        }
    }
}
