import Foundation

final class NetworkSampler {
    private var previousInBytes: UInt64 = 0
    private var previousOutBytes: UInt64 = 0
    private var previousTimestamp: Date?

    func sampleDetailed() -> NetworkDetail? {
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var addrs: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&addrs) == 0, let first = addrs else { return nil }
        defer { freeifaddrs(addrs) }

        var pointer = first
        while true {
            let interface = pointer.pointee
            let flags = Int32(interface.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0

            if isUp && !isLoopback, let data = interface.ifa_data {
                let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                totalIn += UInt64(networkData.ifi_ibytes)
                totalOut += UInt64(networkData.ifi_obytes)
            }

            if let next = interface.ifa_next {
                pointer = next
            } else {
                break
            }
        }

        let now = Date()
        guard let previous = previousTimestamp else {
            previousTimestamp = now
            previousInBytes = totalIn
            previousOutBytes = totalOut
            return NetworkDetail(downKBps: 0, upKBps: 0)
        }

        let deltaIn = totalIn >= previousInBytes ? (totalIn - previousInBytes) : 0
        let deltaOut = totalOut >= previousOutBytes ? (totalOut - previousOutBytes) : 0
        let deltaTime = now.timeIntervalSince(previous)
        previousTimestamp = now
        previousInBytes = totalIn
        previousOutBytes = totalOut

        guard deltaTime > 0 else { return nil }
        let downKBps = (Double(deltaIn) / 1024.0) / deltaTime
        let upKBps = (Double(deltaOut) / 1024.0) / deltaTime
        return NetworkDetail(downKBps: downKBps, upKBps: upKBps)
    }

    func sample() -> Double? {
        sampleDetailed()?.totalKBps
    }
}

final class NetworkProcessSampler {
    func sampleTop(limit: Int) -> [ProcessNetStat] {
        let output = runNettop()
        guard !output.isEmpty else { return [] }
        let lines = output.split(separator: "\n").map(String.init)
        let trimmed = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard trimmed.count >= 3 else { return [] }

        guard let headerLineIndex = trimmed.firstIndex(where: { line in
            line.contains(",") && (line.lowercased().contains("pid") || line.lowercased().contains("bytes") || line.lowercased().contains("process"))
        }) else {
            return []
        }

        let header = parseCSVLine(trimmed[headerLineIndex]).map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        var headerIndex: [String: Int] = [:]
        for (idx, name) in header.enumerated() {
            guard !name.isEmpty else { continue }
            if headerIndex[name] == nil {
                headerIndex[name] = idx
            }
        }

        var nameIndex = firstIndex(in: headerIndex, keys: ["process", "proc", "comm", "name"])
        let timeIndex = firstIndex(in: headerIndex, keys: ["time"])
        let pidIndex = firstIndex(in: headerIndex, keys: ["pid"])
        let inIndex = firstIndex(in: headerIndex, keys: ["bytes_in", "rxbytes", "rbytes", "inbytes", "rx_bytes", "bytesin"])
        let outIndex = firstIndex(in: headerIndex, keys: ["bytes_out", "txbytes", "tbytes", "outbytes", "tx_bytes", "bytesout"])

        if nameIndex == nil, header.count > 1 {
            // nettop CSV often leaves the process column unnamed (empty header after time)
            nameIndex = 1
        }

        guard let nameIndex, let inIndex, let outIndex, let timeIndex else { return [] }

        var perProcess: [String: [Double: (inBytes: Double, outBytes: Double)]] = [:]

        for line in trimmed.dropFirst(headerLineIndex + 1) {
            let cols = parseCSVLine(line)
            guard cols.count > max(timeIndex, max(nameIndex, max(inIndex, outIndex))) else { continue }

            let timeString = cols[timeIndex]
            guard let timeSeconds = parseTimeSeconds(timeString) else { continue }

            let rawName = cols[nameIndex]
            let pid = pidIndex.flatMap { Int(cols[$0]) } ?? pidFromName(rawName)
            let name = sanitizeName(rawName)
            let inBytes = Double(cols[inIndex]) ?? 0
            let outBytes = Double(cols[outIndex]) ?? 0

            if name.isEmpty { continue }

            let key = pid.map { "\(name)#\($0)" } ?? name
            var byTime = perProcess[key] ?? [:]
            let current = byTime[timeSeconds] ?? (0, 0)
            byTime[timeSeconds] = (current.inBytes + inBytes, current.outBytes + outBytes)
            perProcess[key] = byTime
        }

        var stats: [ProcessNetStat] = []
        for (key, timeMap) in perProcess {
            let times = timeMap.keys.sorted()
            guard times.count >= 2 else { continue }
            let t1 = times[times.count - 2]
            let t2 = times[times.count - 1]
            let deltaTime = t2 - t1
            guard deltaTime > 0 else { continue }

            let v1 = timeMap[t1] ?? (0, 0)
            let v2 = timeMap[t2] ?? (0, 0)
            let deltaIn = max(0, v2.inBytes - v1.inBytes)
            let deltaOut = max(0, v2.outBytes - v1.outBytes)

            let downKBps = (deltaIn / 1024.0) / deltaTime
            let upKBps = (deltaOut / 1024.0) / deltaTime

            let pid = extractPid(from: key)
            let name = key.components(separatedBy: "#").first ?? key
            let bundlePath = pid.flatMap { bundlePathForPID(pid_t($0)) }
            let displayName = bundlePath.flatMap { displayNameForBundle(path: $0) } ?? name

            stats.append(ProcessNetStat(
                pid: pid,
                name: displayName,
                downKBps: downKBps,
                upKBps: upKBps,
                bundlePath: bundlePath
            ))
        }

        return stats.sorted { ($0.downKBps + $0.upKBps) > ($1.downKBps + $1.upKBps) }
            .prefix(limit)
            .map { $0 }
    }

    private func runNettop() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        process.arguments = ["-P", "-L", "2", "-x", "-n", "-t", "external"]

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

    private func sanitizeName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let pid = pidFromName(trimmed) {
            let base = trimmed.split(separator: ".").dropLast().joined(separator: ".")
            if !base.isEmpty { return base }
            return trimmed.replacingOccurrences(of: ".\(pid)", with: "")
        }
        if trimmed.contains("/") {
            return URL(fileURLWithPath: trimmed).lastPathComponent
        }
        return trimmed
    }

    private func pidFromName(_ raw: String) -> Int? {
        let parts = raw.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".")
        guard let last = parts.last, parts.count >= 2 else { return nil }
        return Int(last)
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

    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
                continue
            }
            if char == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)
        return result
    }

    private func firstIndex(in header: [String: Int], keys: [String]) -> Int? {
        for key in keys {
            if let index = header[key] { return index }
        }
        return nil
    }

    private func parseTimeSeconds(_ text: String) -> Double? {
        let parts = text.split(separator: ":")
        guard parts.count == 3 else { return nil }
        let h = Double(parts[0]) ?? 0
        let m = Double(parts[1]) ?? 0
        let s = Double(parts[2]) ?? 0
        return h * 3600 + m * 60 + s
    }

    private func extractPid(from key: String) -> Int? {
        let parts = key.split(separator: "#")
        guard parts.count == 2 else { return nil }
        return Int(parts[1])
    }
}
