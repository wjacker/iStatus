import SwiftUI
import AppKit

final class AppServices {
    static let shared = AppServices()

    let metricsStore = MetricsStore()
    let menuBarSettings = MenuBarSettingsStore()
    lazy var windowController = AppWindowController(services: self)

    private init() {}
}

final class StatusBarController: NSObject {
    private let services: AppServices
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var eventMonitor: Any?

    init(services: AppServices) {
        self.services = services
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
        configurePopover()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: "iStatus")
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 260, height: 300)
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(
                onOpenDashboard: { [weak self] in self?.openDashboard() },
                onOpenMenuSettings: { [weak self] in self?.openMenuSettings() },
                onQuit: { NSApp.terminate(nil) }
            )
            .environmentObject(services.metricsStore)
            .environmentObject(services.menuBarSettings)
        )
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }

    private func showPopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        startEventMonitor()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
        stopEventMonitor()
    }

    private func startEventMonitor() {
        stopEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover(nil)
        }
    }

    private func stopEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private func openDashboard() {
        closePopover(nil)
        services.windowController.showDashboard()
    }

    private func openMenuSettings() {
        closePopover(nil)
        services.windowController.showMenuSettings()
    }
}

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
            window.center()
            window.contentViewController = controller
            dashboardWindow = window
        }

        dashboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
            window.center()
            window.contentViewController = controller
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController(services: AppServices.shared)
    }
}
