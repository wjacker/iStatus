import Foundation
import Darwin

final class DiskSampler {
    func sampleDetailed() -> [DiskVolumeStat] {
        let filterKeys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeIsEjectableKey,
            .volumeIsRemovableKey,
            .volumeIsReadOnlyKey,
            .isVolumeKey
        ]

        let capacityKeys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityForOpportunisticUsageKey
        ]

        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(filterKeys),
            options: [.skipHiddenVolumes]
        ) else {
            return []
        }

        var stats: [DiskVolumeStat] = []
        for url in urls {
            guard let filterValues = try? url.resourceValues(forKeys: filterKeys) else { continue }
            guard shouldIncludeVolume(at: url, values: filterValues) else { continue }
            guard let values = try? url.resourceValues(forKeys: capacityKeys) else { continue }

            let name = values.volumeName ?? url.lastPathComponent
            let total = UInt64(values.volumeTotalCapacity ?? 0)
            let importantFree = UInt64(values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 0))
            let opportunisticFree = UInt64(values.volumeAvailableCapacityForOpportunisticUsage ?? Int64(values.volumeAvailableCapacity ?? 0))
            guard total > 0 else { continue }
            let purgeable = opportunisticFree > importantFree ? (opportunisticFree - importantFree) : 0
            let free = min(importantFree, total)
            let used = total > (free + purgeable) ? (total - free - purgeable) : 0
            let usedPercent = (Double(used) / Double(total)) * 100
            stats.append(
                DiskVolumeStat(
                    name: name,
                    usedPercent: usedPercent,
                    totalBytes: total,
                    usedBytes: used,
                    purgeableBytes: purgeable,
                    freeBytes: free
                )
            )
        }

        return stats.sorted { $0.usedPercent > $1.usedPercent }
    }

    private func shouldIncludeVolume(at url: URL, values: URLResourceValues) -> Bool {
        let path = url.path
        if values.isVolume != true { return false }
        if path == "/" { return true }
        if path.hasPrefix("/System/Volumes/") { return false }
        if path.hasPrefix("/private/var/") { return false }
        if path.hasPrefix("/dev/") { return false }
        if values.volumeIsReadOnly == true { return false }
        if values.volumeIsRemovable == true { return false }
        if values.volumeIsEjectable == true { return false }
        if path.hasPrefix("/Volumes/") { return false }
        return true
    }

    func sample() -> Double? {
        guard let root = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let total = root[.systemSize] as? NSNumber,
              let free = root[.systemFreeSize] as? NSNumber else { return nil }
        let used = total.doubleValue - free.doubleValue
        guard total.doubleValue > 0 else { return nil }
        return (used / total.doubleValue) * 100
    }
}

final class DiskProcessSampler {
    private var previousByPID: [pid_t: Usage] = [:]
    private var previousTimestamp: Date?

    func sample(limit: Int) -> (readBytesPerSecond: Double, writeBytesPerSecond: Double, processes: [ProcessDiskStat])? {
        let now = Date()
        let current = currentUsageByPID()

        guard let previousTimestamp else {
            self.previousTimestamp = now
            previousByPID = current
            return nil
        }

        let deltaTime = now.timeIntervalSince(previousTimestamp)
        self.previousTimestamp = now
        defer { previousByPID = current }

        guard deltaTime > 0 else { return nil }

        var stats: [ProcessDiskStat] = []
        var totalReadDelta: UInt64 = 0
        var totalWriteDelta: UInt64 = 0
        for (pid, usage) in current {
            guard let previous = previousByPID[pid] else { continue }

            let readDelta = usage.readBytes >= previous.readBytes ? (usage.readBytes - previous.readBytes) : 0
            let writeDelta = usage.writeBytes >= previous.writeBytes ? (usage.writeBytes - previous.writeBytes) : 0
            totalReadDelta += readDelta
            totalWriteDelta += writeDelta
            guard readDelta > 0 || writeDelta > 0 else { continue }

            let bundlePath = bundlePathForPID(pid)
            let displayName = bundlePath.flatMap { displayNameForBundle(path: $0) } ?? usage.name
            stats.append(
                ProcessDiskStat(
                    pid: Int(pid),
                    name: displayName,
                    readBytesPerSecond: Double(readDelta) / deltaTime,
                    writeBytesPerSecond: Double(writeDelta) / deltaTime,
                    bundlePath: bundlePath
                )
            )
        }

        let processes = stats.sorted {
            ($0.readBytesPerSecond + $0.writeBytesPerSecond) > ($1.readBytesPerSecond + $1.writeBytesPerSecond)
        }
        .prefix(limit)
        .map { $0 }

        return (
            readBytesPerSecond: Double(totalReadDelta) / deltaTime,
            writeBytesPerSecond: Double(totalWriteDelta) / deltaTime,
            processes: processes
        )
    }

    private func currentUsageByPID() -> [pid_t: Usage] {
        let size = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard size > 0 else { return [:] }

        let count = Int(size) / MemoryLayout<pid_t>.size
        var pids = [pid_t](repeating: 0, count: count)
        let actualSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, size)
        guard actualSize > 0 else { return [:] }

        let actualCount = Int(actualSize) / MemoryLayout<pid_t>.size
        var usageByPID: [pid_t: Usage] = [:]
        var nameBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))

        for index in 0..<actualCount {
            let pid = pids[index]
            if pid == 0 { continue }

            var info = rusage_info_v4()
            let result = withUnsafeMutablePointer(to: &info) { ptr -> Int32 in
                let raw = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: rusage_info_t?.self)
                return proc_pid_rusage(pid, RUSAGE_INFO_V4, raw)
            }
            if result != 0 { continue }

            let nameLength = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            let rawName = nameLength > 0 ? String(cString: nameBuffer) : ""
            let name = sanitizeName(rawName)
            if name.isEmpty { continue }

            usageByPID[pid] = Usage(
                name: name,
                readBytes: UInt64(info.ri_diskio_bytesread),
                writeBytes: UInt64(info.ri_diskio_byteswritten)
            )
        }

        return usageByPID
    }

    private func sanitizeName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("/") {
            return URL(fileURLWithPath: trimmed).lastPathComponent
        }
        return trimmed
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
        return (try? Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ??
            (try? Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String)
    }

    private struct Usage {
        let name: String
        let readBytes: UInt64
        let writeBytes: UInt64
    }
}
