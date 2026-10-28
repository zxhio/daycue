import AppKit
import Combine

@MainActor
final class ScheduleState: ObservableObject {
    @Published private(set) var history = ScheduleHistory()
    @Published private(set) var today = Calendar.autoupdatingCurrent.startOfDay(for: Date())
    var blocks: [TimeBlock] { history.blocks(on: Date(), calendar: .autoupdatingCurrent) }
    @Published private(set) var snapshot = ScheduleSnapshot(current: nil, next: nil)
    @Published private(set) var loadError: String?
    var onRefresh: ((ScheduleSnapshot, Bool) -> Void)?
    private let store = ScheduleStore()
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []

    init() {
        reload()
        for name in [Notification.Name.NSSystemClockDidChange, NSNotification.Name.NSSystemTimeZoneDidChange,
                     NSLocale.currentLocaleDidChangeNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            workspaceObservers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
    }

    func reload() {
        do {
            let loaded = try store.load()
            history = loaded
            loadError = nil
        } catch {
            loadError = "Couldn’t read your schedule. The original file has been kept. Check \(store.url.path) and try again."
        }
        refresh()
    }

    func blocks(on date: Date, calendar: Calendar) -> [TimeBlock] {
        let weekday = Weekday(rawValue: calendar.component(.weekday, from: date)) ?? .monday
        return ScheduleCalculation.blocks(on: weekday, in: history.blocks(on: date, calendar: calendar))
    }

    func canEdit(on date: Date) -> Bool {
        Calendar.autoupdatingCurrent.compare(date, to: Date(), toGranularity: .day) != .orderedAscending
    }

    func save(_ block: TimeBlock, on selectedDate: Date) throws {
        guard loadError == nil else { throw ScheduleValidationError(message: "Reload your schedule before making changes.") }
        var updated = blocks.filter { $0.id != block.id }
        updated.append(block)
        try persist(updated, on: selectedDate)
    }

    func delete(_ block: TimeBlock, on selectedDate: Date) throws {
        try persist(blocks.filter { $0.id != block.id }, on: selectedDate)
    }

    private func persist(_ updated: [TimeBlock], on selectedDate: Date) throws {
        guard loadError == nil else { throw ScheduleValidationError(message: "Reload your schedule before making changes.") }
        guard canEdit(on: selectedDate) else { throw ScheduleValidationError(message: "Past schedules are read-only. Select today or a future date.") }
        try ScheduleValidation.validateAll(updated)
        let updatedHistory = history.updating(updated, from: Date(), calendar: .autoupdatingCurrent)
        do { try store.save(updatedHistory) }
        catch { throw ScheduleValidationError(message: "Couldn’t save your schedule. Please try again.") }
        history = updatedHistory
        refresh()
    }

    func refresh() {
        update(at: Date(), notify: false)
    }

    private func update(at date: Date, notify: Bool) {
        timer?.invalidate()
        timer = nil
        let calendar = Calendar.autoupdatingCurrent
        let start = calendar.startOfDay(for: date)
        if today != start { today = start }
        let blocks = history.blocks(on: date, calendar: calendar)
        let previous = snapshot.current
        snapshot = ScheduleCalculation.snapshot(at: date, calendar: calendar, blocks: blocks)
        onRefresh?(snapshot, notify && previous != snapshot.current)
        guard let boundary = ScheduleCalculation.nextBoundary(after: date, calendar: calendar, blocks: blocks) else { return }
        let uptime = ProcessInfo.processInfo.systemUptime
        let delay = boundary.date.timeIntervalSince(date)
        let nextTimer = Timer(fire: boundary.date, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                let now = Date()
                let elapsed = ProcessInfo.processInfo.systemUptime - uptime
                let timely = abs(now.timeIntervalSince(boundary.date)) < 2 && abs(elapsed - delay) < 2
                self?.update(at: now, notify: timely && !boundary.isClockChange)
            }
        }
        nextTimer.tolerance = 0.1
        timer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
    }
}
