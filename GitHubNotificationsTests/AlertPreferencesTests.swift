import Foundation
import Testing

@testable import GitHubNotifications

@MainActor
struct AlertPreferencesTests {
    @Test
    func alertsOnHighPriorityReasonsOutOfTheBox() {
        let preferences = makePreferences()

        #expect(preferences.allowsAlert(for: .reviewRequested))
        #expect(preferences.allowsAlert(for: .mentioned))
    }

    @Test(arguments: [NotificationReason.comment, .subscribed, .ciActivity, .stateChange])
    func staysQuietForEverythingElseOutOfTheBox(reason: NotificationReason) {
        #expect(!makePreferences().allowsAlert(for: reason))
    }

    @Test
    func togglingAGroupTogglesEveryReasonInIt() {
        let preferences = makePreferences()

        preferences.setEnabled(true, forGroup: .systemEvents)

        #expect(preferences.allowsAlert(for: .ciActivity))
        #expect(preferences.isFullyEnabled(.systemEvents))
    }

    @Test
    func reportsAGroupAsPartiallyEnabledWhenOnlySomeReasonsAreOn() {
        let preferences = makePreferences()

        preferences.setEnabled(true, for: .ciActivity)

        #expect(preferences.isPartiallyEnabled(.systemEvents))
        #expect(!preferences.isFullyEnabled(.systemEvents))
    }

    @Test
    func turningAReasonOffLeavesTheRestOfItsGroupAlone() {
        let preferences = makePreferences()

        preferences.setEnabled(false, for: .mentioned)

        #expect(!preferences.allowsAlert(for: .mentioned))
        #expect(preferences.allowsAlert(for: .reviewRequested))
    }

    @Test
    func remembersChoicesAcrossLaunches() {
        let defaults = makeDefaults()
        let firstLaunch = AlertPreferences(defaults: defaults)
        firstLaunch.setEnabled(false, forGroup: .highPriority)

        let secondLaunch = AlertPreferences(defaults: defaults)

        #expect(!secondLaunch.allowsAlert(for: .reviewRequested))
    }

    @Test
    func neverOffersTheUnrecognisedReasonAsAToggle() {
        let preferences = makePreferences()

        #expect(!preferences.reasons(in: .low).contains(.unrecognised))
    }

    private func makePreferences() -> AlertPreferences {
        AlertPreferences(defaults: makeDefaults())
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "alert-preferences-tests-\(UUID().uuidString)")!
    }
}
