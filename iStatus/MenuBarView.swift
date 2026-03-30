import SwiftUI
import AppKit

enum MenuBarMetricItem: String, CaseIterable, Identifiable {
    case network
    case disk
    case cpu
    case memory
    case temperature
    case battery

    var id: String { rawValue }

    static var visibleCases: [MenuBarMetricItem] {
        [.network, .disk, .cpu, .memory, .temperature, .battery]
    }

    var title: String {
        switch self {
        case .network: return "Network"
        case .disk: return "Disk"
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .temperature: return "CPU Temp"
        case .battery: return "Battery"
        }
    }

    var icon: String {
        switch self {
        case .network: return "arrow.up.arrow.down"
        case .disk: return "internaldrive"
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .temperature: return "thermometer.medium"
        case .battery: return "battery.100"
        }
    }

    var accent: Color {
        switch self {
        case .network: return .mint
        case .disk: return .blue
        case .cpu: return .pink
        case .memory: return .cyan
        case .temperature: return .orange
        case .battery: return .green
        }
    }

    var storageKey: String {
        "menu_bar_item_\(rawValue)"
    }

    var defaultEnabled: Bool {
        switch self {
        case .network, .disk, .cpu, .memory, .battery:
            return true
        case .temperature:
            return false
        }
    }
}

struct StatusBarStripSegment: Identifiable {
    enum Kind {
        case network(up: String, down: String)
        case metric(title: String, value: String)
    }

    let id = UUID()
    let kind: Kind
}

@MainActor
final class MenuBarSettingsStore: ObservableObject {
    @Published private var enabledItems: [MenuBarMetricItem: Bool] = [:]

    init() {
        MenuBarMetricItem.allCases.forEach { item in
            if UserDefaults.standard.object(forKey: item.storageKey) == nil {
                enabledItems[item] = item.defaultEnabled
            } else {
                enabledItems[item] = UserDefaults.standard.bool(forKey: item.storageKey)
            }
        }
    }

    func isEnabled(_ item: MenuBarMetricItem) -> Bool {
        enabledItems[item] ?? item.defaultEnabled
    }

    func setEnabled(_ enabled: Bool, for item: MenuBarMetricItem) {
        var updated = enabledItems
        updated[item] = enabled
        enabledItems = updated
        UserDefaults.standard.set(enabled, forKey: item.storageKey)
    }

    var enabledItemsPublisher: Published<[MenuBarMetricItem: Bool]>.Publisher {
        $enabledItems
    }

    var activeItems: [MenuBarMetricItem] {
        MenuBarMetricItem.visibleCases.filter { isEnabled($0) }
    }
}

struct MenuBarView: View {
    @EnvironmentObject private var metricsStore: MetricsStore
    @EnvironmentObject private var menuBarSettings: MenuBarSettingsStore
    let onOpenDashboard: () -> Void
    let onOpenMenuSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("iStatus")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Label("Live", systemImage: "dot.radiowaves.left.and.right")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.mint.opacity(0.2))
                        .overlay(
                            Capsule()
                                .stroke(Color.mint.opacity(0.45), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                        .foregroundStyle(.mint)
                }

                Text("A cleaner snapshot of your Mac, right from the menu bar.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(14)
            .menuPanel(fillOpacity: 0.14, strokeOpacity: 0.12)

            HStack(spacing: 10) {
                Button {
                    onOpenDashboard()
                } label: {
                    Label("Open Dashboard", systemImage: "rectangle.stack.fill")
                        .frame(maxWidth: .infinity)
                }

                Button {
                    onOpenMenuSettings()
                } label: {
                    Label("Menu Bar Settings", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(MenuBarActionButtonStyle())

            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Metrics")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .tracking(1)

                MenuMetricRow(title: "CPU", value: metricsStore.latestValue(.cpuUsage), accent: .pink)
                MenuMetricRow(title: "Memory", value: metricsStore.latestValue(.memoryUsedPercent), accent: .cyan)
                MenuMetricRow(title: "Disk", value: metricsStore.latestValue(.diskUsedPercent), accent: .blue)
                MenuMetricRow(title: "Network", value: metricsStore.latestValue(.networkTotalKBps), suffix: "KB/s", accent: .mint)
                MenuMetricRow(title: "Battery", value: metricsStore.latestValue(.batteryPercent), accent: .green)
            }
            .padding(14)
            .menuPanel(fillOpacity: 0.1, strokeOpacity: 0.1)

            Button {
                onQuit()
            } label: {
                Label("Quit", systemImage: "power")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(MenuBarActionButtonStyle(tint: Color.red.opacity(0.88)))
        }
        .padding(14)
        .frame(width: 248)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.10, blue: 0.18),
                    Color(red: 0.03, green: 0.05, blue: 0.11)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct MenuBarStatusView: View {
    var body: some View {
        Image(systemName: "waveform.path.ecg")
            .font(.system(size: 11, weight: .semibold))
            .frame(width: 16, height: 12)
    }
}

struct MenuBarStatusChip: View {
    let text: String

    var body: some View {
        Text(text)
            .fixedSize()
    }
}

struct StatusBarStripView: View {
    let segments: [StatusBarStripSegment]
    var useCompactPadding: Bool = false
    var showsBackground: Bool = true

    var body: some View {
        HStack(alignment: .center, spacing: useCompactPadding ? 8 : 10) {
            ForEach(segments) { segment in
                switch segment.kind {
                case let .network(up, down):
                    NetworkStripBlock(up: up, down: down)
                case let .metric(title, value):
                    MetricStripBlock(title: title, value: value)
                }
            }
        }
        .padding(.horizontal, useCompactPadding ? 4 : 8)
        .padding(.vertical, useCompactPadding ? 1 : 5)
        .background(backgroundShape)
    }

    @ViewBuilder
    private var backgroundShape: some View {
        if showsBackground {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(nsColor: NSColor(calibratedRed: 0.44, green: 0.46, blue: 0.57, alpha: 0.94)))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
                )
        } else {
            Color.clear
        }
    }
}

private struct NetworkStripBlock: View {
    let up: String
    let down: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            StripValueLine(symbol: "↑", value: up)
            StripValueLine(symbol: "↓", value: down)
        }
    }
}

private struct StripValueLine: View {
    let symbol: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(symbol)
                .font(.system(size: 7, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
            Text(value)
                .font(.system(size: 7, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize()
        }
    }
}

private struct MetricStripBlock: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Text(title)
                .font(.system(size: 6, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .tracking(0.2)
            Text(value)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize()
        }
    }
}

struct MenuBarSettingsView: View {
    @EnvironmentObject private var metricsStore: MetricsStore
    @EnvironmentObject private var menuBarSettings: MenuBarSettingsStore

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Menu Bar")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Configure which metrics appear in the menu bar preview.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Preview")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Group {
                        if previewSegments.isEmpty {
                            Text("Enable at least one item")
                                .foregroundStyle(.white.opacity(0.7))
                        } else {
                            StatusBarStripView(segments: previewSegments)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                    .menuPanel(fillOpacity: 0.08, strokeOpacity: 0.1, shadow: false)
                }

                Spacer()
            }
            .padding(22)
            .frame(width: 286)
            .background(
                LinearGradient(colors: [Color("BackgroundTop"), Color("BackgroundBottom")], startPoint: .top, endPoint: .bottom)
            )

            VStack(alignment: .leading, spacing: 16) {
                Text("Visible Items")
                    .font(.system(size: 15, weight: .bold, design: .rounded))

                ForEach(MenuBarMetricItem.visibleCases) { item in
                    Toggle(isOn: binding(for: item)) {
                        HStack(spacing: 10) {
                            Image(systemName: item.icon)
                                .frame(width: 18)
                                .foregroundStyle(item.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                Text(previewText(for: item))
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .toggleStyle(.switch)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
                            )
                    )
                }

                Spacer()
            }
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    private func binding(for item: MenuBarMetricItem) -> Binding<Bool> {
        Binding(
            get: { menuBarSettings.isEnabled(item) },
            set: { menuBarSettings.setEnabled($0, for: item) }
        )
    }

    private func previewText(for item: MenuBarMetricItem) -> String {
        switch item {
        case .network:
            return "↑\(formatRate(metricsStore.networkDetail?.upKBps))  ↓\(formatRate(metricsStore.networkDetail?.downKBps))"
        case .disk:
            return "SSD \(formatPercent(metricsStore.latestValue(.diskUsedPercent)))"
        case .cpu:
            return "CPU \(formatPercent(metricsStore.latestValue(.cpuUsage)))"
        case .memory:
            return "MEM \(formatPercent(metricsStore.latestValue(.memoryUsedPercent)))"
        case .temperature:
            return "TEMP \(formatTemperature(metricsStore.latestValue(.cpuTemperature)))"
        case .battery:
            return "BAT \(formatPercent(metricsStore.latestValue(.batteryPercent)))"
        }
    }

    private var previewSegments: [StatusBarStripSegment] {
        menuBarSettings.activeItems.map(previewSegment(for:))
    }

    private func previewSegment(for item: MenuBarMetricItem) -> StatusBarStripSegment {
        switch item {
        case .network:
            return StatusBarStripSegment(
                kind: .network(
                    up: formatRateLong(metricsStore.networkDetail?.upKBps),
                    down: formatRateLong(metricsStore.networkDetail?.downKBps)
                )
            )
        case .disk:
            return StatusBarStripSegment(kind: .metric(title: "SSD", value: formatPercent(metricsStore.latestValue(.diskUsedPercent))))
        case .cpu:
            return StatusBarStripSegment(kind: .metric(title: "CPU", value: formatPercent(metricsStore.latestValue(.cpuUsage))))
        case .memory:
            return StatusBarStripSegment(kind: .metric(title: "MEM", value: formatPercent(metricsStore.latestValue(.memoryUsedPercent))))
        case .temperature:
            return StatusBarStripSegment(kind: .metric(title: "TEMP", value: formatTemperature(metricsStore.latestValue(.cpuTemperature))))
        case .battery:
            return StatusBarStripSegment(kind: .metric(title: "BAT", value: formatPercent(metricsStore.latestValue(.batteryPercent))))
        }
    }

    private func formatPercent(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.0f%%", value)
    }

    private func formatTemperature(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.0f°C", value)
    }

    private func formatRate(_ value: Double?) -> String {
        guard let value else { return "--" }
        if value > 1024 {
            return String(format: "%.1f MB/s", value / 1024)
        }
        return String(format: "%.0f KB/s", value)
    }

    private func formatRateLong(_ value: Double?) -> String {
        guard let value else { return "--" }
        if value > 1024 {
            return String(format: "%.1f MB/s", value / 1024)
        }
        return String(format: "%.0f KB/s", value)
    }
}

struct MenuMetricRow: View {
    let title: String
    let value: Double?
    var suffix: String = "%"
    var accent: Color = .blue

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(accent)
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
            }
            Spacer()
            Text(format(value))
                .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .menuPanel(fillOpacity: 0.06, strokeOpacity: 0.08, cornerRadius: 12, shadow: false)
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.0f%@", value, suffix)
    }
}

private struct MenuBarActionButtonStyle: ButtonStyle {
    var tint: Color = Color.blue.opacity(0.9)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.vertical, 9)
            .padding(.horizontal, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.6 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private extension View {
    func menuPanel(
        fillOpacity: Double = 0.12,
        strokeOpacity: Double = 0.12,
        cornerRadius: CGFloat = 16,
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
}
