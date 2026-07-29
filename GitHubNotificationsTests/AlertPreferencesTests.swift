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

    /// The complaint this was built for: someone else commenting on, or
    /// approving, a pull request you were only asked to review is the loudest
    /// thing GitHub sends and the least of what needs you.
    @Test(arguments: [ThreadUpdate.comment, .reviewComment, .otherActivity])
    func staysQuietOnAPullRequestYouWereOnlyAskedToReview(update: ThreadUpdate) {
        #expect(!makePreferences().allowsAlert(about: update, on: .reviewRequested))
    }

    /// The other half of the same complaint: your own pull request is exactly
    /// what you want to hear about. A review submitted with no comment on it
    /// arrives as plain activity, so comments alone would have missed it.
    @Test(arguments: [ThreadUpdate.comment, .reviewComment, .otherActivity])
    func speaksUpOnYourOwnPullRequest(update: ThreadUpdate) {
        #expect(makePreferences().allowsAlert(about: update, on: .author))
    }

    @Test(arguments: [
        (NotificationReason.author, true),
        (.assigned, true),
        (.mentioned, true),
        (.comment, true),
        (.manual, true),
        (.reviewRequested, false),
        (.approvalRequested, false),
        (.teamMentioned, false),
        (.subscribed, false),
        (.stateChange, false),
        (.ciActivity, false),
        (.unrecognised, false),
    ])
    func followsUpOnlyOnThreadsThatAreYoursOutOfTheBox(reason: NotificationReason, isAllowed: Bool) {
        let preferences = makePreferences()

        #expect(preferences.followUpThreads == .yours)
        #expect(preferences.allowsAlert(about: .comment, on: reason) == isAllowed)
    }

    @Test
    func followsUpOnEveryThreadWhenAskedTo() {
        let preferences = makePreferences()

        preferences.followUpThreads = .everyThread

        #expect(preferences.allowsAlert(about: .comment, on: .reviewRequested))
        #expect(preferences.allowsAlert(about: .otherActivity, on: .subscribed))
    }

    @Test
    func hearsEverythingThatHappensOnYourOwnThreadsOutOfTheBox() {
        let preferences = makePreferences()

        #expect(preferences.followUpAlerts == .everything)
        #expect(preferences.allowsAlert(about: .otherActivity, on: .author))
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

        #expect(preferences.allowsAlert(about: update, on: .author) == isAllowed)
    }

    /// The guarantee that makes the quieter choices safe to pick: a thread the
    /// user has not heard about, or one GitHub has re-reasoned because it now
    /// concerns them differently, always gets through. Without it, "threads that
    /// are yours" would mean a review request could never reach you at all.
    @Test(arguments: FollowUpAlerts.allCases)
    func neverSilencesAThreadWhoseReasonIsItselfTheNews(followUpAlerts: FollowUpAlerts) {
        let preferences = makePreferences()
        preferences.followUpAlerts = followUpAlerts
        preferences.followUpThreads = .yours

        #expect(preferences.allowsAlert(about: .reasonForNotifying, on: .reviewRequested))
        #expect(preferences.allowsAlert(about: .reasonForNotifying, on: .subscribed))
    }

    /// GitHub re-reasons a thread when it starts concerning you differently, so
    /// being mentioned on a review you had gone quiet on comes through as the
    /// reason being the news rather than as another comment.
    @Test
    func letsAMentionThroughOnAThreadThatHadGoneQuiet() {
        let preferences = makePreferences()

        #expect(!preferences.allowsAlert(about: .comment, on: .reviewRequested))
        #expect(preferences.allowsAlert(about: .reasonForNotifying, on: .mentioned))
    }

    @Test
    func remembersWhichThreadsToFollowUpOnAcrossLaunches() {
        let defaults = makeDefaults()
        AlertPreferences(defaults: defaults).followUpThreads = .everyThread

        #expect(AlertPreferences(defaults: defaults).followUpThreads == .everyThread)
    }

    @Test
    func remembersHowMuchFollowUpActivityToAlertOnAcrossLaunches() {
        let defaults = makeDefaults()
        AlertPreferences(defaults: defaults).followUpAlerts = .nothing

        #expect(AlertPreferences(defaults: defaults).followUpAlerts == .nothing)
    }

    /// A reason with no name in this app is not assumed to be the user's, so a
    /// type GitHub adds tomorrow announces itself once rather than following up
    /// on activity nobody has decided is worth it.
    @Test
    func doesNotTreatAReasonItHasNoNameForAsYours() {
        #expect(!NotificationReason.unrecognised.makesTheThreadYours)
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
        preferences.followUpAlerts = .nothing
        preferences.followUpThreads = .everyThread
        preferences.panelContents = .everything

        preferences.resetToDefaults()

        #expect(preferences.preset == .essential)
        #expect(preferences.followUpAlerts == .everything)
        #expect(preferences.followUpThreads == .yours)
        #expect(preferences.panelContents == .chosenTypes)
        #expect(!preferences.allowsAlert(for: .ciActivity))
        #expect(AlertPreferences(defaults: defaults).preset == .essential)
        #expect(AlertPreferences(defaults: defaults).followUpAlerts == .everything)
        #expect(AlertPreferences(defaults: defaults).followUpThreads == .yours)
        #expect(AlertPreferences(defaults: defaults).panelContents == .chosenTypes)
    }

    @Test
    func showsOnlyTheTypesTheUserAskedForOutOfTheBox() {
        let preferences = makePreferences()

        #expect(preferences.panelContents == .chosenTypes)
        #expect(preferences.shownReasons.contains(.reviewRequested))
        #expect(!preferences.shownReasons.contains(.ciActivity))
    }

    @Test
    func showsTheWholeInboxWhenAskedTo() {
        let preferences = makePreferences()

        preferences.panelContents = .everything

        #expect(NotificationReason.allCases.allSatisfy(preferences.shownReasons.contains))
        #expect(!preferences.allowsAlert(for: .ciActivity))
    }

    /// A reason with no name in this app has no checkbox either, so it cannot
    /// have been switched off and must not be filtered away as though it had.
    @Test(arguments: PanelContents.allCases)
    func alwaysShowsAReasonItHasNoNameForYet(panelContents: PanelContents) {
        let preferences = makePreferences()

        preferences.panelContents = panelContents

        #expect(preferences.shownReasons.contains(.unrecognised))
    }

    @Test
    func tellsWhoeverIsListeningAsSoonAsWhatThePanelShowsChanges() {
        let preferences = makePreferences()
        var changeCount = 0
        preferences.onShownReasonsChanged = { changeCount += 1 }

        preferences.setEnabled(false, for: .mentioned)
        preferences.panelContents = .everything

        #expect(changeCount == 2)
    }

    @Test
    func remembersWhatThePanelShowsAcrossLaunches() {
        let defaults = makeDefaults()
        AlertPreferences(defaults: defaults).panelContents = .everything

        #expect(AlertPreferences(defaults: defaults).panelContents == .everything)
    }

    private func makePreferences() -> AlertPreferences {
        AlertPreferences(defaults: makeDefaults())
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "alert-preferences-tests-\(UUID().uuidString)")!
    }
}
