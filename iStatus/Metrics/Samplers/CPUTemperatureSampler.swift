import Foundation
import IOKit

final class CPUTemperatureSampler {
    private(set) var isSupported: Bool = false

    func sampleDetailed() -> CPUTemperatureDetail? {
        let smcSnapshot = sampleSnapshotFromAppleSMC()
        let ioSensors = sampleSensorRowsFromIOHWSensors()
        let sensors = (smcSnapshot?.sensors ?? []).isEmpty ? ioSensors : (smcSnapshot?.sensors ?? ioSensors)
        let overall = smcSnapshot?.overall ?? sensors.first?.celsius

        guard let overall else {
            isSupported = false
            return nil
        }

        isSupported = true
        return CPUTemperatureDetail(
            overall: overall,
            sensors: sensors,
            fans: smcSnapshot?.fans ?? []
        )
    }

    func sample() -> Double? {
        sampleDetailed()?.overall
    }

    private func sampleSensorRowsFromIOHWSensors() -> [CPUTemperatureSensorStat] {
        let matching = IOServiceMatching("IOHWSensor")
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var matches: [(score: Int, stat: CPUTemperatureSensorStat)] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            let properties = sensorProperties(for: service)
            if let value = temperatureValue(from: properties),
               let score = sensorScore(for: properties),
               let label = sensorLabel(for: properties) {
                matches.append((score, CPUTemperatureSensorStat(name: label, celsius: value)))
            }

            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        return matches.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.stat.name < rhs.stat.name
            }
            return lhs.score > rhs.score
        }
        .map(\.stat)
    }

    private func temperatureValue(from properties: [String: Any]) -> Double? {
        for key in ["current-value", "currentValue", "value", "temperature", "temp"] {
            if let normalized = normalizeTemperature(properties[key]) {
                return normalized
            }
        }
        return nil
    }

    private func sensorScore(for properties: [String: Any]) -> Int? {
        let name = stringProperty(in: properties, keys: ["location", "name", "device_type", "type"]).lowercased()
        guard name.contains("cpu") || name.contains("die") || name.contains("proximity") || name.contains("peci") else {
            return nil
        }

        var score = 0
        if name.contains("cpu") { score += 4 }
        if name.contains("die") { score += 3 }
        if name.contains("proximity") { score += 2 }
        if name.contains("peci") { score += 1 }
        return score
    }

    private func sensorLabel(for properties: [String: Any]) -> String? {
        let raw = stringProperty(in: properties, keys: ["location", "name", "device_type", "type"])
        guard !raw.isEmpty else { return nil }
        let lowered = raw.lowercased()
        if lowered.contains("eff") {
            return "CPU Efficiency Cores"
        }
        if lowered.contains("perf") {
            return "CPU Performance Cores"
        }
        if lowered.contains("proximity") {
            return "Airflow"
        }
        if lowered.contains("die") || lowered.contains("cpu") {
            return "CPU"
        }
        return raw
    }

    private func stringProperty(in properties: [String: Any], keys: [String]) -> String {
        for key in keys {
            if let text = properties[key] as? String, !text.isEmpty {
                return text
            }
        }
        return ""
    }

    private func sensorProperties(for service: io_service_t) -> [String: Any] {
        var properties: [String: Any] = [:]
        for key in ["location", "name", "device_type", "type", "current-value", "currentValue", "value", "temperature", "temp"] {
            if let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() {
                properties[key] = value
            }
        }
        return properties
    }

    private func sampleSnapshotFromAppleSMC() -> (overall: Double?, sensors: [CPUTemperatureSensorStat], fans: [CPUFanStat])? {
        guard let service = findSMCService() else {
            return nil
        }
        defer { IOObjectRelease(service) }

        guard let connection = openSMCConnection(service: service) else { return nil }
        defer { IOServiceClose(connection) }

        let sensorSpecs: [(name: String, key: String, rank: Int)] = [
            ("CPU", "TC0D", 100),
            ("CPU", "TC0E", 99),
            ("CPU", "TC0F", 98),
            ("CPU", "TC0C", 97),
            ("CPU", "TC0H", 96),
            ("CPU Performance Cores", "TC0P", 90),
            ("CPU Efficiency Cores", "TC1C", 80),
            ("CPU Efficiency Cores", "TC2C", 79),
            ("CPU Efficiency Cores", "TC3C", 78),
            ("Graphics", "TG0D", 70),
            ("Memory", "Tm0P", 60),
            ("Airflow", "TA0P", 50),
            ("Battery", "TB1T", 40),
            ("SSD", "TN0D", 30),
            ("Wi-Fi", "TW0P", 20),
            ("Palm Rest", "Th1H", 10)
        ]

        var overall: Double?
        var sensors: [CPUTemperatureSensorStat] = []
        var seenNames = Set<String>()
        for spec in sensorSpecs {
            if let value = readSMCKey(spec.key, connection: connection) {
                if overall == nil, spec.rank >= 80 {
                    overall = value
                }
                if seenNames.insert(spec.name).inserted {
                    sensors.append(CPUTemperatureSensorStat(name: spec.name, celsius: value))
                }
            }
        }

        let fans = sampleFans(connection: connection)

        return (overall, sensors, fans)
    }

    private func findSMCService() -> io_service_t? {
        let serviceNames = [
            "AppleSMCKeysEndpoint",
            "AppleSMC",
            "AppleSMCInterface"
        ]

        for name in serviceNames {
            let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(name))
            if service != 0 {
                return service
            }
        }

        return nil
    }

    private func sampleFans(connection: io_connect_t) -> [CPUFanStat] {
        let dynamicCount = readSMCIntegerKey("FNum", connection: connection).map(Int.init)
        let upperBound = max(dynamicCount ?? 0, 2)

        var fans: [CPUFanStat] = []
        for index in 0..<upperBound {
            let speedKey = String(format: "F%dAc", index)
            guard let rpm = readSMCKey(speedKey, connection: connection), rpm > 0 else {
                continue
            }

            let labelKey = String(format: "F%dID", index)
            let label = readSMCStringKey(labelKey, connection: connection)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let fallback = upperBound == 1 ? "System Fan" : "Fan \(index + 1)"
            let name = (label?.isEmpty == false) ? label! : fallback

            fans.append(CPUFanStat(name: name, rpm: rpm))
        }

        return fans
    }

    private func normalizeTemperature(_ raw: Any?) -> Double? {
        let number: Double?
        switch raw {
        case let value as NSNumber:
            number = value.doubleValue
        case let value as Double:
            number = value
        case let value as Int:
            number = Double(value)
        default:
            number = nil
        }

        guard let rawValue = number, rawValue.isFinite else { return nil }
        if (0 ... 130).contains(rawValue) {
            return rawValue
        }
        if (0 ... 130_000).contains(rawValue) {
            return rawValue / 1_000
        }
        if (0 ... 1_300_000).contains(rawValue) {
            return rawValue / 10_000
        }
        return nil
    }

    private func readSMCKey(_ key: String, connection: io_connect_t) -> Double? {
        guard let keyInfo = readKeyInfo(key, connection: connection) else { return nil }
        guard let bytes = readBytes(for: key, connection: connection, dataSize: keyInfo.dataSize) else { return nil }

        switch keyInfo.dataType {
        case CPUTemperatureSampler.fourCharCode("sp78"):
            return decodeSP78(bytes)
        case CPUTemperatureSampler.fourCharCode("flt "):
            return decodeFloat(bytes)
        case CPUTemperatureSampler.fourCharCode("fpe2"):
            return decodeFPE2(bytes)
        default:
            return nil
        }
    }

    private func readSMCIntegerKey(_ key: String, connection: io_connect_t) -> UInt32? {
        guard let keyInfo = readKeyInfo(key, connection: connection) else { return nil }
        guard let bytes = readBytes(for: key, connection: connection, dataSize: keyInfo.dataSize) else { return nil }

        switch keyInfo.dataType {
        case Self.fourCharCode("ui8 "):
            guard let first = bytes.first else { return nil }
            return UInt32(first)
        case Self.fourCharCode("ui16"):
            guard bytes.count >= 2 else { return nil }
            return UInt32(bytes[0]) << 8 | UInt32(bytes[1])
        case Self.fourCharCode("ui32"):
            guard bytes.count >= 4 else { return nil }
            return UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
        default:
            return nil
        }
    }

    private func readSMCStringKey(_ key: String, connection: io_connect_t) -> String? {
        guard let keyInfo = readKeyInfo(key, connection: connection) else { return nil }
        guard let bytes = readBytes(for: key, connection: connection, dataSize: keyInfo.dataSize) else { return nil }

        switch keyInfo.dataType {
        case Self.fourCharCode("ch8*"), Self.fourCharCode("{fds"):
            let filtered = bytes.prefix { $0 != 0 }
            guard !filtered.isEmpty else { return nil }
            return String(bytes: filtered, encoding: .ascii)
        default:
            return nil
        }
    }

    private func openSMCConnection(service: io_service_t) -> io_connect_t? {
        var connection: io_connect_t = 0
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard result == KERN_SUCCESS else { return nil }
        return connection
    }

    private func readKeyInfo(_ key: String, connection: io_connect_t) -> (dataSize: UInt32, dataType: UInt32)? {
        var input = SMCParamStruct()
        input.key = Self.fourCharCode(key)
        input.data8 = SMCCommand.readKeyInfo.rawValue

        var output = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.stride
        let result = withUnsafeMutablePointer(to: &input) { inputPtr in
            withUnsafeMutablePointer(to: &output) { outputPtr in
                IOConnectCallStructMethod(
                    connection,
                    2,
                    inputPtr,
                    MemoryLayout<SMCParamStruct>.stride,
                    outputPtr,
                    &outputSize
                )
            }
        }

        guard result == KERN_SUCCESS else { return nil }
        return (output.keyInfo.dataSize, output.keyInfo.dataType)
    }

    private func readBytes(for key: String, connection: io_connect_t, dataSize: UInt32) -> [UInt8]? {
        var input = SMCParamStruct()
        input.key = Self.fourCharCode(key)
        input.keyInfo.dataSize = dataSize
        input.data8 = SMCCommand.readBytes.rawValue

        var output = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.stride
        let result = withUnsafeMutablePointer(to: &input) { inputPtr in
            withUnsafeMutablePointer(to: &output) { outputPtr in
                IOConnectCallStructMethod(
                    connection,
                    2,
                    inputPtr,
                    MemoryLayout<SMCParamStruct>.stride,
                    outputPtr,
                    &outputSize
                )
            }
        }

        guard result == KERN_SUCCESS else { return nil }
        let size = min(Int(dataSize), output.byteArray.count)
        return Array(output.byteArray.prefix(size))
    }

    private func decodeSP78(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= 2 else { return nil }
        let combined = Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        return Double(combined) / 256.0
    }

    private func decodeFloat(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= 4 else { return nil }
        let bitPattern = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
        let value = Float(bitPattern: bitPattern)
        guard value.isFinite else { return nil }
        return Double(value)
    }

    private func decodeFPE2(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= 2 else { return nil }
        let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
        return Double(raw) / 4.0
    }

    private static func fourCharCode(_ key: String) -> UInt32 {
        key.utf8.prefix(4).reduce(0) { ($0 << 8) | UInt32($1) }
    }
}

private enum SMCCommand: UInt8 {
    case readKeyInfo = 9
    case readBytes = 5
}

private struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private struct SMCParamStruct {
    var key: UInt32 = 0
    var version = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var rawBytes = (UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0))
}

private extension SMCParamStruct {
    var byteArray: [UInt8] {
        [
            self.rawBytes.0, self.rawBytes.1, self.rawBytes.2, self.rawBytes.3,
            self.rawBytes.4, self.rawBytes.5, self.rawBytes.6, self.rawBytes.7,
            self.rawBytes.8, self.rawBytes.9, self.rawBytes.10, self.rawBytes.11,
            self.rawBytes.12, self.rawBytes.13, self.rawBytes.14, self.rawBytes.15,
            self.rawBytes.16, self.rawBytes.17, self.rawBytes.18, self.rawBytes.19,
            self.rawBytes.20, self.rawBytes.21, self.rawBytes.22, self.rawBytes.23,
            self.rawBytes.24, self.rawBytes.25, self.rawBytes.26, self.rawBytes.27,
            self.rawBytes.28, self.rawBytes.29, self.rawBytes.30, self.rawBytes.31
        ]
    }
}
