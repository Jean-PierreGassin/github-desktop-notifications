import Foundation
import Testing

@testable import GitHubNotifications

@MainActor
struct BehaviourPreferencesTests {
    @Test
    func clicksMarkReadAndDismissedOutOfTheBox() {
        #expect(BehaviourPreferences(defaults: makeDefaults()).clickBehaviour == .readAndDismissed)
    }

    @Test(arguments: [(true, ClickBehaviour.readAndDismissed), (false, ClickBehaviour.read)])
    func carriesTheOldMarkAsReadChoiceAcross(marksAsReadOnOpen: Bool, expected: ClickBehaviour) {
        let defaults = makeDefaults()
        defaults.set(marksAsReadOnOpen, forKey: "marksAsReadOnOpen")

        #expect(BehaviourPreferences(defaults: defaults).clickBehaviour == expected)
    }

    @Test
    func doesNotAskAgainWhenTheOldQuestionWasAlreadyAnswered() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: "hasChosenMarkAsReadBehaviour")

        #expect(BehaviourPreferences(defaults: defaults).hasChosenClickBehaviour)
    }

    @Test
    func retiresTheOldKeysSoTheyCannotOverrideALaterChoice() {
        let defaults = makeDefaults()
        defaults.set(false, forKey: "marksAsReadOnOpen")

        let preferences = BehaviourPreferences(defaults: defaults)
        preferences.clickBehaviour = .dismissed

        #expect(defaults.object(forKey: "marksAsReadOnOpen") == nil)
        #expect(BehaviourPreferences(defaults: defaults).clickBehaviour == .dismissed)
    }

    @Test
    func resettingRestoresTheDefaultWithoutReAskingTheOneTimeQuestion() {
        let defaults = makeDefaults()
        let preferences = BehaviourPreferences(defaults: defaults)
        preferences.clickBehaviour = .read
        preferences.hasChosenClickBehaviour = true

        preferences.resetToDefaults()

        #expect(preferences.clickBehaviour == .readAndDismissed)
        #expect(preferences.hasChosenClickBehaviour)
        #expect(BehaviourPreferences(defaults: defaults).clickBehaviour == .readAndDismissed)
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "behaviour-preferences-tests-\(UUID().uuidString)")!
    }
}
