import Foundation
import Testing

@testable import GitHubNotifications

@MainActor
struct BehaviourPreferencesTests {
    @Test
    func marksNotificationsAsReadOnOpenOutOfTheBox() {
        #expect(BehaviourPreferences(defaults: makeDefaults()).marksAsReadOnOpen)
    }

    @Test
    func resettingRestoresTheDefaultWithoutReAskingTheOneTimeQuestion() {
        let defaults = makeDefaults()
        let preferences = BehaviourPreferences(defaults: defaults)
        preferences.marksAsReadOnOpen = false
        preferences.hasChosenMarkAsReadBehaviour = true

        preferences.resetToDefaults()

        #expect(preferences.marksAsReadOnOpen)
        #expect(preferences.hasChosenMarkAsReadBehaviour)
        #expect(BehaviourPreferences(defaults: defaults).marksAsReadOnOpen)
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "behaviour-preferences-tests-\(UUID().uuidString)")!
    }
}
