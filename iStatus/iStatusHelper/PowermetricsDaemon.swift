import Foundation

final class PowermetricsDaemon: NSObject, NSXPCListenerDelegate, PrivilegedMetricsXPCProtocol {
    private let encoder = JSONEncoder()
    private let reader = PowermetricsReader()
    private let fallbackSampler = CPUTemperatureSampler()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: PrivilegedMetricsXPCProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    func fetchCPUMetrics(reply: @escaping (Data?, String?) -> Void) {
        let fallback = fallbackSampler.sampleDirectDetailed()
        let snapshot = reader.sampleSnapshot(fallback: fallback)

        do {
            let payload = try encoder.encode(snapshot)
            reply(payload, nil)
        } catch {
            reply(nil, error.localizedDescription)
        }
    }
}

private struct PowermetricsReader {
    func sampleSnapshot(fallback: CPUTemperatureDetail?) -> PrivilegedCPUMetricsSnapshot {
        let result = readPowermetrics()
        let power = result.plist.flatMap(parsePowerSnapshot)
        let thermal = result.plist.flatMap(parseThermalSnapshot)

        let statusMessage: String?
        if let errorMessage = result.errorMessage, !errorMessage.isEmpty {
            statusMessage = errorMessage
        } else if let fallbackMessage = fallback?.statusMessage, !fallbackMessage.isEmpty {
            statusMessage = fallbackMessage
        } else {
            statusMessage = nil
        }

        return PrivilegedCPUMetricsSnapshot(
            overallTemperatureCelsius: fallback?.overall,
            sensors: (fallback?.sensors ?? []).map {
                PrivilegedTemperatureSensorSnapshot(name: $0.name, celsius: $0.celsius)
            },
            fans: (fallback?.fans ?? []).map {
                PrivilegedFanSnapshot(name: $0.name, rpm: $0.rpm)
            },
            power: power,
            thermal: thermal,
            statusMessage: statusMessage
        )
    }

    private func readPowermetrics() -> (plist: [String: Any]?, errorMessage: String?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/powermetrics")
        process.arguments = ["-n", "1", "-i", "1000", "-f", "plist", "-s", "cpu_power,thermal"]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            return (nil, "Unable to launch powermetrics: \(error.localizedDescription)")
        }

        process.waitUntilExit()

        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
            let message = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (nil, message ?? "powermetrics exited with status \(process.terminationStatus)")
        }

        let payloads = stdoutData.split(separator: 0).compactMap { Data($0) }
        guard let plistData = payloads.last else {
            return (nil, "powermetrics returned no plist payload")
        }

        do {
            let object = try PropertyListSerialization.propertyList(from: plistData, format: nil)
            return (object as? [String: Any], nil)
        } catch {
            return (nil, "Failed to parse powermetrics output: \(error.localizedDescription)")
        }
    }

    private func parsePowerSnapshot(from plist: [String: Any]) -> PrivilegedPowerSnapshot? {
        guard let elapsedNanoseconds = lookupDouble(in: plist, path: ["elapsed_ns"]) else {
            return PrivilegedPowerSnapshot(
                packageWatts: lookupDouble(in: plist, path: ["processor", "combined_power"]).map { $0 / 1_000 },
                cpuWatts: nil
            )
        }

        let packageWatts = lookupDouble(in: plist, path: ["processor", "combined_power"]).map { $0 / 1_000 }
        let cpuMilliJoules = lookupDouble(in: plist, path: ["processor", "cpu_energy"])
        let cpuWatts = cpuMilliJoules.map { milliJoules in
            let joules = milliJoules / 1_000
            let seconds = elapsedNanoseconds / 1_000_000_000
            guard seconds > 0 else { return 0.0 }
            return joules / seconds
        }

        guard packageWatts != nil || cpuWatts != nil else { return nil }
        return PrivilegedPowerSnapshot(packageWatts: packageWatts, cpuWatts: cpuWatts)
    }

    private func parseThermalSnapshot(from plist: [String: Any]) -> PrivilegedThermalSnapshot? {
        let pressureLevel = lookupString(in: plist, path: ["thermal_pressure"])
        guard pressureLevel != nil else { return nil }
        return PrivilegedThermalSnapshot(pressureLevel: pressureLevel)
    }

    private func lookupDouble(in dictionary: [String: Any], path: [String]) -> Double? {
        var current: Any = dictionary
        for key in path {
            guard let object = (current as? [String: Any])?[key] else { return nil }
            current = object
        }

        switch current {
        case let value as NSNumber:
            return value.doubleValue
        case let value as Double:
            return value
        case let value as Int:
            return Double(value)
        default:
            return nil
        }
    }

    private func lookupString(in dictionary: [String: Any], path: [String]) -> String? {
        var current: Any = dictionary
        for key in path {
            guard let object = (current as? [String: Any])?[key] else { return nil }
            current = object
        }
        return current as? String
    }
}
