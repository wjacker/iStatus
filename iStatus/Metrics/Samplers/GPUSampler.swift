import Foundation
import IOKit

final class GPUSampler {
    private(set) var isSupported: Bool = false

    func sample() -> Double? {
        guard let value = sampleFromIORegistry() else {
            isSupported = false
            return nil
        }
        isSupported = true
        return value
    }

    private func sampleFromIORegistry() -> Double? {
        let matching = IOServiceMatching("IOAccelerator")
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMasterPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var values: [Double] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let percent = readUtilization(from: service) {
                values.append(percent)
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        guard !values.isEmpty else { return nil }
        let total = values.reduce(0, +)
        return total / Double(values.count)
    }

    private func readUtilization(from service: io_object_t) -> Double? {
        if let value = readKey(service, key: "GPU Busy") {
            return normalize(value)
        }
        if let value = readKey(service, key: "Device Utilization") {
            return normalize(value)
        }
        if let value = readKey(service, key: "GPU Core Utilization") {
            return normalize(value)
        }
        if let stats = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? [String: Any] {
            for key in ["GPU Busy", "Device Utilization", "GPU Core Utilization", "Graphics Utilization"] {
                if let value = stats[key] {
                    if let normalized = normalize(value) {
                        return normalized
                    }
                }
            }
        }
        return nil
    }

    private func readKey(_ service: io_object_t, key: String) -> Any? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue()
    }

    private func normalize(_ value: Any) -> Double? {
        if let number = value as? NSNumber {
            return normalize(number.doubleValue)
        }
        if let doubleValue = value as? Double {
            return normalize(doubleValue)
        }
        if let intValue = value as? Int {
            return normalize(Double(intValue))
        }
        return nil
    }

    private func normalize(_ raw: Double) -> Double? {
        if raw.isNaN { return nil }
        if raw <= 1.0 {
            return max(0, min(raw * 100, 100))
        }
        return max(0, min(raw, 100))
    }
}
