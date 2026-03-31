import Foundation

actor ProcessMetricsWorker {
    private let diskProcessSampler = DiskProcessSampler()
    private let networkProcessSampler = NetworkProcessSampler()
    private let memoryProcessSampler = MemoryProcessSampler()
    private let significantEnergySampler = SignificantEnergySampler()

    func sampleDisk(limit: Int) -> (readBytesPerSecond: Double, writeBytesPerSecond: Double, processes: [ProcessDiskStat])? {
        diskProcessSampler.sample(limit: limit)
    }

    func sampleNetwork(limit: Int) -> [ProcessNetStat] {
        networkProcessSampler.sampleTop(limit: limit)
    }

    func sampleMemory(limit: Int) -> [ProcessMemStat] {
        memoryProcessSampler.sampleTop(limit: limit)
    }

    func sampleSignificantEnergy() -> SignificantEnergyApp? {
        significantEnergySampler.sampleTopApp()
    }
}

actor DiskProcessMetricsWorker {
    private let sampler = DiskProcessSampler()

    func sample(limit: Int) -> (readBytesPerSecond: Double, writeBytesPerSecond: Double, processes: [ProcessDiskStat])? {
        sampler.sample(limit: limit)
    }
}

actor NetworkProcessMetricsWorker {
    private let sampler = NetworkProcessSampler()

    func sample(limit: Int) -> [ProcessNetStat] {
        sampler.sampleTop(limit: limit)
    }
}

actor MemoryProcessMetricsWorker {
    private let sampler = MemoryProcessSampler()

    func sample(limit: Int) -> [ProcessMemStat] {
        sampler.sampleTop(limit: limit)
    }
}

actor SignificantEnergyMetricsWorker {
    private let sampler = SignificantEnergySampler()

    func sample() -> SignificantEnergyApp? {
        sampler.sampleTopApp()
    }
}

@MainActor
final class MetricsStore: ObservableObject {
    private let retention: TimeInterval = 7 * 24 * 60 * 60
    private let sampleInterval: TimeInterval = 2

    private let cpuSampler = CPUSampler()
    private let memorySampler = MemorySampler()
    private let diskSampler = DiskSampler()
    private let networkSampler = NetworkSampler()
    private let cpuTemperatureSampler = CPUTemperatureSampler()
    private let batterySampler = BatterySampler()
    private let diskProcessWorker = DiskProcessMetricsWorker()
    private let networkProcessWorker = NetworkProcessMetricsWorker()
    private let memoryProcessWorker = MemoryProcessMetricsWorker()
    private let significantEnergyWorker = SignificantEnergyMetricsWorker()

    private var task: Task<Void, Never>?
    private var seriesByType: [MetricType: RollingSeries] = [:]
    private var isRefreshingNetworkProcesses = false
    private var isRefreshingMemoryProcesses = false
    private var isRefreshingSignificantEnergy = false

    @Published private(set) var latest: [MetricType: MetricSample] = [:]
    @Published private(set) var cpuDetail: CPUDetail?
    @Published private(set) var cpuTemperatureDetail: CPUTemperatureDetail?
    @Published private(set) var memoryDetail: MemoryDetail?
    @Published private(set) var diskVolumes: [DiskVolumeStat] = []
    @Published private(set) var diskDetail: DiskDetail?
    @Published private(set) var diskProcesses: [ProcessDiskStat] = []
    @Published private(set) var networkDetail: NetworkDetail?
    @Published private(set) var batteryDetail: BatteryDetail?
    @Published private(set) var significantEnergyApp: SignificantEnergyApp?
    @Published private(set) var ipInfo: IPInfo = IPInfo()
    @Published private(set) var networkProcesses: [ProcessNetStat] = []
    @Published private(set) var memoryProcesses: [ProcessMemStat] = []
    @Published private(set) var sampleTick: Date = .distantPast

    var isCPUTemperatureSupported: Bool { cpuTemperatureSampler.isSupported || cpuTemperatureDetail != nil }

    private var lastPublicIPFetch: Date?
    private var lastLocalIPFetch: Date?
    private var lastProcessFetch: Date?
    private var lastMemoryProcessFetch: Date?
    private var lastSignificantEnergyFetch: Date?
    private var lastPersistedAt: Date?
    private var sampleCount: Int = 0

    init() {
        MetricType.allCases.forEach { type in
            seriesByType[type] = RollingSeries(retention: retention)
        }
        loadPersistedSamples()
        start()
    }

    func start() {
        guard task == nil else { return }
        debugLog("MetricsStore start requested")
        task = Task.detached(priority: .utility) { [weak self] in
            await MainActor.run {
                debugLog("MetricsStore sampling loop started")
            }
            while !Task.isCancelled {
                guard let self else { return }
                let startedAt = Date()
                await self.sampleOnce()
                let elapsed = Date().timeIntervalSince(startedAt)
                let remaining = max(self.sampleInterval - elapsed, 0.1)
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func latestValue(_ type: MetricType) -> Double? {
        latest[type]?.value
    }

    func series(_ type: MetricType) -> [MetricSample] {
        seriesByType[type]?.samples ?? []
    }

    private func sampleOnce() async {
        let timestamp = Date()
        sampleCount += 1
        let shouldUpdateNetworkProcesses = shouldRefreshNetworkProcesses(now: timestamp)
        let shouldUpdateMemoryProcesses = shouldRefreshMemoryProcesses(now: timestamp)
        let shouldUpdateSignificantEnergy = shouldRefreshSignificantEnergy(now: timestamp)

        async let diskProcessResult = diskProcessWorker.sample(limit: 5)

        if let cpu = cpuSampler.sampleDetailed() {
            cpuDetail = cpu
            append(.cpuUsage, value: cpu.overall, timestamp: timestamp)
            append(.cpuUser, value: cpu.user, timestamp: timestamp)
            append(.cpuSystem, value: cpu.system, timestamp: timestamp)
        }

        if let memory = memorySampler.sampleDetailed() {
            memoryDetail = memory
            append(.memoryUsedPercent, value: memory.usedPercent, timestamp: timestamp)
            let freePercent = memory.totalBytes > 0 ? (Double(memory.freeBytes) / Double(memory.totalBytes)) * 100 : 0
            append(.memoryFreePercent, value: freePercent, timestamp: timestamp)
            append(.memoryAppBytes, value: Double(memory.appBytes), timestamp: timestamp)
            append(.memoryWiredBytes, value: Double(memory.wiredBytes), timestamp: timestamp)
            append(.memoryCompressedBytes, value: Double(memory.compressedBytes), timestamp: timestamp)
            append(.memoryFreeBytes, value: Double(memory.freeBytes), timestamp: timestamp)
        }

        if let disk = diskSampler.sample() {
            append(.diskUsedPercent, value: disk, timestamp: timestamp)
        }
        let volumes = diskSampler.sampleDetailed()
        diskVolumes = volumes
        if let sample = await diskProcessResult {
            append(.diskReadBytesPerSecond, value: sample.readBytesPerSecond, timestamp: timestamp)
            append(.diskWriteBytesPerSecond, value: sample.writeBytesPerSecond, timestamp: timestamp)
            diskProcesses = sample.processes
            if let primaryVolume = preferredDiskVolume(from: volumes) {
                let usedPercent = primaryVolume.totalBytes > 0 ? (Double(primaryVolume.usedBytes) / Double(primaryVolume.totalBytes)) * 100 : 0
                let normalizedVolume = DiskVolumeStat(
                    name: primaryVolume.name,
                    mountPath: primaryVolume.mountPath,
                    usedPercent: usedPercent,
                    totalBytes: primaryVolume.totalBytes,
                    usedBytes: primaryVolume.usedBytes,
                    purgeableBytes: primaryVolume.purgeableBytes,
                    freeBytes: primaryVolume.freeBytes
                )
                diskDetail = DiskDetail(
                    volume: normalizedVolume,
                    readBytesPerSecond: sample.readBytesPerSecond,
                    writeBytesPerSecond: sample.writeBytesPerSecond
                )
            }
        } else if let primaryVolume = preferredDiskVolume(from: volumes) {
            let usedPercent = primaryVolume.totalBytes > 0 ? (Double(primaryVolume.usedBytes) / Double(primaryVolume.totalBytes)) * 100 : 0
            let normalizedVolume = DiskVolumeStat(
                name: primaryVolume.name,
                mountPath: primaryVolume.mountPath,
                usedPercent: usedPercent,
                totalBytes: primaryVolume.totalBytes,
                usedBytes: primaryVolume.usedBytes,
                purgeableBytes: primaryVolume.purgeableBytes,
                freeBytes: primaryVolume.freeBytes
            )
            diskDetail = DiskDetail(
                volume: normalizedVolume,
                readBytesPerSecond: latestValue(.diskReadBytesPerSecond) ?? 0,
                writeBytesPerSecond: latestValue(.diskWriteBytesPerSecond) ?? 0
            )
        }

        if let network = networkSampler.sampleDetailed() {
            networkDetail = network
            append(.networkTotalKBps, value: network.totalKBps, timestamp: timestamp)
            append(.networkDownKBps, value: network.downKBps, timestamp: timestamp)
            append(.networkUpKBps, value: network.upKBps, timestamp: timestamp)
        }

        updateLocalIPsIfNeeded(now: timestamp)
        updatePublicIPsIfNeeded(now: timestamp)

        if let temperatureDetail = await cpuTemperatureSampler.sampleDetailed() {
            cpuTemperatureDetail = temperatureDetail
            if let overall = temperatureDetail.overall {
                append(.cpuTemperature, value: overall, timestamp: timestamp)
            }
        }

        if let detail = batterySampler.sampleDetailed() {
            batteryDetail = detail
            append(.batteryPercent, value: detail.percent, timestamp: timestamp)
        }

        refreshNetworkProcessesIfNeeded(shouldRefresh: shouldUpdateNetworkProcesses)
        refreshMemoryProcessesIfNeeded(shouldRefresh: shouldUpdateMemoryProcesses)
        refreshSignificantEnergyIfNeeded(shouldRefresh: shouldUpdateSignificantEnergy)

        if sampleCount <= 5 || sampleCount % 10 == 0 {
            debugLog(
                "sample #\(sampleCount) cpu=\(formatDebug(latestValue(.cpuUsage))) mem=\(formatDebug(latestValue(.memoryUsedPercent))) net=\(formatDebug(latestValue(.networkTotalKBps))) temp=\(formatDebug(latestValue(.cpuTemperature))) fans=\(cpuTemperatureDetail?.fans.count ?? 0)"
            )
        }

        sampleTick = timestamp
        persistIfNeeded(now: timestamp)
    }

    private func append(_ type: MetricType, value: Double, timestamp: Date) {
        let sample = MetricSample(timestamp: timestamp, value: value)
        var updatedLatest = latest
        updatedLatest[type] = sample
        latest = updatedLatest
        seriesByType[type]?.append(sample)
    }

    private func formatDebug(_ value: Double?) -> String {
        guard let value else { return "nil" }
        return String(format: "%.1f", value)
    }

    private func preferredDiskVolume(from volumes: [DiskVolumeStat]) -> DiskVolumeStat? {
        volumes.first(where: { $0.mountPath == "/System/Volumes/Data" })
        ?? volumes.first(where: { $0.name == "Data" || $0.name == "Macintosh HD - Data" })
        ?? volumes.first(where: { $0.name == "Macintosh HD" })
        ?? volumes.max(by: { $0.totalBytes < $1.totalBytes })
    }

    private func updateLocalIPsIfNeeded(now: Date) {
        if let last = lastLocalIPFetch, now.timeIntervalSince(last) < 5 {
            return
        }
        lastLocalIPFetch = now
        ipInfo.localIPv4 = localIPAddresses(family: AF_INET)
        ipInfo.localIPv6 = localIPAddresses(family: AF_INET6)
    }

    private func updatePublicIPsIfNeeded(now: Date) {
        if let last = lastPublicIPFetch, now.timeIntervalSince(last) < 300 {
            return
        }
        lastPublicIPFetch = now
        Task { [weak self] in
            async let v4 = Self.fetchPublicIP(url: URL(string: "https://api.ipify.org")!)
            async let v6 = Self.fetchPublicIP(url: URL(string: "https://api64.ipify.org")!)
            let (ipv4, ipv6) = await (v4, v6)
            guard let self else { return }
            self.ipInfo.publicIPv4 = ipv4
            self.ipInfo.publicIPv6 = ipv6
        }
    }

    private func shouldRefreshNetworkProcesses(now: Date) -> Bool {
        if let last = lastProcessFetch, now.timeIntervalSince(last) < 2 {
            return false
        }
        lastProcessFetch = now
        return true
    }

    private func shouldRefreshMemoryProcesses(now: Date) -> Bool {
        if let last = lastMemoryProcessFetch, now.timeIntervalSince(last) < 2 {
            return false
        }
        lastMemoryProcessFetch = now
        return true
    }

    private func shouldRefreshSignificantEnergy(now: Date) -> Bool {
        if let last = lastSignificantEnergyFetch, now.timeIntervalSince(last) < 10 {
            return false
        }
        lastSignificantEnergyFetch = now
        return true
    }

    private func refreshNetworkProcessesIfNeeded(shouldRefresh: Bool) {
        guard shouldRefresh, !isRefreshingNetworkProcesses else { return }
        isRefreshingNetworkProcesses = true
        let worker = networkProcessWorker

        Task(priority: .utility) { [weak self] in
            let stats = await worker.sample(limit: 5)
            guard let self else { return }
            if !stats.isEmpty {
                self.networkProcesses = stats
            }
            self.isRefreshingNetworkProcesses = false
        }
    }

    private func refreshMemoryProcessesIfNeeded(shouldRefresh: Bool) {
        guard shouldRefresh, !isRefreshingMemoryProcesses else { return }
        isRefreshingMemoryProcesses = true
        let worker = memoryProcessWorker

        Task(priority: .utility) { [weak self] in
            let stats = await worker.sample(limit: 5)
            guard let self else { return }
            if !stats.isEmpty {
                self.memoryProcesses = stats
            }
            self.isRefreshingMemoryProcesses = false
        }
    }

    private func refreshSignificantEnergyIfNeeded(shouldRefresh: Bool) {
        guard shouldRefresh, !isRefreshingSignificantEnergy else { return }
        isRefreshingSignificantEnergy = true
        let worker = significantEnergyWorker

        Task(priority: .utility) { [weak self] in
            let app = await worker.sample()
            guard let self else { return }
            self.significantEnergyApp = app
            self.isRefreshingSignificantEnergy = false
        }
    }

    private func localIPAddresses(family: Int32) -> [String] {
        var results: [String] = []
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0, let first = addrs else { return results }
        defer { freeifaddrs(addrs) }

        var pointer = first
        while true {
            let interface = pointer.pointee
            let flags = Int32(interface.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0

            if isUp && !isLoopback, let addr = interface.ifa_addr, addr.pointee.sa_family == UInt8(family) {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let result = getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                if result == 0 {
                    let ip = String(cString: host)
                    if family == AF_INET6, ip.hasPrefix("fe80") == true {
                        // Skip link-local IPv6
                    } else {
                        results.append(ip)
                    }
                }
            }

            if let next = interface.ifa_next {
                pointer = next
            } else {
                break
            }
        }
        return results
    }

    private static func fetchPublicIP(url: URL) async -> String? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }

    private func persistIfNeeded(now: Date) {
        if let last = lastPersistedAt, now.timeIntervalSince(last) < 30 {
            return
        }
        lastPersistedAt = now
        savePersistedSamples()
    }

    private func savePersistedSamples() {
        let cutoff = Date().addingTimeInterval(-retention)
        var payload: [String: [PersistedSample]] = [:]

        for type in MetricType.allCases {
            let samples = seriesByType[type]?.samples ?? []
            let filtered = samples.filter { $0.timestamp >= cutoff }
            payload[type.rawValue] = filtered.map { PersistedSample(timestamp: $0.timestamp, value: $0.value) }
        }

        let store = PersistedStore(savedAt: Date(), samplesByType: payload)
        do {
            let data = try JSONEncoder().encode(store)
            try data.write(to: persistenceURL(), options: .atomic)
        } catch {
            // ignore write failures
        }
    }

    private func loadPersistedSamples() {
        do {
            let data = try Data(contentsOf: persistenceURL())
            let store = try JSONDecoder().decode(PersistedStore.self, from: data)
            let cutoff = Date().addingTimeInterval(-retention)
            var restoredLatestTimestamp: Date?

            for (key, samples) in store.samplesByType {
                guard let type = MetricType(rawValue: key) else { continue }
                let series = seriesByType[type] ?? RollingSeries(retention: retention)
                samples
                    .filter { $0.timestamp >= cutoff }
                    .sorted { $0.timestamp < $1.timestamp }
                    .forEach { persisted in
                        let sample = MetricSample(timestamp: persisted.timestamp, value: persisted.value)
                        series.append(sample)
                        latest[type] = sample
                        if restoredLatestTimestamp == nil || sample.timestamp > restoredLatestTimestamp! {
                            restoredLatestTimestamp = sample.timestamp
                        }
                    }
                seriesByType[type] = series
            }

            if let restoredLatestTimestamp {
                sampleTick = restoredLatestTimestamp
            }
        } catch {
            // no persisted data yet
        }
    }

    private func clearPersistedSamples() {
        do {
            let url = try persistenceURL()
            try? FileManager.default.removeItem(at: url)
        } catch {
            // ignore
        }
        latest.removeAll()
        MetricType.allCases.forEach { type in
            seriesByType[type] = RollingSeries(retention: retention)
        }
    }

    private func persistenceURL() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let folder = base.appendingPathComponent("iStatus", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("metrics.json")
    }
}

private struct PersistedStore: Codable {
    let savedAt: Date
    let samplesByType: [String: [PersistedSample]]
}

private struct PersistedSample: Codable {
    let timestamp: Date
    let value: Double
}
