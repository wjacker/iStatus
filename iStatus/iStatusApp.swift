import SwiftUI
import AppKit
import Combine

@inline(__always)
func debugLog(_ message: String) {
    fputs("[iStatus] \(message)\n", stderr)
    fflush(stderr)
}

@main
struct iStatusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppServices {
    static let shared = AppServices()

    let metricsStore = MetricsStore()
    let menuBarSettings = MenuBarSettingsStore()
    lazy var windowController = AppWindowController(services: self)

    private init() {}
}

@MainActor
final class StatusBarController: NSObject {
    private let services: AppServices
    private var statusItems: [MenuBarMetricItem: NSStatusItem] = [:]
    private var cancellables: Set<AnyCancellable> = []
    private var buttonToItem: [ObjectIdentifier: MenuBarMetricItem] = [:]
    private var activePanelItem: MenuBarMetricItem?
    private var panelHostingController: NSHostingController<AnyView>?
    private var panel: NSPanel?
    private var outsideClickMonitor: Any?

    init(services: AppServices) {
        self.services = services
        super.init()
        syncStatusItems()
        refreshStatusItems()
        observeSettings()
    }

    private func observeSettings() {
        services.menuBarSettings.objectWillChange
            .merge(with: services.metricsStore.objectWillChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncStatusItems()
                self?.refreshStatusItems()
            }
            .store(in: &cancellables)
    }

    private func syncStatusItems() {
        let activeItems = Set(services.menuBarSettings.activeItems)

        for item in MenuBarMetricItem.allCases where activeItems.contains(item) && statusItems[item] == nil {
            let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            configureStatusItem(statusItem, for: item)
            statusItems[item] = statusItem
        }

        for item in MenuBarMetricItem.allCases where !activeItems.contains(item) {
            guard let statusItem = statusItems.removeValue(forKey: item) else { continue }
            if activePanelItem == item {
                closePanel()
            }
            if let button = statusItem.button {
                buttonToItem.removeValue(forKey: ObjectIdentifier(button))
            }
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }

    private func configureStatusItem(_ statusItem: NSStatusItem, for item: MenuBarMetricItem) {
        guard let button = statusItem.button else { return }
        button.title = ""
        button.bezelStyle = .regularSquare
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.image = buildStatusBarImage(for: item)
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp])
        buttonToItem[ObjectIdentifier(button)] = item
        statusItem.length = max(24, button.image?.size.width ?? 24)
    }

    private func openDashboard() {
        services.windowController.showDashboard()
    }

    private func openMenuSettings() {
        services.windowController.showMenuSettings()
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        guard let item = buttonToItem[ObjectIdentifier(sender)] else { return }

        if activePanelItem == item, panel?.isVisible == true {
            closePanel()
            return
        }

        showPanel(for: item, relativeTo: sender)
    }

    private func showPanel(for item: MenuBarMetricItem, relativeTo button: NSStatusBarButton) {
        let section = dashboardSection(for: item)
        let view = AnyView(
            StatusItemDetailPopoverView(section: section) { [weak self] in
                self?.closePanel()
                self?.openDashboard()
            }
            .environmentObject(services.metricsStore)
        )

        let host: NSHostingController<AnyView>
        if let existing = panelHostingController {
            existing.rootView = view
            host = existing
        } else {
            let created = NSHostingController(rootView: view)
            panelHostingController = created
            host = created
        }

        let panel = panel ?? makePanel()
        panel.contentViewController = host
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.setContentSize(host.view.fittingSize)
        position(panel: panel, below: button)
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: false)

        self.panel = panel
        self.activePanelItem = item
        installOutsideClickMonitor()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 420),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        return panel
    }

    private func position(panel: NSPanel, below button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        let buttonFrame = button.convert(button.bounds, to: nil)
        let screenFrame = buttonWindow.convertToScreen(buttonFrame)
        let panelSize = panel.frame.size
        let x = min(
            max(screenFrame.midX - (panelSize.width / 2), NSScreen.main?.visibleFrame.minX ?? 0),
            (NSScreen.main?.visibleFrame.maxX ?? screenFrame.maxX) - panelSize.width
        )
        let y = screenFrame.minY - panelSize.height - 6
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func closePanel() {
        panel?.orderOut(nil)
        activePanelItem = nil
        removeOutsideClickMonitor()
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.closePanel()
            }
        }
    }

    private func removeOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    private func refreshStatusItems() {
        for item in services.menuBarSettings.activeItems {
            guard let statusItem = statusItems[item], let button = statusItem.button else { continue }
            button.image = buildStatusBarImage(for: item)
            statusItem.length = max(24, button.image?.size.width ?? 24)
        }
    }

    private func buildStatusBarImage(for item: MenuBarMetricItem) -> NSImage? {
        let segment = statusSegment(for: item)
        let content = StatusBarStripView(
            segments: [segment],
            useCompactPadding: true,
            showsBackground: false
        )
        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        return renderer.nsImage
    }

    private func dashboardSection(for item: MenuBarMetricItem) -> DashboardSection {
        switch item {
        case .network:
            return .network
        case .disk:
            return .disk
        case .cpu:
            return .cpu
        case .memory:
            return .memory
        case .gpu:
            return .gpu
        case .battery:
            return .battery
        }
    }

    private func statusSegment(for item: MenuBarMetricItem) -> StatusBarStripSegment {
        switch item {
        case .network:
            let up = formatRateCompact(services.metricsStore.networkDetail?.upKBps, fallback: "0 KB/s")
            let down = formatRateCompact(services.metricsStore.networkDetail?.downKBps, fallback: "0 KB/s")
            return StatusBarStripSegment(kind: .network(up: up, down: down))
        case .disk:
            return StatusBarStripSegment(kind: .metric(title: "SSD", value: formatPercent(services.metricsStore.latestValue(.diskUsedPercent), fallback: "0%")))
        case .memory:
            return StatusBarStripSegment(kind: .metric(title: "MEM", value: formatPercent(services.metricsStore.latestValue(.memoryUsedPercent), fallback: "0%")))
        case .cpu:
            return StatusBarStripSegment(kind: .metric(title: "CPU", value: formatPercent(services.metricsStore.latestValue(.cpuUsage), fallback: "0%")))
        case .gpu:
            if services.metricsStore.isGPUSupported {
                return StatusBarStripSegment(kind: .metric(title: "GPU", value: formatPercent(services.metricsStore.latestValue(.gpuUsage), fallback: "0%")))
            }
            return StatusBarStripSegment(kind: .metric(title: "GPU", value: "--"))
        case .battery:
            return StatusBarStripSegment(kind: .metric(title: "BAT", value: formatPercent(services.metricsStore.latestValue(.batteryPercent), fallback: "0%")))
        }
    }

    private func formatPercent(_ value: Double?, fallback: String = "--") -> String {
        guard let value else { return fallback }
        return String(format: "%.0f%%", value)
    }

    private func formatRate(_ value: Double?, fallback: String = "--") -> String {
        guard let value else { return fallback }
        if value > 1024 {
            return String(format: "%.1f MB/s", value / 1024)
        }
        return String(format: "%.0f KB/s", value)
    }

    private func formatRateCompact(_ value: Double?, fallback: String = "--") -> String {
        guard let value else { return fallback }
        if value > 1024 {
            return String(format: "%.1f MB/s", value / 1024)
        }
        return String(format: "%.0f KB/s", value)
    }
}

@MainActor
final class AppWindowController {
    private let services: AppServices
    private var dashboardWindow: NSWindow?
    private var settingsWindow: NSWindow?

    init(services: AppServices) {
        self.services = services
    }

    func showDashboard() {
        if dashboardWindow == nil {
            let rootView = DashboardView()
                .environmentObject(services.metricsStore)
                .environmentObject(services.menuBarSettings)

            let controller = NSHostingController(rootView: rootView)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "iStatus"
            window.isReleasedWhenClosed = false
            window.center()
            window.contentViewController = controller
            dashboardWindow = window
        }

        presentWindow(dashboardWindow)
    }

    func showMenuSettings() {
        if settingsWindow == nil {
            let rootView = MenuBarSettingsView()
                .environmentObject(services.metricsStore)
                .environmentObject(services.menuBarSettings)

            let controller = NSHostingController(rootView: rootView)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 520),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Menu Bar Settings"
            window.isReleasedWhenClosed = false
            window.center()
            window.contentViewController = controller
            settingsWindow = window
        }

        presentWindow(settingsWindow)
    }

    private func presentWindow(_ window: NSWindow?) {
        guard let window else { return }
        DispatchQueue.main.async {
            window.orderFrontRegardless()
            window.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        debugLog("Application did finish launching")
        DispatchQueue.main.async { [weak self] in
            self?.statusBarController = StatusBarController(services: AppServices.shared)
            debugLog("Status bar controller initialized")
        }
    }
}
