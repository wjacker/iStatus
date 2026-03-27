import Foundation

enum PrivilegedHelperConstants {
    static let machServiceName = "com.jack.istatus.powermetrics-helper"
    static let launchdPlistName = "com.jack.istatus.powermetrics-helper.plist"
    static let executableName = "iStatusPowermetricsHelper"
}

struct PrivilegedTemperatureSensorSnapshot: Codable, Sendable {
    let name: String
    let celsius: Double
}

struct PrivilegedFanSnapshot: Codable, Sendable {
    let name: String
    let rpm: Double
}

struct PrivilegedPowerSnapshot: Codable, Sendable {
    let packageWatts: Double?
    let cpuWatts: Double?
}

struct PrivilegedThermalSnapshot: Codable, Sendable {
    let pressureLevel: String?
}

struct PrivilegedCPUMetricsSnapshot: Codable, Sendable {
    let overallTemperatureCelsius: Double?
    let sensors: [PrivilegedTemperatureSensorSnapshot]
    let fans: [PrivilegedFanSnapshot]
    let power: PrivilegedPowerSnapshot?
    let thermal: PrivilegedThermalSnapshot?
    let statusMessage: String?

    var hasData: Bool {
        overallTemperatureCelsius != nil ||
        !sensors.isEmpty ||
        !fans.isEmpty ||
        power?.packageWatts != nil ||
        power?.cpuWatts != nil ||
        thermal?.pressureLevel != nil
    }
}
