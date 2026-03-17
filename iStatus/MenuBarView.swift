import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject private var metricsStore: MetricsStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("iStatus")
                    .font(.headline)
                Spacer()
                Button("Open Dashboard") {
                    openWindow(id: "dashboard")
                    NSApp.activate(ignoringOtherApps: true)
                    dismiss()
                }
            }

            Divider()

            MenuMetricRow(title: "CPU", value: metricsStore.latestValue(.cpuUsage))
            MenuMetricRow(title: "Memory", value: metricsStore.latestValue(.memoryUsedPercent))
            MenuMetricRow(title: "Disk", value: metricsStore.latestValue(.diskUsedPercent))
            MenuMetricRow(title: "Network", value: metricsStore.latestValue(.networkTotalKBps), suffix: "KB/s")
            MenuMetricRow(title: "GPU", value: metricsStore.latestValue(.gpuUsage))
            MenuMetricRow(title: "Battery", value: metricsStore.latestValue(.batteryPercent))

            Divider()

            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 260)
    }
}

struct MenuBarStatusView: View {
    @EnvironmentObject private var metricsStore: MetricsStore

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
            Text("CPU \(formatPercent(metricsStore.latestValue(.cpuUsage)))")
            Text("MEM \(formatPercent(metricsStore.latestValue(.memoryUsedPercent)))")
            Text("NET \(formatRate(metricsStore.latestValue(.networkTotalKBps)))")
        }
        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
        .padding(.vertical, 2)
    }

    private func formatPercent(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.0f%%", value)
    }

    private func formatRate(_ value: Double?) -> String {
        guard let value else { return "--" }
        if value > 1024 {
            return String(format: "%.1fMB/s", value / 1024)
        }
        return String(format: "%.0fKB/s", value)
    }
}

struct MenuMetricRow: View {
    let title: String
    let value: Double?
    var suffix: String = "%"

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(format(value))
                .font(.system(.body, design: .monospaced))
        }
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.0f%@", value, suffix)
    }
}
