import Foundation

struct MetricSample: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let value: Double
}

enum MetricType: String, CaseIterable, Hashable, Sendable {
    case cpuUsage
    case cpuUser
    case cpuSystem
    case cpuTemperature
    case memoryUsedPercent
    case memoryFreePercent
    case memoryAppBytes
    case memoryWiredBytes
    case memoryCompressedBytes
    case memoryFreeBytes
    case diskUsedPercent
    case diskReadBytesPerSecond
    case diskWriteBytesPerSecond
    case networkTotalKBps
    case networkDownKBps
    case networkUpKBps
    case batteryPercent
}

struct CPUDetail: Sendable {
    let overall: Double
    let user: Double
    let system: Double
    let perCore: [Double]
}

struct CPUTemperatureSensorStat: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let celsius: Double
}

struct CPUFanStat: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let rpm: Double
}

struct CPUTemperatureDetail: Sendable {
    let overall: Double
    let sensors: [CPUTemperatureSensorStat]
    let fans: [CPUFanStat]
}

struct MemoryDetail: Sendable {
    let appBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let freeBytes: UInt64
    let totalBytes: UInt64
    let usedPercent: Double
    let pressurePercent: Double
    let pageInsBytes: UInt64
    let pageOutsBytes: UInt64
    let swapUsedBytes: UInt64
    let swapTotalBytes: UInt64
}

struct DiskVolumeStat: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let usedPercent: Double
    let totalBytes: UInt64
    let usedBytes: UInt64
    let purgeableBytes: UInt64
    let freeBytes: UInt64
}

struct DiskDetail: Sendable {
    let volume: DiskVolumeStat
    let readBytesPerSecond: Double
    let writeBytesPerSecond: Double
}

struct ProcessDiskStat: Identifiable, Sendable {
    let id = UUID()
    let pid: Int?
    let name: String
    let readBytesPerSecond: Double
    let writeBytesPerSecond: Double
    let bundlePath: String?
}

struct NetworkDetail: Sendable {
    let downKBps: Double
    let upKBps: Double
    var totalKBps: Double { downKBps + upKBps }
}

struct BatteryDetail: Sendable {
    let percent: Double
    let healthPercent: Double?
    let adapterPowerWatts: Double?
    let batteryPowerWatts: Double?
    let amperageAmps: Double?
    let voltageVolts: Double?
    let temperatureCelsius: Double?
    let cycleCount: Int?
    let condition: String?
    let designCapacitymAh: Int?
    let currentCapacitymAh: Int?
    let cellVoltages: [Double]
    let isCharging: Bool
    let isExternalPowerConnected: Bool
    let lowPowerModeEnabled: Bool
}

struct SignificantEnergyApp: Sendable {
    let pid: Int?
    let name: String
    let bundlePath: String?
}

struct IPInfo: Sendable {
    var publicIPv4: String? = nil
    var publicIPv6: String? = nil
    var localIPv4: [String] = []
    var localIPv6: [String] = []
}

struct ProcessNetStat: Identifiable, Sendable {
    let id = UUID()
    let pid: Int?
    let name: String
    let downKBps: Double
    let upKBps: Double
    let bundlePath: String?
}

struct ProcessMemStat: Identifiable, Sendable {
    let id = UUID()
    let pid: Int?
    let name: String
    let memoryBytes: UInt64
    let bundlePath: String?
}
