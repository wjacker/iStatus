import Foundation

final class PrivilegedMetricsClient {
    private let decoder = JSONDecoder()
    private var hasLoggedDevelopmentSkip = false

    func fetchCPUMetrics() async -> PrivilegedCPUMetricsSnapshot? {
        if PrivilegedHelperEnvironment.isDevelopmentRun {
            if !hasLoggedDevelopmentSkip {
                hasLoggedDevelopmentSkip = true
                debugLog("PrivilegedMetricsClient skipping helper in development run")
            }
            return nil
        }

        return await withCheckedContinuation { (continuation: CheckedContinuation<PrivilegedCPUMetricsSnapshot?, Never>) in
            let connection = NSXPCConnection(
                machServiceName: PrivilegedHelperConstants.machServiceName,
                options: .privileged
            )
            debugLog("PrivilegedMetricsClient connecting to \(PrivilegedHelperConstants.machServiceName)")
            connection.remoteObjectInterface = NSXPCInterface(with: PrivilegedMetricsXPCProtocol.self)
            connection.invalidationHandler = {
                debugLog("PrivilegedMetricsClient connection invalidated")
            }
            connection.interruptionHandler = {
                debugLog("PrivilegedMetricsClient connection interrupted")
            }
            connection.resume()

            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                debugLog("PrivilegedMetricsClient remote proxy error: \(error.localizedDescription)")
                connection.invalidate()
                continuation.resume(returning: nil)
            } as? PrivilegedMetricsXPCProtocol

            guard let proxy else {
                debugLog("PrivilegedMetricsClient could not create XPC proxy")
                connection.invalidate()
                continuation.resume(returning: nil)
                return
            }

            proxy.fetchCPUMetrics { [decoder] payload, errorMessage in
                defer { connection.invalidate() }

                if let errorMessage {
                    debugLog("PrivilegedMetricsClient helper error: \(errorMessage)")
                }

                guard let payload else {
                    continuation.resume(returning: nil)
                    return
                }

                do {
                    let snapshot = try decoder.decode(PrivilegedCPUMetricsSnapshot.self, from: payload)
                    continuation.resume(returning: snapshot)
                } catch {
                    debugLog("PrivilegedMetricsClient decode failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
