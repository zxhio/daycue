import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = ScheduleState()
    private let notifications = NotificationController()
    private var menuBarController: MenuBarController?
    private lazy var mainWindowController = MainWindowController(state: state)

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMenus()
        notifications.start()
        menuBarController = MenuBarController(state: state) { [weak self] in
            self?.mainWindowController.present()
        }
        state.onRefresh = { [weak self] snapshot, notify in
            self?.menuBarController?.refresh(snapshot)
            self?.notifications.refresh(snapshot, notify: notify)
        }
        state.refresh()
        if ProcessInfo.processInfo.arguments.contains("--test-notification") {
            Task { await notifications.sendTestNotification(state.snapshot) }
        }
        if state.loadError != nil { mainWindowController.present() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        notifications.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        mainWindowController.present()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        mainWindowController.requestQuit { allowed in
            DispatchQueue.main.async { sender.reply(toApplicationShouldTerminate: allowed) }
        }
        return .terminateLater
    }

    private func installMenus() {
        let menu = NSMenu()
        let appMenu = NSMenu(title: "DayCue")
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        menu.addItem(appItem)
        appMenu.addItem(withTitle: "About DayCue", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide DayCue", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit DayCue", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileMenu = NSMenu(title: "File")
        let fileItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        fileItem.submenu = fileMenu
        menu.addItem(fileItem)
        fileMenu.addItem(withTitle: "Add Time Block", action: #selector(MainWindowController.addTimeBlock(_:)), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "Save", action: #selector(BlockEditorController.saveTimeBlock(_:)), keyEquivalent: "s")
        fileMenu.addItem(withTitle: "Close", action: #selector(MainWindowController.closeWindow(_:)), keyEquivalent: "w")

        let editMenu = NSMenu(title: "Edit")
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editItem.submenu = editMenu
        menu.addItem(editItem)
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApplication.shared.mainMenu = menu
    }
}
