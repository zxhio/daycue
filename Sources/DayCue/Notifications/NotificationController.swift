import AppKit
import OSLog
import UserNotifications

@MainActor
final class NotificationController: NSObject, UNUserNotificationCenterDelegate {
    private let center: UNUserNotificationCenter?
    private let logger = Logger(subsystem: "io.github.zxhio.daycue", category: "notifications")
    private var authorization: Task<Void, Never>?
    private var delivery: Task<Void, Never>?
    private var requestIdentifier: String?
    private var presentedSnapshot: ScheduleSnapshot?

    override init() {
        center = Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
            ? UNUserNotificationCenter.current() : nil
        super.init()
        center?.delegate = self
    }

    func start() {
        guard let center, authorization == nil else { return }
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        authorization = Task { [weak self] in
            defer { self?.authorization = nil }
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .notDetermined else { return }
            do {
                _ = try await center.requestAuthorization(options: [.alert])
            } catch {
                self?.logger.error("Failed to request notification permission: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func sendTestNotification(_ snapshot: ScheduleSnapshot) async {
        await authorization?.value
        guard let center else {
            print("Run the packaged app to send a test notification.")
            return
        }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            print("Test notification blocked: allow DayCue notifications in System Settings.")
            fflush(nil)
            return
        }
        show(snapshot)
        await delivery?.value
        let delivered = await center.deliveredNotifications()
        let submitted = delivered.contains { $0.request.identifier == requestIdentifier }
        print(submitted ? "Test notification delivered." : "Test notification submitted; check macOS notification settings if no banner appears.")
        fflush(nil)
    }

    func refresh(_ snapshot: ScheduleSnapshot, notify: Bool) {
        if notify { show(snapshot) }
        else if presentedSnapshot != snapshot { clear() }
    }

    func stop() {
        authorization?.cancel()
        clear()
    }

    private func show(_ snapshot: ScheduleSnapshot) {
        clear()
        guard let center else { return }
        presentedSnapshot = snapshot
        let identifier = "daycue.time-block.\(UUID().uuidString)"
        requestIdentifier = identifier
        delivery = Task { [weak self] in
            let settings = await center.notificationSettings()
            guard !Task.isCancelled, self?.requestIdentifier == identifier,
                  settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = snapshot.title
            content.body = snapshot.current?.block.timeRange ?? snapshot.next.map {
                "Next: \($0.name) · \($0.timeRange)"
            } ?? "Your time block has ended."
            content.threadIdentifier = "daycue.time-blocks"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            do {
                try await center.add(request)
                if Task.isCancelled || self?.requestIdentifier != identifier {
                    center.removePendingNotificationRequests(withIdentifiers: [identifier])
                    center.removeDeliveredNotifications(withIdentifiers: [identifier])
                }
            } catch {
                self?.logger.error("Failed to deliver notification: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func clear() {
        delivery?.cancel()
        delivery = nil
        if let requestIdentifier {
            center?.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
            center?.removeDeliveredNotifications(withIdentifiers: [requestIdentifier])
        }
        requestIdentifier = nil
        presentedSnapshot = nil
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let identifier = notification.request.identifier
        return await MainActor.run {
            identifier == requestIdentifier ? [.banner, .list] : []
        }
    }
}
