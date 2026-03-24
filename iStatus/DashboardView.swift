import SwiftUI
import AppKit

enum DashboardSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case cpu = "CPU"
    case memory = "Memory"
    case disk = "Disk"
    case network = "Network"
    case gpu = "GPU"
    case battery = "Battery"

    var id: String { rawValue }
}

enum TimeRange: String, CaseIterable, Identifiable {
    case min10 = "10m"
    case hour1 = "1h"
    case hour6 = "6h"
    case hour12 = "12h"
    case hour24 = "24h"

    var id: String { rawValue }

    var duration: TimeInterval {
        switch self {
        case .min10: return 10 * 60
        case .hour1: return 60 * 60
        case .hour6: return 6 * 60 * 60
        case .hour12: return 12 * 60 * 60
        case .hour24: return 24 * 60 * 60
        }
    }

    var bucketInterval: TimeInterval {
        switch self {
        case .min10: return 5
        case .hour1: return 30
        case .hour6: return 3 * 60
        case .hour12: return 6 * 60
        case .hour24: return 12 * 60
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var metricsStore: MetricsStore
    @State private var selectedSection: DashboardSection = .overview
    @State private var selectedRange: TimeRange = .min10
    @State private var refreshTick = Date()

    var body: some View {
        let _ = refreshTick
        HStack(spacing: 0) {
            sidebar
            Divider()
            content
        }
        .background(LinearGradient(colors: [Color("BackgroundTop"), Color("BackgroundBottom")], startPoint: .top, endPoint: .bottom))
        .onReceive(metricsStore.$sampleTick) { tick in
            refreshTick = tick
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("iStatus")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            ForEach(DashboardSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    HStack {
                        Text(section.rawValue)
                            .font(.system(.callout, design: .rounded))
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(selectedSection == section ? Color.white.opacity(0.12) : Color.clear)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            }

            Spacer()
        }
        .padding(18)
        .frame(width: 180)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                quickStats

                if selectedSection == .overview {
                    overviewGrid
                } else {
                    sectionDetail
                }
            }
            .padding(22)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(selectedSection.rawValue)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Rolling history with 2s sampling")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            TimeRangePicker(selected: $selectedRange)
        }
    }

    private var quickStats: some View {
        HStack(spacing: 12) {
            StatPill(title: "CPU", value: metricsStore.latestValue(.cpuUsage), unit: "%", accent: .pink)
            StatPill(title: "MEM", value: metricsStore.latestValue(.memoryUsedPercent), unit: "%", accent: .cyan)
            StatPill(
                title: "NET",
                value: metricsStore.latestValue(.networkTotalKBps),
                unit: "KB/s",
                accent: .mint,
                formattedValueOverride: formatNetworkRate(kilobytesPerSecond: metricsStore.latestValue(.networkTotalKBps))
            )
            StatPill(title: "GPU", value: metricsStore.latestValue(.gpuUsage), unit: "%", accent: .orange)
            StatPill(title: "BAT", value: metricsStore.latestValue(.batteryPercent), unit: "%", accent: .green)
        }
    }

    private var overviewGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 18)], spacing: 18) {
            cpuCard
            memoryCard
            diskCard
            networkCard
            gpuCard
            batteryCard
        }
    }

    private var sectionDetail: some View {
        Group {
            switch selectedSection {
            case .overview:
                EmptyView()
            case .cpu:
                cpuCard
            case .memory:
                memoryCard
            case .disk:
                diskCard
            case .network:
                networkCard
            case .gpu:
                gpuCard
            case .battery:
                batteryCard
            }
        }
    }

    private var cpuCard: some View {
        MetricCard(
            title: "CPU",
            value: metricsStore.latestValue(.cpuUsage),
            unit: "%",
            series: filteredSeries(.cpuUsage),
            accent: .pink,
            range: selectedRange.duration,
            bucketInterval: selectedRange.bucketInterval
        ) {
            SubMetricChartRow(
                title: "User",
                value: metricsStore.latestValue(.cpuUser),
                unit: "%",
                series: filteredSeries(.cpuUser),
                accent: .pink,
                range: selectedRange.duration,
                bucketInterval: selectedRange.bucketInterval
            )
            SubMetricChartRow(
                title: "System",
                value: metricsStore.latestValue(.cpuSystem),
                unit: "%",
                series: filteredSeries(.cpuSystem),
                accent: .pink,
                range: selectedRange.duration,
                bucketInterval: selectedRange.bucketInterval
            )

            if let detail = metricsStore.cpuDetail {
                PerCoreGrid(values: detail.perCore)
            }
        }
    }

    private var memoryCard: some View {
        MemoryCardView(
            range: selectedRange.duration,
            bucketInterval: selectedRange.bucketInterval,
            appSeries: filteredSeries(.memoryAppBytes),
            wiredSeries: filteredSeries(.memoryWiredBytes),
            compressedSeries: filteredSeries(.memoryCompressedBytes)
        )
    }

    private var diskCard: some View {
        DiskCardView(
            range: selectedRange.duration,
            bucketInterval: selectedRange.bucketInterval,
            readSeries: filteredSeries(.diskReadBytesPerSecond),
            writeSeries: filteredSeries(.diskWriteBytesPerSecond)
        )
    }

    private var networkCard: some View {
        MetricCard(
            title: "Network",
            value: metricsStore.latestValue(.networkTotalKBps),
            unit: "KB/s",
            formattedValueOverride: formatNetworkRate(kilobytesPerSecond: metricsStore.latestValue(.networkTotalKBps)),
            series: filteredSeries(.networkTotalKBps),
            accent: .mint,
            range: selectedRange.duration,
            bucketInterval: selectedRange.bucketInterval
        ) {
            DualBarChartView(
                upSamples: filteredSeries(.networkUpKBps),
                downSamples: filteredSeries(.networkDownKBps),
                upColor: .pink,
                downColor: .blue,
                range: selectedRange.duration,
                bucketInterval: selectedRange.bucketInterval
            )
            .frame(height: 100)

            SubMetricChartRow(
                title: "Down",
                value: metricsStore.latestValue(.networkDownKBps),
                unit: "KB/s",
                formattedValueOverride: formatNetworkRate(kilobytesPerSecond: metricsStore.latestValue(.networkDownKBps)),
                series: filteredSeries(.networkDownKBps),
                accent: .mint,
                range: selectedRange.duration,
                bucketInterval: selectedRange.bucketInterval
            )
            SubMetricChartRow(
                title: "Up",
                value: metricsStore.latestValue(.networkUpKBps),
                unit: "KB/s",
                formattedValueOverride: formatNetworkRate(kilobytesPerSecond: metricsStore.latestValue(.networkUpKBps)),
                series: filteredSeries(.networkUpKBps),
                accent: .mint,
                range: selectedRange.duration,
                bucketInterval: selectedRange.bucketInterval
            )

            SectionHeader(title: "PUBLIC IP ADDRESSES")
            IPListRow(text: metricsStore.ipInfo.publicIPv4 ?? "--")
            if let ipv6 = metricsStore.ipInfo.publicIPv6, !ipv6.isEmpty {
                IPListRow(text: ipv6)
            }

            SectionHeader(title: "IP ADDRESSES")
            ForEach(metricsStore.ipInfo.localIPv4, id: \.self) { ip in
                IPListRow(text: ip)
            }

            SectionHeader(title: "PROCESSES")
            ProcessHeaderRow()
            ForEach(metricsStore.networkProcesses) { proc in
                ProcessRow(stat: proc)
            }
        }
    }

    private var gpuCard: some View {
        MetricCard(
            title: "GPU",
            value: metricsStore.latestValue(.gpuUsage),
            unit: "%",
            series: filteredSeries(.gpuUsage),
            accent: .orange,
            range: selectedRange.duration,
            bucketInterval: selectedRange.bucketInterval,
            note: metricsStore.isGPUSupported ? nil : "GPU usage not available"
        ) {
            EmptyView()
        }
    }

    private var batteryCard: some View {
        BatteryCardView(
            range: selectedRange.duration,
            bucketInterval: selectedRange.bucketInterval,
            batterySeries: filteredSeries(.batteryPercent)
        )
    }

    private func filteredSeries(_ type: MetricType) -> [MetricSample] {
        _ = refreshTick
        let cutoff = Date().addingTimeInterval(-selectedRange.duration)
        return metricsStore.series(type).filter { $0.timestamp >= cutoff }
    }

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }

    private func formatBytes(_ value: UInt64) -> String {
        let gb = Double(value) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.1fGB", gb)
        }
        let mb = Double(value) / 1_048_576
        return String(format: "%.0fMB", mb)
    }
}

struct StatPill: View {
    let title: String
    let value: Double?
    let unit: String
    let accent: Color
    var formattedValueOverride: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(accent)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            Text(formattedValue)
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var formattedValue: String {
        if let formattedValueOverride {
            return formattedValueOverride
        }
        guard let value else { return "--" }
        return String(format: "%.0f%@", value, unit)
    }
}

struct TimeRangePicker: View {
    @Binding var selected: TimeRange

    var body: some View {
        HStack(spacing: 6) {
            ForEach(TimeRange.allCases) { range in
                Button {
                    selected = range
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(selected == range ? Color.black : Color.white)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(selected == range ? Color.white : Color.white.opacity(0.12))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(Color.white.opacity(0.06))
        .cornerRadius(10)
    }
}

struct MetricCard<Footer: View>: View {
    let title: String
    let value: Double?
    let unit: String
    var formattedValueOverride: String? = nil
    let series: [MetricSample]
    let accent: Color
    let range: TimeInterval
    let bucketInterval: TimeInterval
    var note: String? = nil
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(formattedValue)
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(accent)
            }

            MiniChartView(samples: series, accent: accent, range: range, bucketInterval: bucketInterval)
                .frame(height: 110)

            footer()

            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color("CardBackground"))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color("CardBorder"), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
        )
    }

    private var formattedValue: String {
        if let formattedValueOverride {
            return formattedValueOverride
        }
        guard let value else { return "--" }
        return String(format: "%.0f%@", value, unit)
    }
}

struct SubMetricChartRow: View {
    let title: String
    let value: Double?
    let unit: String
    var formattedValueOverride: String? = nil
    let series: [MetricSample]
    let accent: Color
    let range: TimeInterval
    let bucketInterval: TimeInterval

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Text(formattedValue)
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 56, alignment: .leading)
            MiniChartView(samples: series, accent: accent, range: range, bucketInterval: bucketInterval)
                .frame(height: 36)
        }
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
    }

    private var formattedValue: String {
        if let formattedValueOverride {
            return formattedValueOverride
        }
        guard let value else { return "--" }
        return String(format: "%.0f%@", value, unit)
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.7))
            .padding(.top, 6)
    }
}

struct IPListRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.callout, design: .rounded))
            .foregroundStyle(.white)
    }
}

struct ProcessHeaderRow: View {
    var body: some View {
        HStack {
            Text("Process")
            Spacer()
            Text("Down")
            Text("Up")
        }
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.7))
    }
}

struct ProcessRow: View {
    let stat: ProcessNetStat

    var body: some View {
        HStack {
            AppIconView(pid: stat.pid, fallbackName: stat.name, bundlePath: stat.bundlePath)
            Text(appDisplayName)
                .lineLimit(1)
            Spacer()
            Text(format(stat.downKBps))
            Text(format(stat.upKBps))
        }
        .font(.system(.callout, design: .rounded))
        .foregroundStyle(.white)
    }

    private var appDisplayName: String {
        if let pid = stat.pid, let app = NSRunningApplication(processIdentifier: pid_t(pid)), let name = app.localizedName {
            return name
        }
        return stat.name
    }

    private func format(_ value: Double) -> String {
        formatNetworkRate(kilobytesPerSecond: value)
    }
}

struct ProcessMemoryRow: View {
    let stat: ProcessMemStat

    var body: some View {
        HStack {
            AppIconView(pid: stat.pid, fallbackName: stat.name, bundlePath: stat.bundlePath)
            Text(appDisplayName)
                .lineLimit(1)
            Spacer()
            Text(formatBytes(stat.memoryBytes))
        }
        .font(.system(.callout, design: .rounded))
        .foregroundStyle(.white)
    }

    private var appDisplayName: String {
        if let pid = stat.pid, let app = NSRunningApplication(processIdentifier: pid_t(pid)), let name = app.localizedName {
            return name
        }
        return stat.name
    }

    private func formatBytes(_ value: UInt64) -> String {
        let gb = Double(value) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(value) / 1_048_576
        return String(format: "%.0f MB", mb)
    }
}

struct AppIconView: View {
    let pid: Int?
    let fallbackName: String
    var bundlePath: String? = nil

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .renderingMode(.original)
            .frame(width: 16, height: 16)
            .cornerRadius(3)
    }

    private var icon: NSImage {
        if let bundlePath {
            if bundlePath == Bundle.main.bundlePath {
                if let brandedIcon = NSImage(named: "iStatusBrand") {
                    brandedIcon.isTemplate = false
                    return brandedIcon
                }
                if let currentIcon = NSRunningApplication.current.icon {
                    currentIcon.isTemplate = false
                    return currentIcon
                }
                if let appIcon = NSApp.applicationIconImage {
                    appIcon.isTemplate = false
                    return appIcon
                }
            }
            let workspaceIcon = NSWorkspace.shared.icon(forFile: bundlePath)
            workspaceIcon.isTemplate = false
            return workspaceIcon
        }
        if let pid, let app = NSRunningApplication(processIdentifier: pid_t(pid)), let appIcon = app.icon {
            appIcon.isTemplate = false
            return appIcon
        }
        if let app = NSWorkspace.shared.runningApplications.first(where: { app in
            if let name = app.localizedName, name == fallbackName {
                return true
            }
            if let url = app.executableURL {
                return url.lastPathComponent == fallbackName
            }
            return false
        }), let appIcon = app.icon {
            appIcon.isTemplate = false
            return appIcon
        }
        let fallbackIcon = NSWorkspace.shared.icon(forFileType: "app")
        fallbackIcon.isTemplate = false
        return fallbackIcon
    }
}

struct DiskCardView: View {
    @EnvironmentObject private var metricsStore: MetricsStore
    let range: TimeInterval
    let bucketInterval: TimeInterval
    let readSeries: [MetricSample]
    let writeSeries: [MetricSample]

    private let readColor = Color.pink
    private let writeColor = Color.blue

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                if let detail = metricsStore.diskDetail {
                    DiskUsageRingView(volume: detail.volume)
                    DiskCapacityLegend(volume: detail.volume)
                } else {
                    placeholderPanel(title: "Disk usage")
                }
            }

            if let detail = metricsStore.diskDetail {
                DiskVolumeHeader(volume: detail.volume)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 24) {
                    DiskRateMetric(title: "Read", value: metricsStore.latestValue(.diskReadBytesPerSecond), color: readColor)
                    DiskRateMetric(title: "Write", value: metricsStore.latestValue(.diskWriteBytesPerSecond), color: writeColor)
                }

                DualBarChartView(
                    upSamples: readSeries,
                    downSamples: writeSeries,
                    upColor: readColor,
                    downColor: writeColor,
                    range: range,
                    bucketInterval: bucketInterval
                )
                .frame(height: 110)

                HStack {
                    Text("Read \(peakLabel(for: readSeries))")
                    Spacer()
                    Text("Write \(peakLabel(for: writeSeries))")
                }
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(14)

            SectionHeader(title: "PROCESSES")
            ProcessDiskHeaderRow()
            if metricsStore.diskProcesses.isEmpty {
                Text("Waiting for disk activity...")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            } else {
                ForEach(metricsStore.diskProcesses) { proc in
                    ProcessDiskRow(stat: proc)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color("CardBackground"))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color("CardBorder"), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
        )
    }

    private func placeholderPanel(title: String) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.05))
            .overlay(
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            )
            .frame(height: 120)
    }

    private func peakLabel(for series: [MetricSample]) -> String {
        formatTransferRate(series.map(\.value).max() ?? 0)
    }

    private func formatTransferRate(_ value: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .binary) + "/s"
    }
}

struct DiskVolumeHeader: View {
    let volume: DiskVolumeStat

    var body: some View {
        HStack(spacing: 12) {
            RingGaugeView(
                value: volume.usedPercent,
                label: "USED",
                colors: [.blue, .cyan, .blue],
                size: 86,
                lineWidth: 9,
                valueFontSize: 13
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(volume.name)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(formatBytes(volume.freeBytes)) available")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                Circle()
                    .fill(Color.pink)
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(Color.blue)
                    .frame(width: 12, height: 12)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.85), lineWidth: 1.2)
        )
        .cornerRadius(16)
    }

    private func formatBytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .binary)
    }
}

struct DiskUsageRingView: View {
    let volume: DiskVolumeStat

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 18)

            ForEach(segments.indices, id: \.self) { index in
                let segment = segments[index]
                Circle()
                    .trim(from: segment.start, to: segment.end)
                    .stroke(segment.color, style: StrokeStyle(lineWidth: 18, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
        }
        .padding(14)
        .frame(width: 200, height: 200)
        .background(Color.white.opacity(0.04))
        .cornerRadius(18)
    }

    private var segments: [(start: CGFloat, end: CGFloat, color: Color)] {
        let total = max(Double(volume.totalBytes), 1)
        let used = Double(volume.usedBytes) / total
        let purgeable = Double(volume.purgeableBytes) / total
        let free = Double(volume.freeBytes) / total

        let values = [
            (used, Color.blue),
            (purgeable, Color.pink),
            (free, Color.white.opacity(0.22))
        ]

        var start: CGFloat = 0
        return values.map { part, color in
            let end = start + CGFloat(part)
            defer { start = end }
            return (start, end, color)
        }
    }
}

struct DiskCapacityLegend: View {
    let volume: DiskVolumeStat

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DiskLegendRow(color: .blue, title: "Used", value: formatBytes(volume.usedBytes))
            DiskLegendRow(color: .pink, title: "Purgeable", value: formatBytes(volume.purgeableBytes))
            DiskLegendRow(color: Color.white.opacity(0.35), title: "Free", value: formatBytes(volume.freeBytes))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(18)
    }

    private func formatBytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .binary)
    }
}

struct DiskLegendRow: View {
    let color: Color
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }
}

struct DiskRateMetric: View {
    let title: String
    let value: Double?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(formatRate(value))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatRate(_ value: Double?) -> String {
        formatNetworkRate(bytesPerSecond: value)
    }
}

struct ProcessDiskHeaderRow: View {
    var body: some View {
        HStack {
            Text("Process")
            Spacer()
            Text("R")
                .frame(width: 72, alignment: .trailing)
            Text("W")
                .frame(width: 72, alignment: .trailing)
        }
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.7))
    }
}

struct ProcessDiskRow: View {
    let stat: ProcessDiskStat

    var body: some View {
        HStack {
            AppIconView(pid: stat.pid, fallbackName: stat.name, bundlePath: stat.bundlePath)
            Text(appDisplayName)
                .lineLimit(1)
            Spacer()
            Text(format(stat.readBytesPerSecond))
                .frame(width: 72, alignment: .trailing)
            Text(format(stat.writeBytesPerSecond))
                .frame(width: 72, alignment: .trailing)
        }
        .font(.system(.callout, design: .rounded))
        .foregroundStyle(.white)
    }

    private var appDisplayName: String {
        if let pid = stat.pid, let app = NSRunningApplication(processIdentifier: pid_t(pid)), let name = app.localizedName {
            return name
        }
        return stat.name
    }

    private func format(_ value: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .binary)
    }
}

struct BatteryCardView: View {
    @EnvironmentObject private var metricsStore: MetricsStore
    let range: TimeInterval
    let bucketInterval: TimeInterval
    let batterySeries: [MetricSample]

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 14) {
                BatteryStatSection(title: "POWER ADAPTER", rows: powerAdapterRows)
                BatteryStatSection(title: "BATTERY", rows: batteryRows)
                BatteryStatSection(title: "HEALTH", rows: healthRows)

                if let detail = metricsStore.batteryDetail, !detail.cellVoltages.isEmpty {
                    BatteryStatSection(
                        title: "CELLS",
                        rows: detail.cellVoltages.enumerated().map { index, voltage in
                            BatteryStatRow(title: "Cell \(index + 1)", value: formatVoltage(voltage))
                        }
                    )
                }
            }
            .frame(maxWidth: 320, alignment: .top)

            VStack(spacing: 14) {
                BatteryRingPanel(
                    percent: metricsStore.batteryDetail?.percent,
                    healthPercent: metricsStore.batteryDetail?.healthPercent
                )

                BatteryLevelPanel(
                    samples: batterySeries,
                    isCharging: metricsStore.batteryDetail?.isCharging ?? false,
                    isExternalPowerConnected: metricsStore.batteryDetail?.isExternalPowerConnected ?? false,
                    range: range,
                    bucketInterval: bucketInterval
                )

                BatteryModeRow(mode: batteryModeText)

                BatterySignificantEnergyRow(app: metricsStore.significantEnergyApp)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color("CardBackground"))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color("CardBorder"), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
        )
    }

    private var powerAdapterRows: [BatteryStatRow] {
        guard let detail = metricsStore.batteryDetail else { return [] }
        return [
            BatteryStatRow(title: "Power", value: formatWatts(detail.adapterPowerWatts))
        ]
    }

    private var batteryRows: [BatteryStatRow] {
        guard let detail = metricsStore.batteryDetail else { return [] }
        return [
            BatteryStatRow(title: "Power", value: formatWatts(detail.batteryPowerWatts)),
            BatteryStatRow(title: "Amperage", value: formatAmps(detail.amperageAmps)),
            BatteryStatRow(title: "Voltage", value: formatVoltage(detail.voltageVolts)),
            BatteryStatRow(title: "Temperature", value: formatTemperature(detail.temperatureCelsius))
        ]
    }

    private var healthRows: [BatteryStatRow] {
        guard let detail = metricsStore.batteryDetail else { return [] }
        return [
            BatteryStatRow(title: "Cycles", value: detail.cycleCount.map(String.init) ?? "--"),
            BatteryStatRow(title: "Condition", value: detail.condition ?? "--"),
            BatteryStatRow(title: "Design Capacity", value: formatCapacity(detail.designCapacitymAh)),
            BatteryStatRow(title: "Current Capacity", value: formatCapacity(detail.currentCapacitymAh))
        ]
    }

    private var batteryModeText: String {
        guard let detail = metricsStore.batteryDetail else { return "--" }
        return detail.lowPowerModeEnabled ? "Low Power" : "Automatic"
    }

    private func formatWatts(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.0f W", value)
    }

    private func formatAmps(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.1f A", value)
    }

    private func formatVoltage(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.1f V", value)
    }

    private func formatTemperature(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.0f°", value)
    }

    private func formatCapacity(_ value: Int?) -> String {
        guard let value else { return "--" }
        return "\(value.formatted(.number.grouping(.automatic))) mAh"
    }
}

struct BatteryStatSection: View {
    let title: String
    let rows: [BatteryStatRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(Color.blue)

            if rows.isEmpty {
                Text("--")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                ForEach(rows) { row in
                    HStack {
                        Text(row.title)
                        Spacer()
                        Text(row.value)
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
    }
}

struct BatteryStatRow: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

struct BatteryRingPanel: View {
    let percent: Double?
    let healthPercent: Double?

    var body: some View {
        HStack(spacing: 18) {
            BatteryLargeRingView(value: percent ?? 0, title: "BATTERY", icon: "powerplug.fill", colors: [.blue, .cyan, .blue])
            BatteryLargeRingView(value: healthPercent ?? 0, title: "HEALTH", icon: nil, colors: [.pink, .pink])
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.blue.opacity(0.85), lineWidth: 1.2)
        )
        .cornerRadius(18)
    }
}

struct BatteryLargeRingView: View {
    let value: Double
    let title: String
    let icon: String?
    let colors: [Color]

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 12)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(value / 100, 0), 1)))
                .stroke(
                    AngularGradient(colors: colors, center: .center),
                    style: StrokeStyle(lineWidth: 12, lineCap: .butt)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(String(format: "%.0f%%", value))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(12)
        }
        .frame(width: 150, height: 150)
    }
}

struct BatteryLevelPanel: View {
    let samples: [MetricSample]
    let isCharging: Bool
    let isExternalPowerConnected: Bool
    let range: TimeInterval
    let bucketInterval: TimeInterval

    var body: some View {
        VStack(spacing: 10) {
            BatteryLevelBarsView(samples: samples, range: range, bucketInterval: bucketInterval)
                .frame(height: 110)

            RoundedRectangle(cornerRadius: 5)
                .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                .frame(height: 16)
                .overlay(
                    Group {
                        if isCharging || isExternalPowerConnected {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                )
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.04))
        .cornerRadius(18)
    }
}

struct BatteryLevelBarsView: View {
    let samples: [MetricSample]
    let range: TimeInterval
    let bucketInterval: TimeInterval

    var body: some View {
        GeometryReader { proxy in
            let bars = bucketedValues(width: proxy.size.width)
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.blue.opacity(0.95))
                        .frame(width: 4, height: max(proxy.size.height * CGFloat(value / 100), 4))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
    }

    private func bucketedValues(width: CGFloat) -> [Double] {
        let end = Date()
        let start = end.addingTimeInterval(-range)
        let bucketCount = max(Int(width / 6), 12)
        let step = range / Double(bucketCount)
        var buckets = Array(repeating: [Double](), count: bucketCount)

        for sample in samples where sample.timestamp >= start && sample.timestamp <= end {
            let offset = sample.timestamp.timeIntervalSince(start)
            let index = min(max(Int(offset / step), 0), bucketCount - 1)
            buckets[index].append(sample.value)
        }

        return buckets.map { bucket in
            if bucket.isEmpty {
                return samples.last?.value ?? 0
            }
            return bucket.reduce(0, +) / Double(bucket.count)
        }
    }
}

struct BatteryModeRow: View {
    let mode: String

    var body: some View {
        HStack {
            Text("ENERGY MODE")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(Color.blue)
            Spacer()
            Text(mode)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
    }
}

struct BatterySignificantEnergyRow: View {
    let app: SignificantEnergyApp?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("USING SIGNIFICANT ENERGY")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(Color.blue)

            HStack {
                if let app {
                    AppIconView(pid: app.pid, fallbackName: app.name, bundlePath: app.bundlePath)
                    Text(app.name)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Text("No significant app detected")
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
    }
}

struct MemoryCardView: View {
    @EnvironmentObject private var metricsStore: MetricsStore
    let range: TimeInterval
    let bucketInterval: TimeInterval
    let appSeries: [MetricSample]
    let wiredSeries: [MetricSample]
    let compressedSeries: [MetricSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Memory")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(formattedValue)
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.cyan)
            }

            if let detail = metricsStore.memoryDetail {
                HStack(spacing: 16) {
                    RingGaugeView(value: detail.pressurePercent, label: "PRESSURE", colors: [.blue, .cyan, .blue])
                    MemorySummaryRingView(
                        appBytes: detail.appBytes,
                        wiredBytes: detail.wiredBytes,
                        compressedBytes: detail.compressedBytes,
                        freeBytes: detail.freeBytes,
                        usedPercent: detail.usedPercent
                    )
                }
            }

            HStack(alignment: .top, spacing: 12) {
                MemoryStackChartView(
                    appSamples: appSeries,
                    wiredSamples: wiredSeries,
                    compressedSamples: compressedSeries,
                    range: range,
                    bucketInterval: bucketInterval
                )
                .frame(height: 120)

                if let detail = metricsStore.memoryDetail {
                    VStack(alignment: .leading, spacing: 8) {
                        MemoryLegendRow(color: .blue, title: "App", value: formatBytes(detail.appBytes))
                        MemoryLegendRow(color: .orange, title: "Wired", value: formatBytes(detail.wiredBytes))
                        MemoryLegendRow(color: .yellow, title: "Compressed", value: formatBytes(detail.compressedBytes))
                        MemoryLegendRow(color: .gray, title: "Free", value: formatBytes(detail.freeBytes))
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
                }
            }

            if let detail = metricsStore.memoryDetail {
                SectionHeader(title: "PROCESSES")
                ForEach(metricsStore.memoryProcesses) { proc in
                    ProcessMemoryRow(stat: proc)
                }

                HStack {
                    Text("Page Ins \(formatBytes(detail.pageInsBytes))")
                    Spacer()
                    Text("Page Outs \(formatBytes(detail.pageOutsBytes))")
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))

                HStack {
                    Text("Swap \(formatBytes(detail.swapUsedBytes)) of \(formatBytes(detail.swapTotalBytes))")
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color("CardBackground"))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color("CardBorder"), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
        )
    }

    private var formattedValue: String {
        guard let value = metricsStore.latestValue(.memoryUsedPercent) else { return "--" }
        return String(format: "%.0f%%", value)
    }

    private func formatBytes(_ value: UInt64) -> String {
        let gb = Double(value) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(value) / 1_048_576
        return String(format: "%.0f MB", mb)
    }
}

struct MemoryLegendRow: View {
    let color: Color
    let title: String
    let value: String

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundStyle(.white)
        }
    }
}

struct MemorySummaryRingView: View {
    let appBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let freeBytes: UInt64
    let usedPercent: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 10)

            ForEach(segments.indices, id: \.self) { index in
                let segment = segments[index]
                Circle()
                    .trim(from: segment.start, to: segment.end)
                    .stroke(segment.color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 2) {
                Text(String(format: "%.0f%%", usedPercent))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("MEMORY")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(width: 78, height: 78)
    }

    private var segments: [Segment] {
        let total = max(Double(appBytes + wiredBytes + compressedBytes + freeBytes), 1)
        let app = Double(appBytes) / total
        let wired = Double(wiredBytes) / total
        let compressed = Double(compressedBytes) / total
        let free = Double(freeBytes) / total

        let values = [app, wired, compressed, free]
        let colors: [Color] = [.blue, .orange, .yellow, .gray]

        var start: Double = 0
        var result: [Segment] = []
        for (value, color) in zip(values, colors) {
            let end = start + value
            result.append(Segment(start: start, end: end, color: color))
            start = end
        }
        return result
    }

    private struct Segment {
        let start: Double
        let end: Double
        let color: Color
    }
}

struct PerCoreGrid: View {
    let values: [Double]

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(values.prefix(12).enumerated()), id: \.offset) { index, value in
                HStack(spacing: 6) {
                    Text("C\(index + 1)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(String(format: "%.0f%%", value))
                        .font(.caption2)
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
            }
        }
    }
}

struct StatusPopupAppIcon: Identifiable {
    let id = UUID()
    let pid: Int?
    let name: String
    let bundlePath: String?
}

struct StatusItemDetailPopoverView: View {
    @EnvironmentObject private var metricsStore: MetricsStore
    let section: DashboardSection
    let onOpenDashboard: () -> Void

    @State private var selectedRange: TimeRange = .min10
    @State private var refreshTick = Date()

    var body: some View {
        let _ = refreshTick
        VStack(alignment: .leading, spacing: 12) {
            content
            footer
        }
        .padding(12)
        .frame(width: popupWidth)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [Color("BackgroundTop"), Color("BackgroundBottom")], startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color("CardBorder"), lineWidth: 1)
                )
        )
        .onReceive(metricsStore.$sampleTick) { tick in
            refreshTick = tick
        }
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .overview:
            EmptyView()
        case .cpu:
            MetricCard(
                title: "CPU",
                value: metricsStore.latestValue(.cpuUsage),
                unit: "%",
                series: filteredSeries(.cpuUsage),
                accent: .pink,
                range: selectedRange.duration,
                bucketInterval: selectedRange.bucketInterval
            ) {
                SubMetricChartRow(
                    title: "User",
                    value: metricsStore.latestValue(.cpuUser),
                    unit: "%",
                    series: filteredSeries(.cpuUser),
                    accent: .pink,
                    range: selectedRange.duration,
                    bucketInterval: selectedRange.bucketInterval
                )
                SubMetricChartRow(
                    title: "System",
                    value: metricsStore.latestValue(.cpuSystem),
                    unit: "%",
                    series: filteredSeries(.cpuSystem),
                    accent: .pink,
                    range: selectedRange.duration,
                    bucketInterval: selectedRange.bucketInterval
                )

                if let detail = metricsStore.cpuDetail {
                    PerCoreGrid(values: detail.perCore)
                }
            }
        case .memory:
            MemoryCardView(
                range: selectedRange.duration,
                bucketInterval: selectedRange.bucketInterval,
                appSeries: filteredSeries(.memoryAppBytes),
                wiredSeries: filteredSeries(.memoryWiredBytes),
                compressedSeries: filteredSeries(.memoryCompressedBytes)
            )
        case .disk:
            DiskCardView(
                range: selectedRange.duration,
                bucketInterval: selectedRange.bucketInterval,
                readSeries: filteredSeries(.diskReadBytesPerSecond),
                writeSeries: filteredSeries(.diskWriteBytesPerSecond)
            )
        case .network:
            networkPopupCard
        case .gpu:
            MetricCard(
                title: "GPU",
                value: metricsStore.latestValue(.gpuUsage),
                unit: "%",
                series: filteredSeries(.gpuUsage),
                accent: .orange,
                range: selectedRange.duration,
                bucketInterval: selectedRange.bucketInterval,
                note: metricsStore.isGPUSupported ? nil : "GPU usage not available"
            ) {
                EmptyView()
            }
        case .battery:
            BatteryCardView(
                range: selectedRange.duration,
                bucketInterval: selectedRange.bucketInterval,
                batterySeries: filteredSeries(.batteryPercent)
            )
        }
    }

    private var networkPopupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 24) {
                    DiskRateMetric(title: "Upload", value: kbpsToBytes(metricsStore.latestValue(.networkUpKBps)), color: .pink)
                    DiskRateMetric(title: "Download", value: kbpsToBytes(metricsStore.latestValue(.networkDownKBps)), color: .blue)
                }

                DualBarChartView(
                    upSamples: filteredSeries(.networkUpKBps),
                    downSamples: filteredSeries(.networkDownKBps),
                    upColor: .pink,
                    downColor: .blue,
                    range: selectedRange.duration,
                    bucketInterval: selectedRange.bucketInterval
                )
                .frame(height: 110)

                HStack {
                    Text("Upload \(peakLabel(for: filteredSeries(.networkUpKBps)))")
                    Spacer()
                    Text("Download \(peakLabel(for: filteredSeries(.networkDownKBps)))")
                }
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)

            if let interface = activeInterfaceName {
                HStack(spacing: 8) {
                    Image(systemName: "wifi")
                        .foregroundStyle(.blue)
                    Text(interface)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 6)
            }

            SectionHeader(title: "PUBLIC IP ADDRESSES")
            HStack {
                Text(metricsStore.ipInfo.publicIPv4 ?? "--")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
            }

            SectionHeader(title: "IP ADDRESSES")
            ForEach(metricsStore.ipInfo.localIPv4, id: \.self) { ip in
                IPListRow(text: ip)
            }

            SectionHeader(title: "PROCESSES")
            ProcessHeaderRow()
            ForEach(metricsStore.networkProcesses) { proc in
                ProcessRow(stat: proc)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color("CardBackground"))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color("CardBorder"), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
        )
    }

    private var footer: some View {
        HStack(spacing: 10) {
            ForEach(footerIcons) { app in
                Button {
                    openFooterApp(app)
                } label: {
                    AppIconView(pid: app.pid, fallbackName: app.name, bundlePath: app.bundlePath)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private var footerIcons: [StatusPopupAppIcon] {
        [
            StatusPopupAppIcon(pid: nil, name: "Activity Monitor", bundlePath: preferredAppPath(named: "Activity Monitor")),
            StatusPopupAppIcon(pid: nil, name: "Console", bundlePath: preferredAppPath(named: "Console")),
            preferredTerminalAppIcon,
            StatusPopupAppIcon(pid: nil, name: "System Information", bundlePath: preferredAppPath(named: "System Information")),
            StatusPopupAppIcon(pid: nil, name: "iStatus", bundlePath: Bundle.main.bundlePath)
        ]
    }

    private var preferredTerminalAppIcon: StatusPopupAppIcon {
        if let iTermPath = preferredAppPath(named: "iTerm") {
            return StatusPopupAppIcon(pid: nil, name: "iTerm", bundlePath: iTermPath)
        }

        return StatusPopupAppIcon(pid: nil, name: "Terminal", bundlePath: preferredAppPath(named: "Terminal"))
    }

    private func preferredAppPath(named appName: String) -> String? {
        let candidatePaths = [
            "/Applications/\(appName).app",
            "/Applications/Utilities/\(appName).app",
            "/System/Applications/\(appName).app",
            "/System/Applications/Utilities/\(appName).app"
        ]

        if let existingPath = candidatePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
            return existingPath
        }

        return NSWorkspace.shared.runningApplications.first(where: { app in
            app.localizedName == appName
        })?.bundleURL?.path
    }

    private func openFooterApp(_ app: StatusPopupAppIcon) {
        if app.name == "iStatus" {
            onOpenDashboard()
            return
        }

        guard let bundlePath = app.bundlePath else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: bundlePath))
    }

    private var popupWidth: CGFloat {
        switch section {
        case .battery:
            return 760
        case .disk, .memory:
            return 700
        default:
            return 320
        }
    }

    private var activeInterfaceName: String? {
        let serviceOrder = ["Wi-Fi", "Ethernet", "USB 10/100/1000 LAN", "Thunderbolt Bridge"]
        return serviceOrder.first { _ in !metricsStore.ipInfo.localIPv4.isEmpty } ?? (!metricsStore.ipInfo.localIPv4.isEmpty ? "Network" : nil)
    }

    private func kbpsToBytes(_ value: Double?) -> Double? {
        guard let value else { return nil }
        return value * 1024
    }

    private func peakLabel(for series: [MetricSample]) -> String {
        let maxValue = series.map(\.value).max() ?? 0
        return formatNetworkRate(kilobytesPerSecond: maxValue)
    }

    private func filteredSeries(_ type: MetricType) -> [MetricSample] {
        _ = refreshTick
        let cutoff = Date().addingTimeInterval(-selectedRange.duration)
        return metricsStore.series(type).filter { $0.timestamp >= cutoff }
    }
}

private func formatNetworkRate(kilobytesPerSecond value: Double?, fallback: String = "--") -> String {
    guard let value else { return fallback }
    return formatNetworkRate(bytesPerSecond: value * 1024, fallback: fallback)
}

private func formatNetworkRate(bytesPerSecond value: Double?, fallback: String = "--") -> String {
    guard let value else { return fallback }
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
    formatter.countStyle = .binary
    formatter.includesUnit = true
    formatter.isAdaptive = true
    formatter.zeroPadsFractionDigits = false
    return formatter.string(fromByteCount: Int64(value)) + "/s"
}
