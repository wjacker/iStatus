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
    case hour3 = "3h"
    case hour6 = "6h"
    case hour12 = "12h"
    case hour24 = "24h"

    var id: String { rawValue }

    var duration: TimeInterval {
        switch self {
        case .min10: return 10 * 60
        case .hour1: return 60 * 60
        case .hour3: return 3 * 60 * 60
        case .hour6: return 6 * 60 * 60
        case .hour12: return 12 * 60 * 60
        case .hour24: return 24 * 60 * 60
        }
    }

    var bucketInterval: TimeInterval {
        switch self {
        case .min10: return 5
        case .hour1: return 30
        case .hour3: return 60
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
    @State private var isSidebarCollapsed = false
    @State private var filteredSeriesCache: [MetricType: [MetricSample]] = [:]

    var body: some View {
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
        .onAppear {
            rebuildFilteredSeriesCache(referenceDate: metricsStore.sampleTick == .distantPast ? Date() : metricsStore.sampleTick)
        }
        .onReceive(metricsStore.$sampleTick) { tick in
            rebuildFilteredSeriesCache(referenceDate: tick == .distantPast ? Date() : tick)
        }
        .onChange(of: selectedRange) { _ in
            rebuildFilteredSeriesCache(referenceDate: metricsStore.sampleTick == .distantPast ? Date() : metricsStore.sampleTick)
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
            VStack(alignment: .leading, spacing: 22) {
                header(isCompact: isCompact)

                if selectedSection == .overview {
                    quickStats(isCompact: isCompact)
                    overviewGrid(availableWidth: availableWidth)
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

                    Text(selectedSection.description)
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
                        Text(selectedSection.description)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.74))
                    }
                    Spacer()
                    TimeRangePicker(selected: $selectedRange)
                }
            }
        }
        .padding(isCompact ? 20 : 24)
        .dashboardPanel(fillOpacity: 0.14, strokeOpacity: 0.14)
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(selectedSection.accent.opacity(0.16))
                .blur(radius: 36)
                .frame(width: 120, height: 120)
                .offset(x: 24, y: -24)
                .allowsHitTesting(false)
        }
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
        LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 144 : 178), spacing: 14)], spacing: 14) {
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

    private func overviewGrid(availableWidth: CGFloat) -> some View {
        let outerTrailingInset: CGFloat = 14
        let columnCount: Int
        if availableWidth < 760 {
            columnCount = 1
        } else if availableWidth < 1120 {
            columnCount = 2
        } else {
            columnCount = 3
        }

        let columns = distributeOverviewCards(into: columnCount)
        let spacing: CGFloat = 18
        let totalSpacing = spacing * CGFloat(max(columnCount - 1, 0))
        let usableWidth = max(availableWidth - outerTrailingInset, 0)
        let columnWidth = max((usableWidth - totalSpacing) / CGFloat(columnCount), 0)

        return HStack(alignment: .top, spacing: 18) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(column) { card in
                        overviewCardView(for: card.kind)
                            .frame(width: columnWidth, alignment: .topLeading)
                    }
                }
                .frame(width: columnWidth, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, outerTrailingInset)
    }

    private func distributeOverviewCards(into columnCount: Int) -> [[OverviewCardItem]] {
        let cards = overviewCards
        guard columnCount > 1 else { return [cards] }

        var columns = Array(repeating: [OverviewCardItem](), count: columnCount)
        var columnHeights = Array(repeating: CGFloat.zero, count: columnCount)

        for card in cards {
            let targetIndex = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            columns[targetIndex].append(card)
            columnHeights[targetIndex] += card.estimatedHeight
        }

        return columns
    }

    private var overviewCards: [OverviewCardItem] {
        [
            OverviewCardItem(kind: .cpu, estimatedHeight: 420),
            OverviewCardItem(kind: .memory, estimatedHeight: 540),
            OverviewCardItem(kind: .disk, estimatedHeight: 470),
            OverviewCardItem(kind: .network, estimatedHeight: 430),
            OverviewCardItem(kind: .battery, estimatedHeight: 500)
        ]
    }

    @ViewBuilder
    private func overviewCardView(for kind: OverviewCardKind) -> some View {
        switch kind {
        case .cpu:
            cpuCard
        case .memory:
            memoryCard
        case .disk:
            diskCard
        case .network:
            networkCard
        case .battery:
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
                bucketInterval: selectedRange.bucketInterval,
                valueFormatter: { formatNetworkRate(kilobytesPerSecond: $0) }
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
            batteryHistory: filteredBatteryHistory()
        )
    }

    private func filteredSeries(_ type: MetricType) -> [MetricSample] {
        filteredSeriesCache[type] ?? []
    }

    private func filteredBatteryHistory() -> [BatteryHistorySample] {
        let referenceDate = metricsStore.sampleTick == .distantPast ? Date() : metricsStore.sampleTick
        let cutoff = referenceDate.addingTimeInterval(-selectedRange.duration)
        return metricsStore.batteryHistory(from: cutoff)
    }

    private func rebuildFilteredSeriesCache(referenceDate: Date) {
        let cutoff = referenceDate.addingTimeInterval(-selectedRange.duration)
        var nextCache: [MetricType: [MetricSample]] = [:]

        for type in MetricType.dashboardTypes {
            nextCache[type] = metricsStore.series(type).samples(from: cutoff)
        }

        filteredSeriesCache = nextCache
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

private enum OverviewCardKind: String, Identifiable {
    case cpu
    case memory
    case disk
    case network
    case battery

    var id: String { rawValue }
}

private struct OverviewCardItem: Identifiable {
    let kind: OverviewCardKind
    let estimatedHeight: CGFloat

    var id: OverviewCardKind { kind }
}

private extension MetricType {
    static let dashboardTypes: [MetricType] = [
        .cpuUsage,
        .cpuUser,
        .cpuSystem,
        .cpuTemperature,
        .memoryAppBytes,
        .memoryWiredBytes,
        .memoryCompressedBytes,
        .diskReadBytesPerSecond,
        .diskWriteBytesPerSecond,
        .networkTotalKBps,
        .networkDownKBps,
        .networkUpKBps,
        .batteryPercent
    ]
}

private extension Array where Element == MetricSample {
    func samples(from cutoff: Date) -> [MetricSample] {
        guard !isEmpty else { return [] }

        var lowerBound = 0
        var upperBound = count

        while lowerBound < upperBound {
            let mid = (lowerBound + upperBound) / 2
            if self[mid].timestamp < cutoff {
                lowerBound = mid + 1
            } else {
                upperBound = mid
            }
        }

        guard lowerBound < count else { return [] }
        return Array(self[lowerBound...])
    }
}

private extension DashboardSection {
    var description: String {
        switch self {
        case .overview:
            return "A quick glance at the most important system activity across your Mac."
        case .cpu:
            return "Live CPU load, recent activity, and how work is split across your cores."
        case .memory:
            return "Memory pressure, allocation mix, and which apps are using the most RAM."
        case .disk:
            return "Storage usage, throughput history, and the apps moving data right now."
        case .network:
            return "Traffic history, connection details, and the processes sending or receiving data."
        case .temperature:
            return "Thermal trends, fan behavior, and the current temperature picture of your Mac."
        case .battery:
            return "Power source, battery health, and recent charge behavior across the day."
        }
    }

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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    MetricGlyph(symbol: icon, accent: accent, size: 24)
                    Text(title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .tracking(1.1)
                }
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(accent)
                        .frame(width: 8, height: 8)
                        .shadow(color: accent.opacity(0.7), radius: 6)
                    Text("LIVE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                        .tracking(1)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(formattedValue)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("Current reading")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
            }

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
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .dashboardPanel(fillOpacity: 0.14, strokeOpacity: 0.12)
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
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.leading, 6)

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
                                            colors: [Color.white, Color.white.opacity(0.84)],
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
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
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
    var showsBackground: Bool = true
    var showsHeader: Bool = true
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsHeader {
                DashboardCardHeader(
                    title: title,
                    subtitle: "Recent activity",
                    value: formattedValue,
                    accent: accent,
                    icon: icon
                )
            }

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
        .modifier(ConditionalDashboardCardBackground(isEnabled: showsBackground))
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
        let accent = item.accent

        Button {
            isOnBinding.wrappedValue.toggle()
        } label: {
            HStack(spacing: 10) {
                ZStack(alignment: isEnabled ? .trailing : .leading) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: isEnabled
                                ? [accent.opacity(0.95), accent.opacity(0.72)]
                                : [accent.opacity(0.24), accent.opacity(0.14)],
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
                    .foregroundStyle(.white.opacity(isEnabled ? 0.94 : 0.72))
            }
            .padding(.horizontal, 8)
            .frame(height: 44)
            .background(accent.opacity(isEnabled ? 0.18 : 0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .stroke(accent.opacity(isEnabled ? 0.38 : 0.24), lineWidth: 1)
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
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .tracking(1.2)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.16), Color.white.opacity(0.02)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
        .padding(.top, 10)
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
        HStack(alignment: .top, spacing: 16) {
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

            VStack(alignment: .trailing, spacing: 10) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.92), accent.opacity(0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 36, height: 6)
                    .shadow(color: accent.opacity(0.45), radius: 8)
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
            .font(.system(.callout, design: .monospaced))
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
        .font(.system(size: 11, weight: .bold, design: .rounded))
        .foregroundStyle(.white.opacity(0.58))
        .tracking(1)
        .padding(.horizontal, 4)
    }
}

private struct MetricValueBadge: View {
    let text: String
    var width: CGFloat

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.86))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(width: width, alignment: .trailing)
    }
}

struct ProcessRow: View {
    let stat: ProcessNetStat

    var body: some View {
        HStack(spacing: 10) {
            AppIconView(pid: stat.pid, fallbackName: stat.name, bundlePath: stat.bundlePath)
            Text(appDisplayName)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            MetricValueBadge(text: format(stat.downKBps), width: processRateColumnWidth)
            MetricValueBadge(text: format(stat.upKBps), width: processRateColumnWidth)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .dashboardPanel(fillOpacity: 0.055, strokeOpacity: 0.075, cornerRadius: 12, shadow: false)
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

private let processRateColumnWidth: CGFloat = 62

struct ProcessMemoryRow: View {
    let stat: ProcessMemStat

    var body: some View {
        HStack(spacing: 10) {
            AppIconView(pid: stat.pid, fallbackName: stat.name, bundlePath: stat.bundlePath)
            Text(appDisplayName)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .lineLimit(1)
            Spacer()
            MetricValueBadge(text: formatBytes(stat.memoryBytes), width: 72)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .dashboardPanel(fillOpacity: 0.055, strokeOpacity: 0.075, cornerRadius: 12, shadow: false)
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
            .frame(width: 18, height: 18)
            .cornerRadius(4)
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
    var showsBackground: Bool = true
    var showsHeader: Bool = true

    private let readColor = Color.pink
    private let writeColor = Color.blue

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsHeader {
                DashboardCardHeader(
                    title: "Disk",
                    subtitle: "Storage throughput",
                    value: throughputValue,
                    accent: .blue,
                    icon: "internaldrive.fill"
                )
            }

            VStack(alignment: .leading, spacing: 14) {
                if let detail = metricsStore.diskDetail {
                    DiskUsageRingView(volume: detail.volume)
                        .frame(maxWidth: .infinity, alignment: .center)
                    DiskCapacityLegend(volume: detail.volume)
                        .frame(maxWidth: .infinity)
                } else {
                    placeholderPanel(
                        title: "Disk details are loading",
                        message: "Capacity and volume breakdown will appear after the first disk sample arrives."
                    )
                }
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
                    bucketInterval: bucketInterval,
                    valueFormatter: { formatNetworkRate(bytesPerSecond: $0) }
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
        .modifier(ConditionalDashboardCardBackground(isEnabled: showsBackground))
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

struct DiskUsageRingView: View {
    let volume: DiskVolumeStat
    private let size: CGFloat = 200
    private let segmentGap: Double = 0.014
    private let minimumVisibleFraction: Double = 0.02

    private var ringWidth: CGFloat {
        size >= 190 ? 15 : 12
    }

    private var valueFontSize: CGFloat {
        size >= 190 ? 26 : 18
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: ringWidth)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.blue.opacity(0.18), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.32
                    )
                )

            ForEach(segments.indices, id: \.self) { index in
                let segment = segments[index]
                Circle()
                    .trim(from: adjustedStart(for: segment), to: adjustedEnd(for: segment))
                    .stroke(segment.color, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: segment.color.opacity(0.18), radius: 4)
            }

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(ringWidth + 6)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                        .padding(ringWidth + 6)
                )

            VStack(spacing: 2) {
                Text(String(format: "%.0f%%", volume.usedPercent))
                    .font(.system(size: valueFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("USED")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .tracking(1.1)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 7)
    }

    private var segments: [Segment] {
        let total = max(Double(volume.totalBytes), 1)
        let rawSegments: [(value: Double, color: Color)] = [
            (Double(volume.usedBytes) / total, .blue),
            (Double(volume.purgeableBytes) / total, .pink),
            (Double(volume.freeBytes) / total, .gray)
        ]

        let nonZeroCount = rawSegments.filter { $0.value > 0 }.count
        let minimumBudget = Double(nonZeroCount) * minimumVisibleFraction
        let normalizedSegments: [(value: Double, color: Color)]
        if nonZeroCount > 0, minimumBudget < 1 {
            let expandableTotal = rawSegments
                .filter { $0.value > minimumVisibleFraction }
                .reduce(0.0) { $0 + $1.value }
            let remaining = max(1 - minimumBudget, 0)

            normalizedSegments = rawSegments.map { segment in
                guard segment.value > 0 else { return (0, segment.color) }
                if segment.value <= minimumVisibleFraction {
                    return (minimumVisibleFraction, segment.color)
                }

                guard expandableTotal > 0 else { return (minimumVisibleFraction, segment.color) }
                let scaledValue = remaining * (segment.value / expandableTotal)
                return (max(scaledValue, minimumVisibleFraction), segment.color)
            }
        } else {
            normalizedSegments = rawSegments
        }

        var start = 0.0
        return normalizedSegments.map { segment in
            let end = min(start + segment.value, 1)
            defer { start = end }
            return Segment(start: start, end: end, color: segment.color)
        }
    }

    private func adjustedStart(for segment: Segment) -> Double {
        min(segment.start + segmentGap / 2, segment.end)
    }

    private func adjustedEnd(for segment: Segment) -> Double {
        max(segment.end - segmentGap / 2, segment.start)
    }

    private struct Segment {
        let start: Double
        let end: Double
        let color: Color
    }
}

struct DiskCapacityLegend: View {
    let volume: DiskVolumeStat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CAPACITY BREAKDOWN")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .tracking(1.2)

            VStack(spacing: 6) {
                DiskLegendRow(color: .blue, title: "Used", value: formatBytes(volume.usedBytes))
                DiskLegendRow(color: .pink, title: "Purgeable", value: formatBytes(volume.purgeableBytes))
                DiskLegendRow(color: Color.white.opacity(0.35), title: "Free", value: formatBytes(volume.freeBytes))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 8)
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
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
                .shadow(color: color.opacity(0.28), radius: 4)

            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 2)
    }
}

struct DiskRateMetric: View {
    let title: String
    let value: Double?
    let color: Color
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(formatRate(value))
                .font(.system(size: compact ? 18 : 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            HStack(spacing: compact ? 6 : 8) {
                Circle()
                    .fill(color)
                    .frame(width: compact ? 8 : 10, height: compact ? 8 : 10)
                Text(title)
                    .font(.system(size: compact ? 13 : 16, weight: .semibold, design: .rounded))
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
                .frame(width: 62, alignment: .trailing)
            Text("Write/s")
                .frame(width: 62, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .bold, design: .rounded))
        .foregroundStyle(.white.opacity(0.58))
        .tracking(1)
        .padding(.horizontal, 4)
    }
}

struct ProcessDiskRow: View {
    let stat: ProcessDiskStat

    var body: some View {
        HStack(spacing: 10) {
            AppIconView(pid: stat.pid, fallbackName: stat.name, bundlePath: stat.bundlePath)
            Text(appDisplayName)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .lineLimit(1)
            Spacer()
            MetricValueBadge(text: format(stat.readBytesPerSecond), width: 62)
            MetricValueBadge(text: format(stat.writeBytesPerSecond), width: 62)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .dashboardPanel(fillOpacity: 0.055, strokeOpacity: 0.075, cornerRadius: 12, shadow: false)
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
    let batteryHistory: [BatteryHistorySample]
    var showsBackground: Bool = true
    var showsHeader: Bool = true

    private var isCompactLayout: Bool { !showsBackground }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsHeader {
                DashboardCardHeader(
                    title: "Battery",
                    subtitle: "Power source and health",
                    value: batteryHeaderValue,
                    accent: .green,
                    icon: "battery.100percent"
                )
            }

            if metricsStore.batteryDetail == nil {
                EmptyStatePanel(
                    icon: "battery.100percent",
                    title: "Battery telemetry unavailable",
                    message: "This Mac may still be gathering battery details, or the current hardware does not expose them."
                )
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    BatteryRingPanel(
                        percent: metricsStore.batteryDetail?.percent,
                        healthPercent: metricsStore.batteryDetail?.healthPercent,
                        status: batteryStatus,
                        compact: isCompactLayout
                    )

                    BatteryLevelPanel(
                        history: batteryHistory,
                        isCharging: metricsStore.batteryDetail?.isCharging ?? false,
                        isExternalPowerConnected: metricsStore.batteryDetail?.isExternalPowerConnected ?? false,
                        status: batteryStatus,
                        range: range,
                        bucketInterval: bucketInterval
                    )

                    BatteryModeRow(mode: batteryModeText)

                    BatterySignificantEnergyRow(app: metricsStore.significantEnergyApp)

                    batteryDetailsGrid
                }
            }
        }
        .padding(16)
        .modifier(ConditionalDashboardCardBackground(isEnabled: showsBackground))
    }

    private var powerAdapterRows: [BatteryStatRow] {
        guard let detail = metricsStore.batteryDetail else { return [] }
        return [
            BatteryStatRow(title: "Status", value: batteryStatus.label),
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

    private var batteryStatus: BatteryDisplayStatus {
        guard let detail = metricsStore.batteryDetail else { return .unknown }
        if detail.isExternalPowerConnected && detail.percent >= 99.5 {
            return .connected
        }
        if detail.isCharging {
            return .charging
        }
        if detail.isExternalPowerConnected {
            return .connected
        }
        return .battery
    }

    private var batteryHeaderValue: String {
        guard let detail = metricsStore.batteryDetail else { return "--" }
        return String(format: "%.0f%% · %@", detail.percent, batteryStatus.shortLabel)
    }

    @ViewBuilder
    private var batteryDetailsGrid: some View {
        let columns = isCompactLayout
        ? [GridItem(.flexible(), spacing: 14)]
        : [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

        LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
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
    var showsBackground: Bool = true
    var showsHeader: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsHeader {
                DashboardCardHeader(
                    title: "CPU Temp",
                    subtitle: "Thermal and fan telemetry",
                    value: formatTemperature(metricsStore.latestValue(.cpuTemperature)),
                    accent: .orange,
                    icon: "thermometer.medium"
                )
            }

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
        .modifier(ConditionalDashboardCardBackground(isEnabled: showsBackground))
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
    let status: BatteryDisplayStatus
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 12 : 18) {
            BatteryLargeRingView(
                value: percent ?? 0,
                title: "BATTERY",
                icon: status.icon,
                colors: status.ringColors,
                compact: compact
            )
            BatteryLargeRingView(value: healthPercent ?? 0, title: "HEALTH", icon: nil, colors: [.pink, .pink], compact: compact)
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
    var compact: Bool = false

    private var ringWidth: CGFloat { compact ? 10 : 12 }
    private var size: CGFloat { compact ? 132 : 150 }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.white.opacity(0.12), lineWidth: ringWidth)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [(colors.first ?? .blue).opacity(0.18), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 56
                    )
                )
            Circle()
                .trim(from: 0, to: CGFloat(min(max(value / 100, 0), 1)))
                .stroke(
                    AngularGradient(colors: colors, center: .center),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: (colors.first ?? .blue).opacity(0.26), radius: 8)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(ringWidth + 8)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                        .padding(ringWidth + 8)
                )

            VStack(spacing: 2) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: compact ? 16 : 18, weight: .semibold))
                        .foregroundStyle(colors.first ?? .white)
                }
                Text(String(format: "%.0f%%", value))
                    .font(.system(size: compact ? 24 : 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(title)
                    .font(.system(size: compact ? 11 : 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(12)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 8)
    }
}

struct BatteryLevelPanel: View {
    let history: [BatteryHistorySample]
    let isCharging: Bool
    let isExternalPowerConnected: Bool
    let status: BatteryDisplayStatus
    let range: TimeInterval
    let bucketInterval: TimeInterval

    var body: some View {
        VStack(spacing: 10) {
            if history.isEmpty {
                EmptyStatePanel(
                    icon: "chart.bar.fill",
                    title: "No battery history yet",
                    message: "Charge level history will fill in after a few fresh samples.",
                    minHeight: 110
                )
            } else {
                BatteryHistoryChartView(
                    history: history,
                    range: range,
                    bucketInterval: bucketInterval
                )
            }

            RoundedRectangle(cornerRadius: 5)
                .fill(
                    LinearGradient(
                        colors: status.barColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 16)
                .overlay(
                    HStack(spacing: 8) {
                        Image(systemName: status.icon)
                            .font(.system(size: 14, weight: .bold))
                        Text(status.label)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(0.6)
                    }
                    .foregroundStyle(.white)
                )
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.04))
        .cornerRadius(18)
    }
}

enum BatteryDisplayStatus {
    case charging
    case connected
    case battery
    case unknown

    var label: String {
        switch self {
        case .charging:
            return "Charging"
        case .connected:
            return "Power Adapter"
        case .battery:
            return "On Battery"
        case .unknown:
            return "Unknown"
        }
    }

    var shortLabel: String {
        switch self {
        case .charging:
            return "Charging"
        case .connected:
            return "Plugged In"
        case .battery:
            return "Battery"
        case .unknown:
            return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .charging:
            return "bolt.fill"
        case .connected:
            return "powerplug.fill"
        case .battery:
            return "battery.100"
        case .unknown:
            return "questionmark"
        }
    }

    var ringColors: [Color] {
        switch self {
        case .charging:
            return [.green, .mint, .cyan]
        case .connected:
            return [.blue, .cyan, .blue]
        case .battery:
            return [.green, .teal, .mint]
        case .unknown:
            return [.gray, .gray]
        }
    }

    var barColors: [Color] {
        switch self {
        case .charging:
            return [.green, .mint]
        case .connected:
            return [.blue, .cyan]
        case .battery:
            return [Color.white.opacity(0.26), Color.white.opacity(0.18)]
        case .unknown:
            return [Color.white.opacity(0.16), Color.white.opacity(0.12)]
        }
    }
}

struct BatteryHistoryChartView: View {
    let history: [BatteryHistorySample]
    let range: TimeInterval
    let bucketInterval: TimeInterval

    @State private var hoverIndex: Int?
    @State private var hoverLocationX: CGFloat?

    private let barWidth: CGFloat = 4
    private let barSpacing: CGFloat = 2

    var body: some View {
        GeometryReader { proxy in
            let layout = bucketedValues(width: proxy.size.width)

            ZStack(alignment: .topLeading) {
                if let hoverLocationX {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 3, height: proxy.size.height)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .offset(x: hoverLocationX - 1.5)
                }

                VStack(spacing: 10) {
                    HStack(alignment: .bottom, spacing: 2) {
                        Spacer(minLength: 0)
                        ForEach(Array(layout.enumerated()), id: \.offset) { index, item in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(item.hasData ? item.barColor : Color.clear)
                                .frame(width: barWidth, height: item.hasData ? max(110 * CGFloat(item.percent / 100), 4) : 0)
                                .opacity(hoverIndex == index ? 1 : 0.96)
                        }
                    }
                    .frame(height: 110, alignment: .bottomLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                if let tooltipIndex = tooltipIndex(in: layout),
                   let hoverLocationX {
                    BatteryHistoryTooltip(item: layout[tooltipIndex])
                        .position(x: tooltipX(for: hoverLocationX, width: proxy.size.width), y: 14)
                        .allowsHitTesting(false)
                        .zIndex(2)
                }

                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover(coordinateSpace: .local) { phase in
                        switch phase {
                        case .active(let location):
                            updateHoverState(locationX: location.x, width: proxy.size.width, itemCount: layout.count)
                        case .ended:
                            hoverIndex = nil
                            hoverLocationX = nil
                        }
                    }
            }
        }
        .frame(height: 110)
    }

    private func bucketedValues(width: CGFloat) -> [BatteryHistoryBucket] {
        let end = alignedEndDate()
        let start = end.addingTimeInterval(-range)
        let baseBucketCount = max(Int(range / max(bucketInterval, 1)), 1)
        let step = max(bucketInterval, 1)
        var buckets = Array(repeating: [BatteryHistorySample](), count: baseBucketCount)

        for sample in history where sample.timestamp >= start && sample.timestamp <= end {
            let offset = sample.timestamp.timeIntervalSince(start)
            let index = min(max(Int(offset / step), 0), baseBucketCount - 1)
            buckets[index].append(sample)
        }

        let maxBars = max(Int(width / (barWidth + barSpacing)), 1)
        let groupSize = max(Int(ceil(Double(baseBucketCount) / Double(maxBars))), 1)

        return stride(from: 0, to: baseBucketCount, by: groupSize).map { startIndex in
            let endIndex = min(startIndex + groupSize, baseBucketCount)
            let groupedSamples = buckets[startIndex..<endIndex].flatMap { $0 }
            let bucketTimestamp = start.addingTimeInterval(step * Double(endIndex))

            guard !groupedSamples.isEmpty else {
                return BatteryHistoryBucket(
                    timestamp: nil,
                    percent: 0,
                    isCharging: false,
                    isExternalPowerConnected: false,
                    hasData: false
                )
            }

            let latest = groupedSamples.max(by: { $0.timestamp < $1.timestamp }) ?? groupedSamples[0]
            let latestPercent = latest.percent
            let averagePower = groupedSamples.reduce(0) { $0 + ($1.isExternalPowerConnected ? 1.0 : 0.0) } / Double(groupedSamples.count)
            let averageCharging = groupedSamples.reduce(0) { partial, sample in
                partial + ((sample.isCharging && sample.percent < 99.5) ? 1.0 : 0.0)
            } / Double(groupedSamples.count)

            return BatteryHistoryBucket(
                timestamp: bucketTimestamp,
                percent: latestPercent,
                isCharging: averageCharging >= 0.5,
                isExternalPowerConnected: averagePower >= 0.5,
                hasData: true
            )
        }
    }

    private func alignedEndDate() -> Date {
        alignBatteryChartToClockBoundary(history.last?.timestamp ?? Date(), interval: bucketInterval)
    }

    private func updateHoverState(locationX: CGFloat, width: CGFloat, itemCount: Int) {
        guard itemCount > 0 else {
            hoverIndex = nil
            hoverLocationX = nil
            return
        }

        let totalWidth = CGFloat(itemCount) * barWidth + CGFloat(max(itemCount - 1, 0)) * barSpacing
        let leftOffset = max(width - totalWidth, 0)
        let clampedLineX = min(max(locationX, 0), width)
        hoverLocationX = clampedLineX

        guard locationX >= leftOffset, locationX <= leftOffset + totalWidth else {
            hoverIndex = nil
            return
        }

        let relativeX = locationX - leftOffset
        let index = min(max(Int(relativeX / (barWidth + barSpacing)), 0), itemCount - 1)
        hoverIndex = index
    }

    private func tooltipX(for hoverLocationX: CGFloat, width: CGFloat) -> CGFloat {
        min(max(hoverLocationX, 72), max(width - 72, 72))
    }

    private func tooltipIndex(in layout: [BatteryHistoryBucket]) -> Int? {
        guard let hoverIndex else { return nil }
        guard hoverIndex < layout.count else { return nil }
        if layout[hoverIndex].hasData { return hoverIndex }

        for distance in 1..<layout.count {
            let leftIndex = hoverIndex - distance
            if leftIndex >= 0, layout[leftIndex].hasData {
                return leftIndex
            }

            let rightIndex = hoverIndex + distance
            if rightIndex < layout.count, layout[rightIndex].hasData {
                return rightIndex
            }
        }

        return nil
    }
}

private struct BatteryHistoryBucket {
    let timestamp: Date?
    let percent: Double
    let isCharging: Bool
    let isExternalPowerConnected: Bool
    let hasData: Bool

    var barColor: Color {
        if isCharging {
            return Color.green.opacity(0.95)
        }
        return isExternalPowerConnected ? Color.blue.opacity(0.95) : Color.pink.opacity(0.95)
    }

    var statusText: String {
        if isCharging {
            return "Charging"
        }
        return isExternalPowerConnected ? "Power" : "Battery"
    }
}

private struct BatteryHistoryTooltip: View {
    let item: BatteryHistoryBucket

    var body: some View {
        VStack(spacing: 2) {
            Text(timeText)
            Text(String(format: "%.0f%% · %@", item.percent, item.statusText))
        }
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private var timeText: String {
        guard let timestamp = item.timestamp else { return "--" }
        return Self.timeFormatter.string(from: timestamp)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

private func alignBatteryChartToClockBoundary(_ date: Date, interval: TimeInterval) -> Date {
    let interval = max(interval, 1)
    let calendar = Calendar.current

    if interval < 60 {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let secondInterval = max(Int(interval.rounded()), 1)
        let second = components.second ?? 0
        components.second = (second / secondInterval) * secondInterval
        return calendar.date(from: components) ?? date
    }

    if interval < 3600 {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minuteInterval = max(Int((interval / 60).rounded()), 1)
        let minute = components.minute ?? 0
        components.minute = (minute / minuteInterval) * minuteInterval
        components.second = 0
        return calendar.date(from: components) ?? date
    }

    var components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
    let hourInterval = max(Int((interval / 3600).rounded()), 1)
    let hour = components.hour ?? 0
    components.hour = (hour / hourInterval) * hourInterval
    components.minute = 0
    components.second = 0
    return calendar.date(from: components) ?? date
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
    var showsBackground: Bool = true
    var showsHeader: Bool = true

    private var isCompactLayout: Bool {
        !showsBackground && !showsHeader
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsHeader {
                DashboardCardHeader(
                    title: "Memory",
                    subtitle: "Pressure and allocation mix",
                    value: formattedValue,
                    accent: .cyan,
                    icon: "memorychip.fill"
                )
            }

            if let detail = metricsStore.memoryDetail {
                GeometryReader { proxy in
                    let spacing: CGFloat = isCompactLayout ? 16 : 18
                    let minRingSize: CGFloat = isCompactLayout ? 128 : 148
                    let maxRingSize: CGFloat = isCompactLayout ? 152 : 206
                    let availableWidth = max(proxy.size.width - spacing, 0)
                    let ringSize = min(max(availableWidth / 2, minRingSize), maxRingSize)
                    let pressureSize = ringSize
                    let summarySize = ringSize

                    HStack(alignment: .center, spacing: spacing) {
                        RingGaugeView(
                            value: detail.pressurePercent,
                            label: "PRESSURE",
                            colors: [.blue, .cyan, .blue],
                            size: pressureSize,
                            lineWidth: isCompactLayout ? 11 : (pressureSize >= 190 ? 15 : 13),
                            valueFontSize: isCompactLayout ? 22 : (pressureSize >= 190 ? 30 : 26)
                        )
                        .frame(maxWidth: .infinity)

                        MemorySummaryRingView(
                            appBytes: detail.appBytes,
                            wiredBytes: detail.wiredBytes,
                            compressedBytes: detail.compressedBytes,
                            freeBytes: detail.freeBytes,
                            usedPercent: detail.usedPercent,
                            size: summarySize
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .frame(height: isCompactLayout ? 176 : 220)
                .padding(.top, isCompactLayout ? 0 : 2)

                MemoryLegendPanel(detail: detail)
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
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
        .modifier(ConditionalDashboardCardBackground(isEnabled: showsBackground))
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
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
                .shadow(color: color.opacity(0.28), radius: 4)

            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 2)
    }
}

struct MemoryLegendPanel: View {
    let detail: MemoryDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MEMORY BREAKDOWN")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .tracking(1.2)

            VStack(spacing: 6) {
                MemoryLegendRow(color: .blue, title: "App", value: formatBytes(detail.appBytes))
                MemoryLegendRow(color: .orange, title: "Wired", value: formatBytes(detail.wiredBytes))
                MemoryLegendRow(color: .yellow, title: "Compressed", value: formatBytes(detail.compressedBytes))
                MemoryLegendRow(color: .gray, title: "Free", value: formatBytes(detail.freeBytes))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 7)
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

struct MemorySummaryRingView: View {
    let appBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let freeBytes: UInt64
    let usedPercent: Double
    var size: CGFloat = 132
    private let segmentGap: Double = 0.014

    private var ringWidth: CGFloat {
        size >= 190 ? 15 : 12
    }

    private var valueFontSize: CGFloat {
        size >= 190 ? 26 : 18
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: ringWidth)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.cyan.opacity(0.18), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.32
                    )
                )

            ForEach(segments.indices, id: \.self) { index in
                let segment = segments[index]
                Circle()
                    .trim(from: adjustedStart(for: segment), to: adjustedEnd(for: segment))
                    .stroke(segment.color, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: segment.color.opacity(0.18), radius: 4)
            }

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(ringWidth + 6)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                        .padding(ringWidth + 6)
                )

            VStack(spacing: 2) {
                Text(String(format: "%.0f%%", usedPercent))
                    .font(.system(size: valueFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("USED")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .tracking(1.1)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 7)
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

    private func adjustedStart(for segment: Segment) -> Double {
        min(segment.start + segmentGap / 2, segment.end)
    }

    private func adjustedEnd(for segment: Segment) -> Double {
        max(segment.end - segmentGap / 2, segment.start)
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
            popupHeader
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

    private var popupHeader: some View {
        HStack(spacing: 10) {
            MetricGlyph(symbol: section.icon, accent: section.accent, size: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(section.rawValue)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Live detail view")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(section.accent)
                    .frame(width: 6, height: 6)
                    .shadow(color: section.accent.opacity(0.7), radius: 5)

                Text("Live")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.74))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(section.accent.opacity(0.14))
            .overlay(
                Capsule()
                    .stroke(section.accent.opacity(0.3), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 1)
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
                bucketInterval: selectedRange.bucketInterval,
                showsBackground: false,
                showsHeader: false
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
                compressedSeries: filteredSeries(.memoryCompressedBytes),
                showsBackground: false,
                showsHeader: false
            )
        case .disk:
            DiskCardView(
                range: selectedRange.duration,
                bucketInterval: selectedRange.bucketInterval,
                readSeries: filteredSeries(.diskReadBytesPerSecond),
                writeSeries: filteredSeries(.diskWriteBytesPerSecond),
                showsBackground: false,
                showsHeader: false
            )
        case .network:
            networkPopupCard
        case .temperature:
            CPUTemperatureCardView(
                range: selectedRange.duration,
                bucketInterval: selectedRange.bucketInterval,
                temperatureSeries: filteredSeries(.cpuTemperature),
                showsBackground: false,
                showsHeader: false
            )
        case .battery:
            BatteryCardView(
                range: selectedRange.duration,
                bucketInterval: selectedRange.bucketInterval,
                batteryHistory: filteredBatteryHistory(),
                showsBackground: false,
                showsHeader: false
            )
        }
    }

    private var networkPopupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 18) {
                    DiskRateMetric(title: "Upload", value: kbpsToBytes(metricsStore.latestValue(.networkUpKBps)), color: .pink, compact: true)
                    DiskRateMetric(title: "Download", value: kbpsToBytes(metricsStore.latestValue(.networkDownKBps)), color: .blue, compact: true)
                }

                DualBarChartView(
                    upSamples: filteredSeries(.networkUpKBps),
                    downSamples: filteredSeries(.networkDownKBps),
                    upColor: .pink,
                    downColor: .blue,
                    range: selectedRange.duration,
                    bucketInterval: selectedRange.bucketInterval,
                    valueFormatter: { formatNetworkRate(kilobytesPerSecond: $0) }
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
                    .font(.system(size: 13, weight: .medium, design: .rounded))
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
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 6)
            }

            SectionHeader(title: "PUBLIC IP ADDRESSES")
            if let publicIPv4 = metricsStore.ipInfo.publicIPv4, !publicIPv4.isEmpty {
                HStack {
                    Text(publicIPv4)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
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
        case .battery, .disk, .memory, .network:
            return 340
        default:
            return 340
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

    private func filteredBatteryHistory() -> [BatteryHistorySample] {
        let cutoff = Date().addingTimeInterval(-selectedRange.duration)
        return metricsStore.batteryHistory(from: cutoff)
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
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(fillOpacity + 0.025),
                            Color.white.opacity(fillOpacity * 0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(strokeOpacity), lineWidth: 1)
                )
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.07), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: max(30, cornerRadius * 1.4))
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
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

private struct ConditionalDashboardCardBackground: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            AnyView(content.dashboardCardBackground())
        } else {
            AnyView(content)
        }
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
