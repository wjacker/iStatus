import Foundation

enum PrivilegedHelperEnvironment {
    private static let xcodeDerivedDataMarker = "/DerivedData/"

    static var isDevelopmentRun: Bool {
        let bundlePath = Bundle.main.bundleURL.path
        return bundlePath.contains(xcodeDerivedDataMarker) || !bundlePath.hasPrefix("/Applications/")
    }

    static var developmentFallbackMessage: String {
        "Privileged helper is unavailable when running from Xcode/DerivedData. Install the signed app in /Applications to enable powermetrics thermal, power, and fan data."
    }
}
