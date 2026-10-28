import AppKit
import SwiftUI

@MainActor
final class MainWindowController: NSWindowController {
    init() {
        let window = NSWindow(contentViewController: NSHostingController(rootView: MainWindowView()))
        window.title = "DayCue"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 360, height: 240))
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func present() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate()
    }
}
