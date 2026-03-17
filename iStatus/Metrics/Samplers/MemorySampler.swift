import Foundation
import IOKit
import Darwin

private struct XswUsage {
    var xsu_total: UInt64 = 0
    var xsu_avail: UInt64 = 0
    var xsu_used: UInt64 = 0
    var xsu_pagesize: UInt32 = 0
    var xsu_encrypted: Int32 = 0
}

final class MemorySampler {
    func sampleDetailed() -> MemoryDetail? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        let active = UInt64(stats.active_count)
        let inactive = UInt64(stats.inactive_count)
        let wired = UInt64(stats.wire_count)
        let compressed = UInt64(stats.compressor_page_count)
        let free = UInt64(stats.free_count)
        let pageIns = UInt64(stats.pageins)
        let pageOuts = UInt64(stats.pageouts)

        let appPages = active + inactive
        let usedPages = appPages + wired + compressed
        guard usedPages > 0 else { return nil }

        let appBytes = appPages * UInt64(pageSize)
        let wiredBytes = wired * UInt64(pageSize)
        let compressedBytes = compressed * UInt64(pageSize)
        let totalBytes = totalMemoryBytes()
        guard totalBytes > 0 else { return nil }
        let usedBytes = appBytes + wiredBytes + compressedBytes
        let freeBytes = totalBytes > usedBytes ? (totalBytes - usedBytes) : 0
        let usedPercent = (Double(usedBytes) / Double(totalBytes)) * 100
        let pressurePercent = (Double(wiredBytes + compressedBytes + (active * UInt64(pageSize))) / Double(totalBytes)) * 100
        let pageInsBytes = pageIns * UInt64(pageSize)
        let pageOutsBytes = pageOuts * UInt64(pageSize)
        let (swapUsed, swapTotal) = swapUsage()

        return MemoryDetail(
            appBytes: appBytes,
            wiredBytes: wiredBytes,
            compressedBytes: compressedBytes,
            freeBytes: freeBytes,
            totalBytes: totalBytes,
            usedPercent: usedPercent,
            pressurePercent: pressurePercent,
            pageInsBytes: pageInsBytes,
            pageOutsBytes: pageOutsBytes,
            swapUsedBytes: swapUsed,
            swapTotalBytes: swapTotal
        )
    }

    func sample() -> Double? {
        sampleDetailed()?.usedPercent
    }

    private func swapUsage() -> (UInt64, UInt64) {
        var usage = XswUsage()
        var size = MemoryLayout<XswUsage>.size
        let result = sysctlbyname("vm.swapusage", &usage, &size, nil, 0)
        guard result == 0 else { return (0, 0) }
        return (usage.xsu_used, usage.xsu_total)
    }

    private func totalMemoryBytes() -> UInt64 {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        let result = sysctlbyname("hw.memsize", &value, &size, nil, 0)
        if result != 0 {
            return 0
        }
        return value
    }
}

final class MemoryProcessSampler {
    func sampleTop(limit: Int) -> [ProcessMemStat] {
        if let stats = sampleViaLibproc(), !stats.isEmpty {
            return stats.sorted { $0.memoryBytes > $1.memoryBytes }
                .prefix(limit)
                .map { $0 }
        }

        let output = runPs()
        guard !output.isEmpty else { return [] }
        let lines = output.split(separator: "\n").map(String.init)

        var stats: [ProcessMemStat] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count >= 3 else { continue }
            let pid = Int(parts[0])
            let rssKB = UInt64(parts[1]) ?? 0
            let name = sanitizeName(String(parts[2]))
            stats.append(ProcessMemStat(pid: pid, name: name, memoryBytes: rssKB * 1024, bundlePath: nil))
        }

        return stats.sorted { $0.memoryBytes > $1.memoryBytes }
            .prefix(limit)
            .map { $0 }
    }

    private func runPs() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,rss=,comm="]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return ""
        }
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
    }

    private func sampleViaLibproc() -> [ProcessMemStat]? {
        let size = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard size > 0 else { return nil }
        let count = Int(size) / MemoryLayout<pid_t>.size
        var pids = [pid_t](repeating: 0, count: count)
        let actualSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, size)
        guard actualSize > 0 else { return nil }

        let actualCount = Int(actualSize) / MemoryLayout<pid_t>.size
        var grouped: [String: (name: String, bundlePath: String?, bytes: UInt64)] = [:]
        var nameBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))

        for i in 0..<actualCount {
            let pid = pids[i]
            if pid == 0 { continue }

            var info = rusage_info_v4()
            let result = withUnsafeMutablePointer(to: &info) { ptr -> Int32 in
                let raw = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: rusage_info_t?.self)
                return proc_pid_rusage(pid, RUSAGE_INFO_V4, raw)
            }
            if result != 0 { continue }

            let nameLen = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            let rawName = nameLen > 0 ? String(cString: nameBuffer) : ""
            let name = sanitizeName(rawName)
            if name.isEmpty { continue }

            let footprint = UInt64(info.ri_phys_footprint)
            let bundlePath = bundlePathForPID(pid, pathBuffer: &pathBuffer)
            let key = bundlePath ?? name
            let displayName = bundlePath.flatMap { displayNameForBundle(path: $0) } ?? name

            if var entry = grouped[key] {
                entry.bytes += footprint
                grouped[key] = entry
            } else {
                grouped[key] = (displayName, bundlePath, footprint)
            }
        }

        return grouped.map { key, value in
            ProcessMemStat(pid: nil, name: value.name, memoryBytes: value.bytes, bundlePath: value.bundlePath)
        }
    }

    private func bundlePathForPID(_ pid: pid_t, pathBuffer: inout [CChar]) -> String? {
        let len = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
        guard len > 0 else { return nil }
        let fullPath = String(cString: pathBuffer)
        guard let range = fullPath.range(of: ".app/") else { return nil }
        let end = fullPath.index(range.lowerBound, offsetBy: 4)
        return String(fullPath[..<end])
    }

    private func displayNameForBundle(path: String) -> String? {
        let url = URL(fileURLWithPath: path)
        return (try? Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ??
            (try? Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String)
    }

    private func sanitizeName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("/") {
            return URL(fileURLWithPath: trimmed).lastPathComponent
        }
        return trimmed
    }
}
