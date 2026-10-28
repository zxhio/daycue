import AppKit
import OSLog
import ServiceManagement

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let openWindow: () -> Void
    private let loginService = SMAppService.mainApp
    private let logger = Logger(subsystem: "io.github.zxhio.daycue", category: "login")
    private let launchAtLoginItem = NSMenuItem(
        title: "Launch at Login",
        action: #selector(toggleLaunchAtLogin),
        keyEquivalent: ""
    )
    private let loginSettingsItem = NSMenuItem(
        title: "Open Login Settings…",
        action: #selector(openLoginSettings),
        keyEquivalent: ""
    )

    init(openWindow: @escaping () -> Void) {
        self.openWindow = openWindow
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        statusItem.button?.title = "DayCue"
        statusItem.button?.setAccessibilityIdentifier("daycue.menu-bar")

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        let openItem = NSMenuItem(
            title: "Open DayCue…",
            action: #selector(openMainWindow),
            keyEquivalent: "o"
        )
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())

        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        loginSettingsItem.target = self
        menu.addItem(loginSettingsItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit DayCue",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApplication.shared
        menu.addItem(quitItem)
        statusItem.menu = menu
        refreshLoginItems()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshLoginItems()
    }

    @objc
    private func openMainWindow() {
        openWindow()
    }

    private func refreshLoginItems() {
        let bundleURL = Bundle.main.bundleURL
        let isReadOnly = try? bundleURL.resourceValues(forKeys: [.volumeIsReadOnlyKey]).volumeIsReadOnly
        launchAtLoginItem.isEnabled = bundleURL.pathExtension == "app" && isReadOnly != true
        launchAtLoginItem.toolTip = launchAtLoginItem.isEnabled
            ? nil : "Install DayCue before enabling launch at login."

        let status = loginService.status
        loginSettingsItem.isHidden = status != .requiresApproval

        switch status {
        case .enabled:
            launchAtLoginItem.state = .on
        case .requiresApproval:
            launchAtLoginItem.state = .mixed
            launchAtLoginItem.toolTip = "Approval required in System Settings."
        case .notRegistered, .notFound:
            launchAtLoginItem.state = .off
        @unknown default:
            launchAtLoginItem.state = .off
            launchAtLoginItem.isEnabled = false
        }
    }

    @objc
    private func toggleLaunchAtLogin() {
        do {
            switch loginService.status {
            case .enabled, .requiresApproval:
                try loginService.unregister()
            case .notRegistered, .notFound:
                try loginService.register()
                if loginService.status == .requiresApproval {
                    openLoginSettings()
                }
            @unknown default:
                return
            }
            refreshLoginItems()
        } catch {
            refreshLoginItems()
            let failure = error as NSError
            logger.error("Failed to update launch at login domain=\(failure.domain, privacy: .public) code=\(failure.code)")

            let alert = NSAlert()
            alert.messageText = "Couldn’t change Launch at Login."
            alert.informativeText = "Try again, or check Login Items in System Settings."
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Open Settings…")
            NSApplication.shared.activate()
            if alert.runModal() == .alertSecondButtonReturn {
                openLoginSettings()
            }
        }
    }

    @objc
    private func openLoginSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
