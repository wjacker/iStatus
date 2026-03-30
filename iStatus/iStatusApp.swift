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

    private init() {
        PrivilegedHelperManager.shared.registerIfNeeded()
    }
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
        syncStatusItems(activeItems: Set(services.menuBarSettings.activeItems))
        refreshStatusItems()
        observeSettings()
    }

    private func observeSettings() {
        services.menuBarSettings.enabledItemsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] enabledItems in
                let activeItems = Set(
                    MenuBarMetricItem.visibleCases.filter { enabledItems[$0] ?? $0.defaultEnabled }
                )
                self?.syncStatusItems(activeItems: activeItems)
                self?.refreshStatusItems()
            }
            .store(in: &cancellables)

        services.metricsStore.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshStatusItems()
            }
            .store(in: &cancellables)
    }

    private func syncStatusItems(activeItems: Set<MenuBarMetricItem>) {
        for item in MenuBarMetricItem.visibleCases {
            let statusItem: NSStatusItem
            if let existing = statusItems[item] {
                statusItem = existing
            } else {
                let created = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                configureStatusItem(created, for: item)
                statusItems[item] = created
                statusItem = created
            }

            let isActive = activeItems.contains(item)
            statusItem.isVisible = isActive

            if !isActive, activePanelItem == item {
                closePanel()
            }
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
        case .temperature:
            return .temperature
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
        case .temperature:
            if services.metricsStore.isCPUTemperatureSupported {
                return StatusBarStripSegment(kind: .metric(title: "TEMP", value: formatTemperature(services.metricsStore.latestValue(.cpuTemperature), fallback: "--")))
            }
            return StatusBarStripSegment(kind: .metric(title: "TEMP", value: "--"))
        case .battery:
            return StatusBarStripSegment(kind: .metric(title: "BAT", value: formatPercent(services.metricsStore.latestValue(.batteryPercent), fallback: "0%")))
        }
    }

    private func formatPercent(_ value: Double?, fallback: String = "--") -> String {
        guard let value else { return fallback }
        return String(format: "%.0f%%", value)
    }

    private func formatTemperature(_ value: Double?, fallback: String = "--") -> String {
        guard let value else { return fallback }
        return String(format: "%.0f°C", value)
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
final class AppWindowController: NSObject, NSWindowDelegate {
    private let services: AppServices
    private var dashboardWindow: NSWindow?
    private var settingsWindow: NSWindow?

    init(services: AppServices) {
        self.services = services
        super.init()
    }

    func showDashboard() {
        if dashboardWindow == nil {
            let rootView = DashboardView()
                .environmentObject(services.metricsStore)
                .environmentObject(services.menuBarSettings)

            let controller = NSHostingController(rootView: rootView)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1280, height: 820),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "iStatus"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 1280, height: 760)
            window.contentMinSize = NSSize(width: 1280, height: 760)
            window.center()
            window.contentViewController = controller
            window.delegate = self
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
            window.delegate = self
            settingsWindow = window
        }

        presentWindow(settingsWindow)
    }

    private func presentWindow(_ window: NSWindow?) {
        guard let window else { return }
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            window.orderFrontRegardless()
            window.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.updateActivationPolicy()
        }
    }

    private func updateActivationPolicy() {
        let hasVisibleWindows = [dashboardWindow, settingsWindow].contains { window in
            guard let window else { return false }
            return window.isVisible
        }

        NSApp.setActivationPolicy(hasVisibleWindows ? .regular : .accessory)
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
