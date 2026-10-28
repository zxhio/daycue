import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private lazy var mainWindowController = MainWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController { [weak self] in
            self?.mainWindowController.present()
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        mainWindowController.present()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
