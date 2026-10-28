import AppKit
import OSLog
import ServiceManagement
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let logo: NSImage?
    private var displayedColor: BlockColor?
    private let state: ScheduleState
    private let openWindow: () -> Void
    private let nowItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let rangeItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let nextItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
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

    init(state: ScheduleState, openWindow: @escaping () -> Void) {
        self.state = state
        self.openWindow = openWindow
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let logoURL = Bundle.main.url(forResource: "DayCueMenuBar", withExtension: "svg")
            ?? Bundle.module.url(forResource: "DayCueMenuBar", withExtension: "svg")
        logo = logoURL.flatMap { NSImage(contentsOf: $0) } ?? NSImage(systemSymbolName: "clock", accessibilityDescription: "DayCue")
        super.init()
        statusItem.button?.title = ""
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.imageScaling = .scaleProportionallyDown
        statusItem.button?.setAccessibilityIdentifier("daycue.menu-bar")

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        for item in [nowItem, rangeItem, nextItem] {
            item.isEnabled = false
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let openItem = NSMenuItem(
            title: "Edit Schedule…",
            action: #selector(openMainWindow),
            keyEquivalent: "o"
        )
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())

        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        let notificationSettingsItem = NSMenuItem(
            title: "Notification Settings…",
            action: #selector(openNotificationSettings),
            keyEquivalent: ""
        )
        notificationSettingsItem.target = self
        menu.addItem(notificationSettingsItem)
        loginSettingsItem.target = self
        menu.addItem(loginSettingsItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApplication.shared
        menu.addItem(quitItem)
        statusItem.menu = menu
        refresh(state.snapshot)
        refreshLoginItems()
    }

    func refresh(_ snapshot: ScheduleSnapshot) {
        let title = snapshot.title
        let color = snapshot.current?.block.color ?? .gray
        if displayedColor != color, let logo {
            let image = NSImage(size: NSSize(width: 22, height: 18), flipped: false) { bounds in
                logo.draw(in: bounds)
                color.accentColor.setFill()
                bounds.fill(using: .sourceIn)
                return true
            }
            image.isTemplate = false
            statusItem.button?.image = image
            displayedColor = color
        }
        statusItem.button?.toolTip = snapshot.current.map { "\($0.block.name) · \($0.block.timeRange)" } ?? title
        statusItem.button?.setAccessibilityLabel("DayCue, \(title)")
        nowItem.title = "Now: \(title)"
        nowItem.toolTip = title
        nowItem.view = detailView(nowItem.title, color: color)
        rangeItem.title = snapshot.current?.block.timeRange ?? ""
        rangeItem.isHidden = snapshot.current == nil
        nextItem.title = snapshot.next.map { "Next: \($0.name) · \($0.timeRange)" } ?? ""
        nextItem.toolTip = nextItem.title
        nextItem.view = snapshot.next == nil ? nil : detailView(nextItem.title, color: snapshot.next?.color ?? .gray)
        nextItem.isHidden = snapshot.next == nil
    }

    private func detailView(_ text: String, color: BlockColor) -> NSView {
        let view = NSHostingView(rootView: HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle().fill(color.tint).frame(width: 7, height: 7)
            Text(text)
        }
            .font(.system(size: 13))
            .frame(width: 340, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14).padding(.vertical, 6))
        view.setFrameSize(view.fittingSize)
        return view
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        state.refresh()
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
    private func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=io.github.zxhio.daycue") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc
    private func openLoginSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
