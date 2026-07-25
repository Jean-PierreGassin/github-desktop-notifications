import Foundation
import Testing

@testable import GitHubNotifications

@MainActor
struct AlertPreferencesTests {
    @Test
    func onlyInterruptsForHighPriorityOutOfTheBox() {
        let preferences = makePreferences()

        #expect(preferences.preset == .essential)
        #expect(preferences.allowsAlert(for: .reviewRequested))
        #expect(preferences.allowsAlert(for: .mentioned))
    }

    @Test(arguments: [NotificationReason.comment, .subscribed, .ciActivity, .stateChange])
    func staysQuietForEverythingElseOutOfTheBox(reason: NotificationReason) {
        #expect(!makePreferences().allowsAlert(for: reason))
    }

    @Test
    func theEverythingPresetCoversEveryType() {
        let preferences = makePreferences()

        preferences.select(.everything)

        #expect(NotificationReason.togglableCases.allSatisfy(preferences.allowsAlert))
    }

    @Test
    func theExceptSystemEventsPresetLeavesWorkflowRunsOut() {
        let preferences = makePreferences()

        preferences.select(.exceptSystemEvents)

        #expect(preferences.allowsAlert(for: .subscribed))
        #expect(!preferences.allowsAlert(for: .ciActivity))
    }

    @Test
    func pickingATypeByHandMovesTheUserOntoTheirOwnSetWithoutLosingTheRest() {
        let preferences = makePreferences()

        preferences.setEnabled(false, for: .mentioned)

        #expect(preferences.preset == .custom)
        #expect(!preferences.allowsAlert(for: .mentioned))
        #expect(preferences.allowsAlert(for: .reviewRequested))
    }

    @Test
    func addingATypeToAPresetKeepsEverythingThatPresetAlreadyCovered() {
        let preferences = makePreferences()

        preferences.setEnabled(true, for: .ciActivity)

        #expect(preferences.allowsAlert(for: .ciActivity))
        #expect(preferences.allowsAlert(for: .reviewRequested))
    }

    @Test
    func snapsBackToAPresetWhenTheChosenTypesMatchItExactly() {
        let preferences = makePreferences()
        preferences.select(.everything)

        for reason in preferences.reasons(in: .systemEvents) {
            preferences.setEnabled(false, for: reason)
        }

        #expect(preferences.preset == .exceptSystemEvents)
    }

    @Test
    func remembersACustomSetAcrossLaunches() {
        let defaults = makeDefaults()
        let firstLaunch = AlertPreferences(defaults: defaults)
        firstLaunch.setEnabled(false, for: .reviewRequested)

        let secondLaunch = AlertPreferences(defaults: defaults)

        #expect(secondLaunch.preset == .custom)
        #expect(!secondLaunch.allowsAlert(for: .reviewRequested))
        #expect(secondLaunch.allowsAlert(for: .mentioned))
    }

    @Test
    func remembersAChosenPresetAcrossLaunches() {
        let defaults = makeDefaults()
        AlertPreferences(defaults: defaults).select(.everything)

        #expect(AlertPreferences(defaults: defaults).preset == .everything)
    }

    @Test
    func neverOffersTheUnrecognisedReasonAsAToggle() {
        #expect(!makePreferences().reasons(in: .low).contains(.unrecognised))
    }

    private func makePreferences() -> AlertPreferences {
        AlertPreferences(defaults: makeDefaults())
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "alert-preferences-tests-\(UUID().uuidString)")!
    }
}
