import Foundation
import Testing

@testable import GitHubNotifications

@MainActor
struct NotificationContentPreferencesTests {
    @Test
    func resettingContentLeavesHowNotificationsBehaveAlone() {
        let preferences = makePreferences()
        preferences.settings.showsRepository = false
        preferences.settings.showsThreadTitle = false
        preferences.settings.playsSound = false

        preferences.resetContent()

        #expect(preferences.settings.showsRepository)
        #expect(preferences.settings.showsThreadTitle)
        #expect(!preferences.settings.playsSound)
    }

    @Test
    func resettingBehaviourLeavesWhatNotificationsSayAlone() {
        let preferences = makePreferences()
        preferences.settings.showsRepository = false
        preferences.settings.groupsByRepository = false
        preferences.settings.sound = .submarine

        preferences.resetBehaviour()

        #expect(preferences.settings.groupsByRepository)
        #expect(preferences.settings.sound == NotificationContentSettings().sound)
        #expect(!preferences.settings.showsRepository)
    }

    @Test
    func aResetSurvivesTheNextLaunch() {
        let defaults = makeDefaults()
        let preferences = NotificationContentPreferences(defaults: defaults)
        preferences.settings.showsThreadTitle = false

        preferences.resetContent()

        #expect(NotificationContentPreferences(defaults: defaults).settings.showsThreadTitle)
    }

    private func makePreferences() -> NotificationContentPreferences {
        NotificationContentPreferences(defaults: makeDefaults())
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "notification-content-preferences-tests-\(UUID().uuidString)")!
    }
}
