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
    func holdsBackPushesAndChecksOutOfTheBox() {
        let preferences = makePreferences()

        #expect(preferences.followUpAlerts == .comments)
        #expect(!preferences.allowsAlert(about: .otherActivity))
    }

    @Test(arguments: [
        (FollowUpAlerts.everything, ThreadUpdate.comment, true),
        (.everything, .reviewComment, true),
        (.everything, .otherActivity, true),
        (.comments, .comment, true),
        (.comments, .reviewComment, true),
        (.comments, .otherActivity, false),
        (.nothing, .comment, false),
        (.nothing, .reviewComment, false),
        (.nothing, .otherActivity, false),
    ])
    func decidesWhichChangesToAKnownThreadAreWorthInterruptingFor(
        followUpAlerts: FollowUpAlerts,
        update: ThreadUpdate,
        isAllowed: Bool,
    ) {
        let preferences = makePreferences()
        preferences.followUpAlerts = followUpAlerts

        #expect(preferences.allowsAlert(about: update) == isAllowed)
    }

    /// The guarantee that makes the quieter choices safe to pick: a thread the
    /// user has not heard about, or one GitHub has re-reasoned because it now
    /// concerns them more directly, always gets through.
    @Test(arguments: FollowUpAlerts.allCases)
    func neverSilencesAThreadWhoseReasonIsItselfTheNews(followUpAlerts: FollowUpAlerts) {
        let preferences = makePreferences()
        preferences.followUpAlerts = followUpAlerts

        #expect(preferences.allowsAlert(about: .reasonForNotifying))
    }

    @Test
    func remembersHowMuchFollowUpActivityToAlertOnAcrossLaunches() {
        let defaults = makeDefaults()
        AlertPreferences(defaults: defaults).followUpAlerts = .nothing

        #expect(AlertPreferences(defaults: defaults).followUpAlerts == .nothing)
    }

    @Test
    func neverOffersTheUnrecognisedReasonAsAToggle() {
        #expect(!makePreferences().reasons(in: .low).contains(.unrecognised))
    }

    @Test
    func resettingForgetsTheHandPickedSetAsWellAsThePresets() {
        let defaults = makeDefaults()
        let preferences = AlertPreferences(defaults: defaults)
        preferences.setEnabled(true, for: .ciActivity)
        preferences.followUpAlerts = .everything

        preferences.resetToDefaults()

        #expect(preferences.preset == .essential)
        #expect(preferences.followUpAlerts == .comments)
        #expect(!preferences.allowsAlert(for: .ciActivity))
        #expect(AlertPreferences(defaults: defaults).preset == .essential)
        #expect(AlertPreferences(defaults: defaults).followUpAlerts == .comments)
    }

    private func makePreferences() -> AlertPreferences {
        AlertPreferences(defaults: makeDefaults())
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "alert-preferences-tests-\(UUID().uuidString)")!
    }
}
