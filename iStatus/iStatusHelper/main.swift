import Foundation

@inline(__always)
func debugLog(_ message: String) {
    fputs("[iStatusHelper] \(message)\n", stderr)
    fflush(stderr)
}

let daemon = PowermetricsDaemon()
let listener = NSXPCListener(machServiceName: PrivilegedHelperConstants.machServiceName)
listener.delegate = daemon
listener.resume()
RunLoop.main.run()
