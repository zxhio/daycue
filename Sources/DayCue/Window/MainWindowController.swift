import AppKit
import SwiftUI

@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate, NSMenuItemValidation {
    private let state: ScheduleState
    private var selectedDate = Date()
    private var editor: BlockEditorController?

    init(state: ScheduleState) {
        self.state = state
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 540),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Schedule"
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 680, height: 460)
        window.center()
        super.init(window: window)
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: MainWindowView(
            state: state,
            selectedDate: selectedDate,
            selectDate: { [weak self] in self?.selectedDate = $0 },
            add: { [weak self] in self?.addTimeBlock(nil) },
            edit: { [weak self] in self?.edit($0) },
            delete: { [weak self] in self?.delete($0) }
        ))
        window.setContentSize(NSSize(width: 760, height: 540))
    }

    required init?(coder: NSCoder) { nil }

    func present() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate()
    }

    @objc func addTimeBlock(_ sender: Any?) {
        guard editor == nil, state.loadError == nil, state.canEdit(on: selectedDate), window?.attachedSheet == nil else { return }
        edit(nil)
    }

    private func edit(_ block: TimeBlock?) {
        guard editor == nil, state.loadError == nil, state.canEdit(on: selectedDate), let window else { return }
        let controller = BlockEditorController(state: state, block: block, selectedDate: selectedDate, parentWindow: window)
        controller.onDismiss = { [weak self] in self?.editor = nil }
        editor = controller
        if let sheet = controller.window { window.beginSheet(sheet) }
    }

    private func delete(_ block: TimeBlock) {
        guard editor == nil, state.loadError == nil, state.canEdit(on: selectedDate), let window, window.attachedSheet == nil else { return }
        let deletionDate = selectedDate
        let alert = TimeBlockAlerts.deletion(for: block)
        alert.beginSheetModal(for: window) { [self] response in
            guard response == .alertFirstButtonReturn else { return }
            do {
                try state.delete(block, on: deletionDate)
            } catch {
                let failure = NSAlert()
                failure.messageText = "Couldn’t delete your time block."
                failure.informativeText = error.localizedDescription
                failure.addButton(withTitle: "OK")
                failure.beginSheetModal(for: window)
            }
        }
    }

    @objc func closeWindow(_ sender: Any?) {
        window?.performClose(sender)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let ready = editor == nil && window?.isKeyWindow == true
            && window?.attachedSheet == nil && NSApplication.shared.modalWindow == nil
        if menuItem.action == #selector(addTimeBlock(_:)) { return ready && state.loadError == nil && state.canEdit(on: selectedDate) }
        return ready && menuItem.action == #selector(closeWindow(_:))
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let editor else { return true }
        editor.requestClose { [weak self] allowed in
            if allowed { self?.window?.close() }
        }
        return false
    }

    func windowDidResize(_ notification: Notification) {
        if let window { editor?.fit(in: window) }
    }

    func windowDidChangeScreen(_ notification: Notification) {
        if let window { editor?.fit(in: window) }
    }

    func requestQuit(_ completion: @escaping (Bool) -> Void) {
        guard let editor else { completion(true); return }
        editor.requestClose(completion)
    }
}

@MainActor
final class BlockEditorController: NSWindowController, NSWindowDelegate, NSMenuItemValidation {
    private let state: ScheduleState
    private let draft: BlockDraft
    private let selectedDate: Date
    private var dialogOpen = false
    private var isDismissed = false
    var onDismiss: (() -> Void)?

    init(state: ScheduleState, block: TimeBlock?, selectedDate: Date, parentWindow: NSWindow? = nil) {
        self.state = state
        self.selectedDate = selectedDate
        draft = BlockDraft(block: block, day: ScheduleWeek(containing: selectedDate, calendar: .autoupdatingCurrent).selectedWeekday)
        let window = BlockEditorWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = block == nil ? "Add Time Block" : "Edit Time Block"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        let hosting = NSHostingController(rootView: BlockEditorView(
            draft: draft,
            save: { [weak self] in self?.saveTimeBlock(nil) },
            cancel: { [weak self] in self?.cancelOperation(nil) },
            delete: { [weak self] in self?.deleteBlock() }
        ))
        window.contentViewController = hosting
        fit(in: parentWindow)
        window.setContentSize(hosting.view.fittingSize)
        hosting.view.layoutSubtreeIfNeeded()
    }

    required init?(coder: NSCoder) { nil }

    func fit(in parent: NSWindow?) {
        guard let window, let hosting = window.contentViewController as? NSHostingController<BlockEditorView> else { return }
        let screen = (parent?.screen ?? NSScreen.main)?.visibleFrame.size ?? NSSize(width: 1024, height: 768)
        let available = parent?.contentLayoutRect.size ?? screen
        let width = min(560, max(320, min(screen.width, available.width) - 48))
        let maximumHeight = min(720, max(240, min(screen.height - 120, available.height - 48)))
        var view = hosting.rootView
        guard view.width != width || view.maximumHeight != maximumHeight else { return }
        view.width = width
        view.maximumHeight = maximumHeight
        hosting.rootView = view
    }

    @objc func saveTimeBlock(_ sender: Any?) {
        guard !dialogOpen, !draft.isSaving, !isDismissed else { return }
        if save() { dismiss() }
    }

    @objc override func cancelOperation(_ sender: Any?) {
        requestClose { _ in }
    }

    private func save() -> Bool {
        guard !draft.isSaving, !isDismissed else { return false }
        draft.isSaving = true
        defer { draft.isSaving = false }
        do {
            try state.save(draft.block(among: state.blocks), on: selectedDate)
            return true
        } catch {
            draft.error = error.localizedDescription
            return false
        }
    }

    private func dismiss() {
        guard !isDismissed, let window else { return }
        isDismissed = true
        window.sheetParent?.endSheet(window)
        window.orderOut(nil)
        onDismiss?()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        requestClose { _ in }
        return false
    }

    func requestClose(_ completion: @escaping (Bool) -> Void) {
        guard !dialogOpen, !draft.isSaving, !isDismissed, let window else { completion(false); return }
        guard draft.hasChanges else { dismiss(); completion(true); return }
        dialogOpen = true
        let alert = NSAlert()
        alert.messageText = "Save Changes?"
        alert.informativeText = "Your changes will be lost if you don’t save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel").keyEquivalent = "\u{1b}"
        alert.beginSheetModal(for: window) { [self] response in
            dialogOpen = false
            switch response {
            case .alertFirstButtonReturn:
                let saved = save()
                if saved { dismiss() }
                completion(saved)
            case .alertSecondButtonReturn:
                dismiss()
                completion(true)
            default:
                completion(false)
            }
        }
    }

    private func deleteBlock() {
        guard !dialogOpen, !draft.isSaving, !isDismissed, let block = draft.original, let window else { return }
        dialogOpen = true
        let alert = TimeBlockAlerts.deletion(for: block)
        alert.beginSheetModal(for: window) { [self] response in
            dialogOpen = false
            guard response == .alertFirstButtonReturn else { return }
            do {
                try state.delete(block, on: selectedDate)
                dismiss()
            } catch { draft.error = error.localizedDescription }
        }
    }

    @objc func closeWindow(_ sender: Any?) {
        window?.performClose(sender)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let ready = !dialogOpen && !draft.isSaving && !isDismissed && window?.isKeyWindow == true
            && window?.attachedSheet == nil && NSApplication.shared.modalWindow == nil
        return ready && [#selector(saveTimeBlock(_:)), #selector(closeWindow(_:))].contains(menuItem.action)
    }
}

@MainActor
private final class BlockEditorWindow: NSWindow {
    override func performClose(_ sender: Any?) {
        guard attachedSheet == nil else { return }
        _ = delegate?.windowShouldClose?(self)
    }
}

@MainActor
private enum TimeBlockAlerts {
    static func deletion(for block: TimeBlock) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "Delete “\(block.name)”?"
        alert.informativeText = "This time block will be removed from today onward. Past dates stay unchanged."
        alert.addButton(withTitle: "Delete").hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel").keyEquivalent = "\u{1b}"
        return alert
    }
}
