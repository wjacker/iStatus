import SwiftUI

@main
struct iStatusApp: App {
    @StateObject private var metricsStore = MetricsStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(metricsStore)
        } label: {
            MenuBarStatusView()
                .environmentObject(metricsStore)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("iStatus", id: "dashboard") {
            DashboardView()
                .environmentObject(metricsStore)
        }
        .defaultSize(width: 900, height: 640)
    }
}
