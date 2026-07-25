import Testing
import UserNotifications

/// The app ships ad-hoc signed, with no Developer ID. Local notifications do not
/// need one, but they do need a real app bundle, so this guards the assumption
/// the whole product rests on.
struct NotificationCentreAvailabilityTests {
    @Test
    @MainActor
    func notificationCentreIsReachableFromTheAppBundle() async {
        #expect(Bundle.main.bundleIdentifier != nil)

        let settings = await UNUserNotificationCenter.current().notificationSettings()

        print("Notification authorization status: \(settings.authorizationStatus.rawValue)")

        #expect([.notDetermined, .denied, .authorized, .provisional].contains(settings.authorizationStatus))
    }
}
