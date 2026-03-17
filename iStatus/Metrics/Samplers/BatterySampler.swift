import Foundation
import IOKit.ps
import IOKit
import Darwin

final class BatterySampler {
    func sampleDetailed() -> BatteryDetail? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            guard let current = description[kIOPSCurrentCapacityKey] as? Double,
                  let max = description[kIOPSMaxCapacityKey] as? Double,
                  max > 0 else {
                continue
            }

            let percent = (current / max) * 100
            let isCharging = (description[kIOPSIsChargingKey] as? Bool) ?? false
            let powerState = (description[kIOPSPowerSourceStateKey] as? String) ?? ""
            let externalPower = powerState == kIOPSACPowerValue
            let registry = registryProperties()

            let adapterDetails = registry["AdapterDetails"] as? [String: Any]
            let adapterPowerWatts = number(from: adapterDetails?["Watts"])
            let rawAmperage = number(from: registry["Amperage"])
            let rawVoltage = number(from: registry["Voltage"])
            let rawTemperature = number(from: registry["Temperature"])
            let currentCapacity = int(from: registry["AppleRawCurrentCapacity"]) ?? int(from: registry["CurrentCapacity"])
            let maxCapacity = int(from: registry["AppleRawMaxCapacity"]) ?? int(from: registry["MaxCapacity"])
            let designCapacity = int(from: registry["DesignCapacity"])
            let healthPercent: Double? = {
                guard let designCapacity, let maxCapacity, designCapacity > 0 else { return nil }
                return (Double(maxCapacity) / Double(designCapacity)) * 100
            }()

            return BatteryDetail(
                percent: percent,
                healthPercent: healthPercent,
                adapterPowerWatts: adapterPowerWatts,
                batteryPowerWatts: batteryPowerWatts(amperage: rawAmperage, voltage: rawVoltage),
                amperageAmps: rawAmperage.map { abs($0) / 1000.0 },
                voltageVolts: rawVoltage.map { $0 / 1000.0 },
                temperatureCelsius: rawTemperature.map { $0 / 100.0 },
                cycleCount: int(from: registry["CycleCount"]),
                condition: registry["BatteryHealthCondition"] as? String ?? registry["Condition"] as? String,
                designCapacitymAh: designCapacity,
                currentCapacitymAh: currentCapacity,
                cellVoltages: cellVoltages(from: registry),
                isCharging: isCharging,
                isExternalPowerConnected: externalPower,
                lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled
            )
        }

        return nil
    }

    func sample() -> Double? {
        sampleDetailed()?.percent
    }

    private func registryProperties() -> [String: Any] {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return [:] }
        defer { IOObjectRelease(service) }

        var propertiesRef: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &propertiesRef, kCFAllocatorDefault, 0)
        guard result == KERN_SUCCESS,
              let properties = propertiesRef?.takeRetainedValue() as? [String: Any] else {
            return [:]
        }
        return properties
    }

    private func number(from value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let intValue = value as? Int {
            return Double(intValue)
        }
        return nil
    }

    private func int(from value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        return value as? Int
    }

    private func batteryPowerWatts(amperage: Double?, voltage: Double?) -> Double? {
        guard let amperage, let voltage else { return nil }
        return abs(amperage * voltage) / 1_000_000.0
    }

    private func cellVoltages(from registry: [String: Any]) -> [Double] {
        var voltages: [Double] = []
        for index in 1...8 {
            if let value = number(from: registry["CellVoltage\(index)"]) {
                voltages.append(value / 1000.0)
            }
        }

        if voltages.isEmpty, let value = number(from: registry["CellVoltage"]) {
            voltages.append(value / 1000.0)
        }

        return voltages
    }
}

final class SignificantEnergySampler {
    func sampleTopApp() -> SignificantEnergyApp? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,%cpu=,comm="]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)
        let lines = output.split(separator: "\n")

        var best: (pid: Int, cpu: Double, path: String)?
        for line in lines {
            let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count == 3,
                  let pid = Int(parts[0]),
                  let cpu = Double(parts[1]) else {
                continue
            }

            let path = String(parts[2])
            if cpu < 8 { continue }
            if path.hasPrefix("/System/") || path.hasPrefix("/usr/") { continue }
            if best == nil || cpu > best!.cpu {
                best = (pid, cpu, path)
            }
        }

        guard let best else { return nil }
        let bundlePath = bundlePathForPID(pid_t(best.pid))
        let name = bundlePath.flatMap { displayNameForBundle(path: $0) } ?? URL(fileURLWithPath: best.path).lastPathComponent
        return SignificantEnergyApp(pid: best.pid, name: name, bundlePath: bundlePath)
    }

    private func bundlePathForPID(_ pid: pid_t) -> String? {
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let len = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
        guard len > 0 else { return nil }
        let fullPath = String(cString: pathBuffer)
        guard let range = fullPath.range(of: ".app/") else { return nil }
        let end = fullPath.index(range.lowerBound, offsetBy: 4)
        return String(fullPath[..<end])
    }

    private func displayNameForBundle(path: String) -> String? {
        let url = URL(fileURLWithPath: path)
        return Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
            Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String
    }
}
