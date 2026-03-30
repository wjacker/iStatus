import SwiftUI
import AppKit

enum DashboardSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case cpu = "CPU"
    case memory = "Memory"
    case disk = "Disk"
    case network = "Network"
    case temperature = "CPU Temp"
    case battery = "Battery"

    var id: String { rawValue }

    static var visibleCases: [DashboardSection] {
        [.overview, .cpu, .memory, .disk, .network, .temperature, .battery]
    }

    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2.fill"
        case .cpu: return "cpu.fill"
        case .memory: return "memorychip.fill"
        case .disk: return "internaldrive.fill"
        case .network: return "wave.3.right"
        case .temperature: return "thermometer.medium"
        case .battery: return "battery.100percent"
        }
    }

    var accent: Color {
        switch self {
        case .overview: return Color(red: 0.52, green: 0.76, blue: 1.0)
        case .cpu: return .pink
        case .memory: return .cyan
        case .disk: return .blue
        case .network: return .mint
        case .temperature: return .orange
        case .battery: return .green
        }
    }
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
    @State private var isSidebarCollapsed = false

    var body: some View {
        let _ = refreshTick
        GeometryReader { proxy in
            let availableContentWidth = max(proxy.size.width - sidebarWidth, 320)

            ZStack {
                dashboardBackground
                    .ignoresSafeArea()

                HStack(spacing: 0) {
                    sidebar
                    content(availableWidth: availableContentWidth)
                }
            }
        }
        .onReceive(metricsStore.$sampleTick) { tick in
            refreshTick = tick
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                if isSidebarCollapsed {
                    VStack(spacing: 12) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)

                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                isSidebarCollapsed.toggle()
                            }
                        } label: {
                            Image(systemName: "sidebar.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white.opacity(0.82))
                                .frame(width: 28, height: 28)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.035))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                } else {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("iStatus")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(.white)

                            Text("Beautiful live system telemetry for your Mac.")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.68))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                isSidebarCollapsed.toggle()
                            }
                        } label: {
                            Image(systemName: "sidebar.left")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white.opacity(0.82))
                                .frame(width: 28, height: 28)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(18)
                    .dashboardPanel(fillOpacity: 0.18, strokeOpacity: 0.18)
                }
            }

            ForEach(DashboardSection.visibleCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: section.icon)
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 18)
                            .foregroundStyle(selectedSection == section ? Color.black.opacity(0.82) : section.accent)

                        if !isSidebarCollapsed {
                            Text(section.rawValue)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            Spacer()
                        }

                        if selectedSection == section && !isSidebarCollapsed {
                            Circle()
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 7, height: 7)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: isSidebarCollapsed ? .center : .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                selectedSection == section
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [section.accent.opacity(0.92), Color.white.opacity(0.88)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                : AnyShapeStyle(Color.white.opacity(0.035))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(selectedSection == section ? 0.08 : 0.1), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedSection == section ? Color.black.opacity(0.84) : .white)
                .help(section.rawValue)
            }

            Spacer()

            if !isSidebarCollapsed {
                HStack(spacing: 8) {
                    Circle()
                        .fill(selectedSection.accent)
                        .frame(width: 9, height: 9)

                    Text("Live sampling every 2 seconds")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .padding(24)
        .frame(width: sidebarWidth)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isSidebarCollapsed)
    }

    private var sidebarWidth: CGFloat {
        isSidebarCollapsed ? 104 : 228
    }

    private func content(availableWidth: CGFloat) -> some View {
        let isCompact = availableWidth < 760

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(isCompact: isCompact)
                quickStats(isCompact: isCompact)

                if selectedSection == .overview {
                    overviewGrid(isCompact: isCompact)
                } else {
                    sectionDetail
                }
            }
            .frame(maxWidth: isCompact ? .infinity : 1220, alignment: .leading)
            .padding(.leading, isCompact ? 4 : 5)
            .padding(.trailing, isCompact ? 18 : 28)
            .padding(.vertical, isCompact ? 20 : 26)
        }
    }

    private func header(isCompact: Bool) -> some View {
        Group {
            if isCompact {
                VStack(alignment: .leading, spacing: 16) {
                    headerMeta

                    HStack(spacing: 12) {
                        MetricGlyph(symbol: selectedSection.icon, accent: selectedSection.accent, size: 36)
                        Text(selectedSection.rawValue)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Text("Rolling history, high-frequency telemetry, and a cleaner view of what your Mac is doing right now.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.74))

                    TimeRangePicker(selected: $selectedRange)
                }
            } else {
                HStack(alignment: .center, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        headerMeta

                        HStack(spacing: 12) {
                            MetricGlyph(symbol: selectedSection.icon, accent: selectedSection.accent, size: 42)
                            Text(selectedSection.rawValue)
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Text("Rolling history, high-frequency telemetry, and a cleaner view of what your Mac is doing right now.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.74))
                    }
                    Spacer()
                    TimeRangePicker(selected: $selectedRange)
                }
            }
        }
        .padding(22)
        .dashboardPanel(fillOpacity: 0.13, strokeOpacity: 0.14)
    }

    private var headerMeta: some View {
        HStack(spacing: 10) {
            if let menuBarItem = selectedSection.menuBarItem {
                MenuBarVisibilityButton(item: menuBarItem, style: .header)
            }

            HStack(spacing: 8) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 12, weight: .bold))
                Text("Live")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(selectedSection.accent)
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(selectedSection.accent.opacity(0.18))
            .overlay(
                Capsule()
                    .stroke(selectedSection.accent.opacity(0.38), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
    }

    private func quickStats(isCompact: Bool) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 132 : 170), spacing: 14)], spacing: 14) {
            StatPill(title: "CPU", icon: "cpu.fill", value: metricsStore.latestValue(.cpuUsage), unit: "%", accent: .pink)
            StatPill(title: "Memory", icon: "memorychip.fill", value: metricsStore.latestValue(.memoryUsedPercent), unit: "%", accent: .cyan)
            StatPill(
                title: "Network",
                icon: "wave.3.right",
                value: metricsStore.latestValue(.networkTotalKBps),
                unit: "KB/s",
                accent: .mint,
                formattedValueOverride: formatNetworkRate(kilobytesPerSecond: metricsStore.latestValue(.networkTotalKBps))
            )
            StatPill(title: "Battery", icon: "battery.100percent", value: metricsStore.latestValue(.batteryPercent), unit: "%", accent: .green)
        }
    }

    private func overviewGrid(isCompact: Bool) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 260 : 320), spacing: 18)], spacing: 18) {
            cpuCard
            memoryCard
            diskCard
            networkCard
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
            case .temperature:
                temperatureCard
            case .battery:
                batteryCard
            }
        }
    }

    private var cpuCard: some View {
        MetricCard(
            title: "CPU",
            icon: "cpu.fill",
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
            icon: "wave.3.right",
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

    private var temperatureCard: some View {
        CPUTemperatureCardView(
            range: selectedRange.duration,
            bucketInterval: selectedRange.bucketInterval,
            temperatureSeries: filteredSeries(.cpuTemperature)
        )
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

private extension DashboardSection {
    var menuBarItem: MenuBarMetricItem? {
        switch self {
        case .overview:
            return nil
        case .cpu:
            return .cpu
        case .memory:
            return .memory
        case .disk:
            return .disk
        case .network:
            return .network
        case .temperature:
            return .temperature
        case .battery:
            return .battery
        }
    }
}

struct StatPill: View {
    let title: String
    let icon: String
    let value: Double?
    let unit: String
    let accent: Color
    var formattedValueOverride: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    MetricGlyph(symbol: icon, accent: accent, size: 22)
                    Text(title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .tracking(1.1)
                }
                Spacer()
                Circle()
                    .fill(accent)
                    .frame(width: 9, height: 9)
                    .shadow(color: accent.opacity(0.7), radius: 6)
            }

            Text(formattedValue)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.9), accent.opacity(0.18)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .dashboardPanel(fillOpacity: 0.13, strokeOpacity: 0.12)
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
                        .foregroundStyle(selected == range ? Color.black.opacity(0.84) : Color.white.opacity(0.88))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    selected == range
                                    ? AnyShapeStyle(
                                        LinearGradient(
                                            colors: [Color.white, Color.white.opacity(0.82)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    : AnyShapeStyle(Color.white.opacity(0.06))
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .frame(height: 44)
        .fixedSize(horizontal: true, vertical: false)
        .dashboardPanel(fillOpacity: 0.1, strokeOpacity: 0.12, cornerRadius: 14, shadow: false)
    }
}

struct MetricCard<Footer: View>: View {
    let title: String
    var icon: String? = nil
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
        VStack(alignment: .leading, spacing: 14) {
            DashboardCardHeader(
                title: title,
                subtitle: "Recent activity",
                value: formattedValue,
                accent: accent,
                icon: icon
            )

            MiniChartView(
                samples: series,
                accent: accent,
                range: range,
                bucketInterval: bucketInterval,
                valueFormatter: tooltipFormatter
            )
                .frame(height: 110)

            footer()

            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(20)
        .dashboardCardBackground()
    }

    private var formattedValue: String {
        if let formattedValueOverride {
            return formattedValueOverride
        }
        guard let value else { return "--" }
        return String(format: "%.0f%@", value, unit)
    }

    private var tooltipFormatter: (Double?) -> String {
        { value in
            if unit == "KB/s" {
                return formatNetworkRate(kilobytesPerSecond: value)
            }

            guard let value else { return "--" }

            switch unit {
            case "%":
                return String(format: "%.0f%%", value)
            case "°C":
                return String(format: "%.0f°C", value)
            default:
                return String(format: "%.1f%@", value, unit)
            }
        }
    }
}

struct MenuBarVisibilityButton: View {
    @EnvironmentObject private var menuBarSettings: MenuBarSettingsStore
    let item: MenuBarMetricItem
    var style: Style = .header

    enum Style {
        case header
    }

    var body: some View {
        let isEnabled = menuBarSettings.isEnabled(item)

        Button {
            isOnBinding.wrappedValue.toggle()
        } label: {
            HStack(spacing: 10) {
                ZStack(alignment: isEnabled ? .trailing : .leading) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: isEnabled
                                ? [Color(red: 0.11, green: 0.50, blue: 0.98), Color(red: 0.21, green: 0.67, blue: 1.0)]
                                : [Color.white.opacity(0.22), Color.white.opacity(0.14)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 52, height: 30)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 28, height: 28)
                        .overlay {
                            if isEnabled {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .black))
                                    .foregroundStyle(Color.black.opacity(0.82))
                            }
                        }
                        .padding(1)
                        .shadow(color: .black.opacity(isEnabled ? 0.24 : 0.14), radius: 8, x: 0, y: 4)
                }

                Text(isEnabled ? "On" : "Off")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(isEnabled ? 0.92 : 0.7))
            }
            .padding(.horizontal, 8)
            .frame(height: 44)
            .background(Color.white.opacity(isEnabled ? 0.12 : 0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .stroke(Color.white.opacity(isEnabled ? 0.18 : 0.09), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 999, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(isEnabled ? "Hide from menu bar" : "Show in menu bar")
    }

    private var isOnBinding: Binding<Bool> {
        Binding(
            get: { menuBarSettings.isEnabled(item) },
            set: { menuBarSettings.setEnabled($0, for: item) }
        )
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
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .tracking(1)
                Text(formattedValue)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 56, alignment: .leading)
            MiniChartView(
                samples: series,
                accent: accent,
                range: range,
                bucketInterval: bucketInterval,
                valueFormatter: tooltipFormatter
            )
                .frame(height: 36)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .dashboardPanel(fillOpacity: 0.07, strokeOpacity: 0.08, cornerRadius: 12, shadow: false)
    }

    private var formattedValue: String {
        if let formattedValueOverride {
            return formattedValueOverride
        }
        guard let value else { return "--" }
        return String(format: "%.0f%@", value, unit)
    }

    private var tooltipFormatter: (Double?) -> String {
        { value in
            if unit == "KB/s" {
                return formatNetworkRate(kilobytesPerSecond: value)
            }

            guard let value else { return "--" }

            switch unit {
            case "%":
                return String(format: "%.0f%%", value)
            case "°C":
                return String(format: "%.0f°C", value)
            default:
                return String(format: "%.1f%@", value, unit)
            }
        }
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.62))
            .tracking(1.2)
            .padding(.top, 8)
    }
}

struct MetricGlyph: View {
    let symbol: String
    let accent: Color
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.28), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(accent)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.34, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct DashboardCardHeader: View {
    let title: String
    let subtitle: String
    let value: String
    let accent: Color
    var icon: String? = nil

    var body: some View {
        HStack(alignment: .top) {
            HStack(spacing: 12) {
                if let icon {
                    MetricGlyph(symbol: icon, accent: accent, size: 34)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text(title.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                        .tracking(1.2)
                    Text(title)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Circle()
                    .fill(accent)
                    .frame(width: 10, height: 10)
                    .shadow(color: accent.opacity(0.8), radius: 8)
                Text(value)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }
}

struct IPListRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.callout, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dashboardPanel(fillOpacity: 0.06, strokeOpacity: 0.08, cornerRadius: 12, shadow: false)
    }
}

struct ProcessHeaderRow: View {
    var body: some View {
        HStack {
            Text("Process")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Down")
                .frame(width: processRateColumnWidth, alignment: .trailing)
            Text("Up")
                .frame(width: processRateColumnWidth, alignment: .trailing)
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
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(format(stat.downKBps))
                .frame(width: processRateColumnWidth, alignment: .trailing)
            Text(format(stat.upKBps))
                .frame(width: processRateColumnWidth, alignment: .trailing)
        }
        .font(.system(.callout, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .dashboardPanel(fillOpacity: 0.05, strokeOpacity: 0.06, cornerRadius: 12, shadow: false)
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

private let processRateColumnWidth: CGFloat = 84

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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .dashboardPanel(fillOpacity: 0.05, strokeOpacity: 0.06, cornerRadius: 12, shadow: false)
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
            DashboardCardHeader(
                title: "Disk",
                subtitle: "Storage throughput",
                value: throughputValue,
                accent: .blue,
                icon: "internaldrive.fill"
            )

            HStack(alignment: .top, spacing: 14) {
                if let detail = metricsStore.diskDetail {
                    DiskUsageRingView(volume: detail.volume)
                    DiskCapacityLegend(volume: detail.volume)
                } else {
                    placeholderPanel(
                        title: "Disk details are loading",
                        message: "Capacity and volume breakdown will appear after the first disk sample arrives."
                    )
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

                if readSeries.isEmpty && writeSeries.isEmpty {
                    InlineEmptyState(
                        title: "No disk transfer history yet",
                        message: "Recent read and write activity will show up here automatically."
                    )
                } else {
                    HStack {
                        Text("Read \(peakLabel(for: readSeries))")
                        Spacer()
                        Text("Write \(peakLabel(for: writeSeries))")
                    }
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(14)

            SectionHeader(title: "PROCESSES")
            if metricsStore.diskProcesses.isEmpty {
                EmptyListState(
                    title: "No active disk processes",
                    message: "Per-process reads and writes appear once apps start moving data."
                )
            } else {
                ProcessDiskHeaderRow()
                ForEach(metricsStore.diskProcesses) { proc in
                    ProcessDiskRow(stat: proc)
                }
            }
        }
        .padding(16)
        .dashboardCardBackground()
    }

    private func placeholderPanel(title: String, message: String) -> some View {
        EmptyStatePanel(
            icon: "internaldrive.fill",
            title: title,
            message: message,
            minHeight: 120
        )
    }

    private func peakLabel(for series: [MetricSample]) -> String {
        formatTransferRate(series.map(\.value).max() ?? 0)
    }

    private func formatTransferRate(_ value: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .binary) + "/s"
    }

    private var throughputValue: String {
        let read = metricsStore.latestValue(.diskReadBytesPerSecond) ?? 0
        let write = metricsStore.latestValue(.diskWriteBytesPerSecond) ?? 0
        return formatTransferRate(read + write)
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
            Text("Read/s")
                .frame(width: 72, alignment: .trailing)
            Text("Write/s")
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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .dashboardPanel(fillOpacity: 0.05, strokeOpacity: 0.06, cornerRadius: 12, shadow: false)
    }

    private var appDisplayName: String {
        if let pid = stat.pid, let app = NSRunningApplication(processIdentifier: pid_t(pid)), let name = app.localizedName {
            return name
        }
        return stat.name
    }

    private func format(_ value: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .binary) + "/s"
    }
}

struct BatteryCardView: View {
    @EnvironmentObject private var metricsStore: MetricsStore
    let range: TimeInterval
    let bucketInterval: TimeInterval
    let batterySeries: [MetricSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DashboardCardHeader(
                title: "Battery",
                subtitle: "Power source and health",
                value: metricsStore.batteryDetail.map { String(format: "%.0f%%", $0.percent) } ?? "--",
                accent: .green,
                icon: "battery.100percent"
            )

            if metricsStore.batteryDetail == nil {
                EmptyStatePanel(
                    icon: "battery.100percent",
                    title: "Battery telemetry unavailable",
                    message: "This Mac may still be gathering battery details, or the current hardware does not expose them."
                )
            } else {
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
            }
        }
        .padding(16)
        .dashboardCardBackground()
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
        return String(format: "%.0f°C", value)
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

struct CPUTemperatureCardView: View {
    @EnvironmentObject private var metricsStore: MetricsStore
    let range: TimeInterval
    let bucketInterval: TimeInterval
    let temperatureSeries: [MetricSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DashboardCardHeader(
                title: "CPU Temp",
                subtitle: "Thermal and fan telemetry",
                value: formatTemperature(metricsStore.latestValue(.cpuTemperature)),
                accent: .orange,
                icon: "thermometer.medium"
            )

            HStack(alignment: .top, spacing: 16) {
                TemperatureHeroRing(value: metricsStore.latestValue(.cpuTemperature))

                VStack(alignment: .leading, spacing: 12) {
                    if temperatureSeries.isEmpty {
                        EmptyStatePanel(
                            icon: "thermometer.medium",
                            title: "No temperature history yet",
                            message: "Thermal samples will appear here as soon as the sensor stream updates.",
                            minHeight: 92
                        )
                    } else {
                        MiniChartView(
                            samples: temperatureSeries,
                            accent: .orange,
                            range: range,
                            bucketInterval: bucketInterval,
                            valueFormatter: { value in
                                guard let value else { return "--" }
                                return String(format: "%.0f°C", value)
                            }
                        )
                            .frame(height: 92)
                    }

                    HStack(spacing: 12) {
                        TemperatureSummaryPill(title: "CPU", value: formatTemperature(metricsStore.latestValue(.cpuTemperature)))
                        TemperatureSummaryPill(title: "POWER", value: powerSummary)
                        TemperatureSummaryPill(title: "FANS", value: fanSummary)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            BatteryStatSection(title: "TEMPERATURE", rows: temperatureRows.isEmpty ? unsupportedRows : temperatureRows)
            BatteryStatSection(title: "THERMAL / POWER", rows: thermalRows.isEmpty ? unsupportedRows : thermalRows)
            BatteryStatSection(title: "FANS", rows: fanRows.isEmpty ? unsupportedRows : fanRows)
        }
        .padding(16)
        .dashboardCardBackground()
    }

    private var temperatureRows: [BatteryStatRow] {
        guard let detail = metricsStore.cpuTemperatureDetail else { return [] }
        let rows = detail.sensors.prefix(8).map { stat in
            BatteryStatRow(title: stat.name, value: formatTemperature(stat.celsius))
        }
        return rows.isEmpty ? [BatteryStatRow(title: "CPU", value: formatTemperature(detail.overall))] : rows
    }

    private var fanRows: [BatteryStatRow] {
        guard let detail = metricsStore.cpuTemperatureDetail else { return [] }
        return detail.fans.map { fan in
            BatteryStatRow(title: fan.name, value: formatRPM(fan.rpm))
        }
    }

    private var thermalRows: [BatteryStatRow] {
        guard let detail = metricsStore.cpuTemperatureDetail else { return [] }

        var rows: [BatteryStatRow] = []
        if let thermalPressure = detail.thermalPressure?.level {
            rows.append(BatteryStatRow(title: "Pressure", value: thermalPressure))
        }
        if let packageWatts = detail.power?.packageWatts {
            rows.append(BatteryStatRow(title: "Package", value: formatWatts(packageWatts)))
        }
        if let cpuWatts = detail.power?.cpuWatts {
            rows.append(BatteryStatRow(title: "CPU", value: formatWatts(cpuWatts)))
        }
        return rows
    }

    private var unsupportedRows: [BatteryStatRow] {
        let message = metricsStore.cpuTemperatureDetail?.statusMessage ?? "Unavailable from IOKit/SMC on this Mac"
        return [BatteryStatRow(title: "Status", value: message)]
    }

    private var powerSummary: String {
        if let watts = metricsStore.cpuTemperatureDetail?.power?.packageWatts {
            return formatWatts(watts)
        }
        return "--"
    }

    private var fanSummary: String {
        let count = metricsStore.cpuTemperatureDetail?.fans.count ?? 0
        return count > 0 ? "\(count)" : "--"
    }

    private func formatTemperature(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.0f°C", value)
    }

    private func formatRPM(_ value: Double?) -> String {
        guard let value else { return "--" }
        return "\(Int(value.rounded())).formatted(.number.grouping(.automatic)) rpm"
    }

    private func formatWatts(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.2f W", value)
    }
}

private struct TemperatureHeroRing: View {
    let value: Double?

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 12)
            Circle()
                .trim(from: 0, to: CGFloat(min(max((value ?? 0) / 100, 0), 1)))
                .stroke(
                    AngularGradient(colors: [.blue, .cyan, .blue], center: .center),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text(value.map { String(format: "%.0f°C", $0) } ?? "--")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("CPU TEMP")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(12)
        }
        .frame(width: 122, height: 122)
    }
}

private struct TemperatureSummaryPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
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
                    .font(.system(size: 28, weight: .bold, design: .rounded))
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
            if samples.isEmpty {
                EmptyStatePanel(
                    icon: "chart.bar.fill",
                    title: "No battery history yet",
                    message: "Charge level history will fill in after a few fresh samples.",
                    minHeight: 110
                )
            } else {
                BatteryLevelBarsView(samples: samples, range: range, bucketInterval: bucketInterval)
                    .frame(height: 110)
            }

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
            DashboardCardHeader(
                title: "Memory",
                subtitle: "Pressure and allocation mix",
                value: formattedValue,
                accent: .cyan,
                icon: "memorychip.fill"
            )

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

            if let detail = metricsStore.memoryDetail {
                HStack(alignment: .top, spacing: 12) {
                    if appSeries.isEmpty && wiredSeries.isEmpty && compressedSeries.isEmpty {
                        EmptyStatePanel(
                            icon: "memorychip.fill",
                            title: "No memory history yet",
                            message: "Usage composition will appear after the first rolling samples are collected.",
                            minHeight: 120
                        )
                    } else {
                        MemoryStackChartView(
                            appSamples: appSeries,
                            wiredSamples: wiredSeries,
                            compressedSamples: compressedSeries,
                            range: range,
                            bucketInterval: bucketInterval
                        )
                        .frame(height: 120)
                    }

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

                SectionHeader(title: "PROCESSES")
                if metricsStore.memoryProcesses.isEmpty {
                    EmptyListState(
                        title: "No heavy memory processes yet",
                        message: "The largest memory users will appear here once process details are available."
                    )
                } else {
                    ForEach(metricsStore.memoryProcesses) { proc in
                        ProcessMemoryRow(stat: proc)
                    }
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
            } else {
                EmptyStatePanel(
                    icon: "memorychip.fill",
                    title: "Memory details are loading",
                    message: "Pressure, composition, swap, and process details will appear once sampling completes."
                )
            }
        }
        .padding(16)
        .dashboardCardBackground()
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
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.07, green: 0.11, blue: 0.19),
                            Color(red: 0.03, green: 0.05, blue: 0.11)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.32), radius: 22, x: 0, y: 18)
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
        case .temperature:
            CPUTemperatureCardView(
                range: selectedRange.duration,
                bucketInterval: selectedRange.bucketInterval,
                temperatureSeries: filteredSeries(.cpuTemperature)
            )
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

                if filteredSeries(.networkUpKBps).isEmpty && filteredSeries(.networkDownKBps).isEmpty {
                    InlineEmptyState(
                        title: "No network history yet",
                        message: "Upload and download activity will appear here once traffic is observed."
                    )
                } else {
                    HStack {
                        Text("Upload \(peakLabel(for: filteredSeries(.networkUpKBps)))")
                        Spacer()
                        Text("Download \(peakLabel(for: filteredSeries(.networkDownKBps)))")
                    }
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                }
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
            if let publicIPv4 = metricsStore.ipInfo.publicIPv4, !publicIPv4.isEmpty {
                HStack {
                    Text(publicIPv4)
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                }
            } else {
                InlineEmptyState(
                    title: "Public IP not available",
                    message: "A public address will show here when the network probe resolves it."
                )
            }

            SectionHeader(title: "IP ADDRESSES")
            if metricsStore.ipInfo.localIPv4.isEmpty {
                EmptyListState(
                    title: "No local addresses detected",
                    message: "Interface addresses will appear after the active network service is identified."
                )
            } else {
                ForEach(metricsStore.ipInfo.localIPv4, id: \.self) { ip in
                    IPListRow(text: ip)
                }
            }

            SectionHeader(title: "PROCESSES")
            if metricsStore.networkProcesses.isEmpty {
                EmptyListState(
                    title: "No network-heavy processes",
                    message: "Per-process traffic appears here when apps start uploading or downloading."
                )
            } else {
                ProcessHeaderRow()
                ForEach(metricsStore.networkProcesses) { proc in
                    ProcessRow(stat: proc)
                }
            }
        }
        .padding(16)
        .dashboardCardBackground()
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

private extension View {
    func dashboardPanel(
        fillOpacity: Double = 0.12,
        strokeOpacity: Double = 0.12,
        cornerRadius: CGFloat = 18,
        shadow: Bool = true
    ) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(fillOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(strokeOpacity), lineWidth: 1)
                )
                .shadow(color: shadow ? .black.opacity(0.18) : .clear, radius: shadow ? 16 : 0, x: 0, y: shadow ? 10 : 0)
        )
    }

    func dashboardCardBackground() -> some View {
        background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.24), radius: 24, x: 0, y: 18)
        )
    }
}

private struct EmptyStatePanel: View {
    let icon: String
    let title: String
    let message: String
    var minHeight: CGFloat = 148

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))

            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: minHeight)
        .dashboardPanel(fillOpacity: 0.07, strokeOpacity: 0.09, cornerRadius: 16, shadow: false)
    }
}

private struct EmptyListState: View {
    let title: String
    let message: String

    var body: some View {
        EmptyStatePanel(
            icon: "tray.fill",
            title: title,
            message: message,
            minHeight: 84
        )
    }
}

private struct InlineEmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
            Text(message)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.64))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .dashboardPanel(fillOpacity: 0.05, strokeOpacity: 0.07, cornerRadius: 12, shadow: false)
    }
}

private extension DashboardView {
    var dashboardBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.07, blue: 0.14),
                    Color(red: 0.02, green: 0.04, blue: 0.09),
                    Color(red: 0.01, green: 0.02, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(selectedSection.accent.opacity(0.24))
                .blur(radius: 110)
                .frame(width: 320, height: 320)
                .offset(x: -440, y: -250)

            Circle()
                .fill(Color.cyan.opacity(0.16))
                .blur(radius: 140)
                .frame(width: 380, height: 380)
                .offset(x: 320, y: -180)

            Circle()
                .fill(Color.pink.opacity(0.14))
                .blur(radius: 150)
                .frame(width: 360, height: 360)
                .offset(x: 440, y: 280)
        }
    }
}
