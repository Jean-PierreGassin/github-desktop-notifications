import AppKit
import Foundation
import UserNotifications

/// Wraps the notification centre so the rest of the app never has to think
/// about authorisation state or whether it is running inside an app bundle.
@MainActor
@Observable
final class Notifier: NSObject, @preconcurrency UNUserNotificationCenterDelegate {
    private static let notificationSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.notifications",
    )!
    private nonisolated static let threadIdentifierKey = "threadIdentifier"

    private let log: AppLog

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Set by the session so a click on an alert opens the thread.
    var onAlertClicked: ((String) -> Void)?

    init(log: AppLog) {
        self.log = log

        super.init()
    }

    func installClickHandler() {
        notificationCentre()?.delegate = self
    }

    /// Raises one alert per thread, grouped in Notification Centre by repository.
    func announce(_ thread: NotificationThread) async {
        let content = UNMutableNotificationContent()
        content.title = thread.repository.fullName
        content.subtitle = thread.reason.displayName
        content.body = thread.subject.title
        content.threadIdentifier = thread.repository.fullName
        content.userInfo = [Self.threadIdentifierKey: thread.id]

        await post(content, identifier: "thread-\(thread.id)-\(thread.updatedAt.timeIntervalSince1970)")
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
    ) async {
        let threadIdentifier = response.notification.request.content.userInfo[Self.threadIdentifierKey] as? String

        guard let threadIdentifier else {
            return
        }

        await MainActor.run {
            onAlertClicked?(threadIdentifier)
        }
    }

    var canPostNotifications: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    var isBlockedBySystemSettings: Bool {
        authorizationStatus == .denied
    }

    func requestAuthorization() async {
        guard let center = notificationCentre() else {
            return
        }

        await refreshAuthorizationStatus()

        guard authorizationStatus == .notDetermined else {
            log.info("Notification permission already decided: \(describe(authorizationStatus)).")
            return
        }

        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
            await refreshAuthorizationStatus()
            log.info("Notification permission is now \(describe(authorizationStatus)).")
        } catch {
            log.error("Couldn't ask for notification permission: \(error.localizedDescription)")
        }
    }

    func refreshAuthorizationStatus() async {
        guard let center = notificationCentre() else {
            return
        }

        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    func openSystemNotificationSettings() {
        NSWorkspace.shared.open(Self.notificationSettingsURL)
    }

    func postTestNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "GitHub Notifications"
        content.body = "Notifications are working."

        await post(content, identifier: UUID().uuidString)
    }

    func post(_ content: UNNotificationContent, identifier: String) async {
        guard let center = notificationCentre() else {
            return
        }

        do {
            try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
        } catch {
            log.error("Couldn't post a notification: \(error.localizedDescription)")
        }
    }

    /// `UNUserNotificationCenter.current()` traps when the process has no bundle
    /// identifier, which happens in command line contexts.
    private func notificationCentre() -> UNUserNotificationCenter? {
        guard Bundle.main.bundleIdentifier != nil else {
            log.warning("Not running from an app bundle; notifications are unavailable.")
            return nil
        }

        return UNUserNotificationCenter.current()
    }

    private func describe(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "not yet decided"
        case .denied: "denied"
        case .authorized: "allowed"
        case .provisional: "provisional"
        case .ephemeral: "ephemeral"
        @unknown default: "unknown"
        }
    }
}
