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
    func announce(_ announcement: ThreadAnnouncement, settings: NotificationContentSettings) async {
        let thread = announcement.thread
        let content = makeContent(
            NotificationContentFormatter.make(for: announcement, settings: settings),
            settings: settings,
        )
        content.threadIdentifier = settings.groupsByRepository ? thread.repository.fullName : ""
        content.userInfo = [Self.threadIdentifierKey: thread.id]

        await post(content, identifier: "thread-\(thread.id)-\(thread.updatedAt.timeIntervalSince1970)")
    }

    private func makeContent(
        _ text: NotificationContentText,
        settings: NotificationContentSettings,
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = text.title
        content.subtitle = text.subtitle
        content.body = text.body
        content.sound = settings.playsSound ? settings.sound.notificationSound : nil

        return content
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

    var needsPermission: Bool {
        !canPostNotifications
    }

    /// macOS only shows its own prompt once. After that the only route back is
    /// System Settings, so the button has to say which one the user is getting.
    var permissionActionTitle: String {
        authorizationStatus == .notDetermined ? "Allow" : "Open Settings"
    }

    var permissionMessage: String {
        authorizationStatus == .notDetermined
            ? "Alerts are not turned on yet, so nothing will reach you."
            : "macOS is blocking alerts from this app, so nothing will reach you."
    }

    /// Asks macOS directly when it has never been asked, and falls back to
    /// System Settings once a decision has been recorded.
    func resolvePermission() async {
        guard authorizationStatus == .notDetermined else {
            openSystemNotificationSettings()
            return
        }

        await requestAuthorization()
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

    /// Sends a sample alert formatted exactly as a real one would be, so the
    /// user can confirm both permission and layout in one click.
    func sendTestNotification(settings: NotificationContentSettings) async {
        let text = NotificationContentFormatter.make(for: SampleNotification.announcement, settings: settings)

        await post(makeContent(text, settings: settings), identifier: "test-\(UUID().uuidString)")
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
