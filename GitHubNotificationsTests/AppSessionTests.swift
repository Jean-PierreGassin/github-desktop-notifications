import Foundation
import Testing

@testable import GitHubNotifications

@MainActor
struct AppSessionTests {
    private let secondUpdate = Date(timeIntervalSince1970: 1_700_000_600)
    private let firstComment = "https://api.github.com/repos/acme/api/issues/comments/1"
    private let secondComment = "https://api.github.com/repos/acme/api/issues/comments/2"

    @Test
    func markingReadKeepsTheRowAndTellsGitHubOnlyThat() async {
        let api = FakeGitHubAPI()
        let session = await makeSession(api: api, threads: [Fixtures.thread(id: "1")])

        await session.apply(.read, to: Fixtures.thread(id: "1"))

        #expect(api.markedAsRead == ["1"])
        #expect(api.markedAsDone.isEmpty)
        #expect(session.store.threads.map(\.id) == ["1"])
        #expect(session.store.unreadCount == 0)
    }

    @Test
    func dismissingRemovesTheRowWithoutMarkingItRead() async {
        let api = FakeGitHubAPI()
        let session = await makeSession(api: api, threads: [Fixtures.thread(id: "1")])

        await session.apply(.dismissed, to: Fixtures.thread(id: "1"))

        #expect(api.markedAsRead.isEmpty)
        #expect(api.markedAsDone == ["1"])
        #expect(session.store.threads.isEmpty)
    }

    @Test
    func readAndDismissedDoesBoth() async {
        let api = FakeGitHubAPI()
        let session = await makeSession(api: api, threads: [Fixtures.thread(id: "1")])

        await session.apply(.readAndDismissed, to: Fixtures.thread(id: "1"))

        #expect(api.markedAsRead == ["1"])
        #expect(api.markedAsDone == ["1"])
        #expect(session.store.threads.isEmpty)
    }

    @Test
    func aRefusedDismissPutsTheRowBackWhereItWas() async {
        let api = FakeGitHubAPI()
        api.markThreadResult = .failure(.serverFailure(statusCode: 500))
        let threads = [Fixtures.thread(id: "1"), Fixtures.thread(id: "2"), Fixtures.thread(id: "3")]
        let session = await makeSession(api: api, threads: threads)

        await session.apply(.dismissed, to: threads[1])

        #expect(session.store.threads.map(\.id) == ["1", "2", "3"])
        #expect(session.lastActionFailure != nil)
    }

    @Test
    func aRefusedReadPutsTheDotBack() async {
        let api = FakeGitHubAPI()
        api.markThreadResult = .failure(.serverFailure(statusCode: 500))
        let session = await makeSession(api: api, threads: [Fixtures.thread(id: "1")])

        await session.apply(.read, to: Fixtures.thread(id: "1"))

        #expect(session.store.unreadCount == 1)
        #expect(session.lastActionFailure != nil)
    }

    @Test
    func markingEverythingReadIsOneRequestAndKeepsTheRows() async {
        let api = FakeGitHubAPI()
        let session = await makeSession(api: api, threads: [Fixtures.thread(id: "1"), Fixtures.thread(id: "2")])

        await session.applyToEverything(.read)

        #expect(api.markedEverythingAsReadCount == 1)
        #expect(api.markedAsDone.isEmpty)
        #expect(session.store.threads.count == 2)
        #expect(session.store.unreadCount == 0)
    }

    @Test
    func dismissingEverythingIsOneRequestPerThreadBecauseGitHubHasNoBulkEndpoint() async {
        let api = FakeGitHubAPI()
        let session = await makeSession(api: api, threads: [Fixtures.thread(id: "1"), Fixtures.thread(id: "2")])

        await session.applyToEverything(.dismissed)

        #expect(api.markedAsDone.sorted() == ["1", "2"])
        #expect(session.store.threads.isEmpty)
        #expect(session.bulkProgress == nil)
    }

    @Test
    func aBulkDismissThatFailsStopsAndSaysWhereItStopped() async {
        let api = FakeGitHubAPI()
        api.markThreadResult = .failure(.serverFailure(statusCode: 500))
        let session = await makeSession(api: api, threads: [Fixtures.thread(id: "1"), Fixtures.thread(id: "2")])

        await session.applyToEverything(.dismissed)

        #expect(api.markedAsDone == ["1"])
        #expect(session.store.threads.count == 2)
        #expect(session.lastActionFailure != nil)
    }

    @Test(arguments: [20, 11])
    func clampsAStoredRowLimitThePanelIsNoLongerBuiltFor(storedValue: Int) async {
        let defaults = makeDefaults()
        defaults.set(storedValue, forKey: "rowsPerRepository")

        let session = await makeSession(defaults: defaults)

        #expect(session.rowsPerRepository == AppSession.rowsPerRepositoryLimits.upperBound)
    }

    @Test
    func asksForAClickBehaviourOnceAndNotAgain() async {
        let defaults = makeDefaults()
        let session = await makeSession(defaults: defaults)

        #expect(session.isAskingForClickBehaviour)

        session.chooseClickBehaviour(.read)

        #expect(!session.isAskingForClickBehaviour)
        #expect(session.behaviourPreferences.clickBehaviour == .read)
        #expect(session.highlightedSettingsField == .clickBehaviour)

        let nextLaunch = await makeSession(defaults: defaults)

        #expect(!nextLaunch.isAskingForClickBehaviour)
    }

    /// The complaint that started this: a type switched off stayed silent and
    /// still took a row, so the setting looked as though it had done nothing.
    @Test
    func keepsSwitchedOffTypesOutOfThePanelEntirely() async {
        let session = await makeSession()
        session.alertPreferences.select(.essential)

        session.store.replaceAll(with: [
            Fixtures.thread(id: "wanted", reason: .reviewRequested),
            Fixtures.thread(id: "unwanted", reason: .assigned),
        ])
        session.alertPreferences.setEnabled(false, for: .assigned)

        #expect(session.store.threads.map(\.id) == ["wanted"])
        #expect(session.store.unreadCount == 1)
        #expect(session.store.groups.flatMap { $0.visibleThreads.map(\.id) } == ["wanted"])
    }

    /// The invariant, from the outside: whatever the settings, a thread has a row
    /// if and only if its type is one the app would alert on. There is no
    /// arrangement of settings that produces a row nobody was told about.
    @Test(arguments: AlertPreset.allCases)
    func givesARowToEveryTypeItAlertsOnAndNoOthers(preset: AlertPreset) async {
        let session = await makeSession()
        session.alertPreferences.select(preset)

        let inbox = NotificationReason.allCases.enumerated().map { index, reason in
            Fixtures.thread(id: "\(index)", reason: reason)
        }
        session.store.replaceAll(with: inbox)

        let shown = Set(session.store.threads.map(\.reason))
        let alerted = Set(NotificationReason.allCases.filter(session.alertPreferences.allowsAlert(for:)))

        #expect(shown == alerted)
    }

    /// Polling is conditional, so an unchanged inbox answers 304 and the panel is
    /// never handed a fresh list. Switching a type back on has to bring its rows
    /// back on the spot rather than whenever GitHub next has news.
    @Test
    func bringsATypeBackAsSoonAsItIsSwitchedOnAgain() async {
        let session = await makeSession()
        session.alertPreferences.select(.essential)
        session.store.replaceAll(with: [Fixtures.thread(id: "1", reason: .comment)])

        #expect(session.store.threads.isEmpty)

        session.alertPreferences.setEnabled(true, for: .comment)

        #expect(session.store.threads.map(\.id) == ["1"])
    }

    /// A hidden type must not be dismissed by a bulk action either. The panel
    /// says how many rows the button will clear, and the button has to mean it.
    @Test
    func leavesHiddenTypesOutOfABulkDismiss() async {
        let api = FakeGitHubAPI()
        let session = await makeSession(api: api)
        session.alertPreferences.select(.essential)
        session.store.replaceAll(with: [
            Fixtures.thread(id: "wanted", reason: .reviewRequested),
            Fixtures.thread(id: "hidden", reason: .ciActivity),
        ])

        await session.applyToEverything(.dismissed)

        #expect(api.markedAsDone == ["wanted"])
    }

    /// A refusal puts the row back, and what the app remembers about the thread
    /// has to go back with it. Forgetting on the way out left a thread that never
    /// went anywhere to be announced as new the next time someone commented.
    @Test
    func aRefusedDismissLeavesTheThreadRememberedAsWellAsOnScreen() async {
        let api = FakeGitHubAPI()
        let session = await makeSession(api: api)
        let thread = Fixtures.thread(id: "1", latestCommentAPIURL: firstComment)
        seed(thread, in: session)

        api.markThreadResult = .failure(.serverFailure(statusCode: 500))
        await session.apply(.dismissed, to: thread)

        let announced = session.ledger.selectThreadsToAnnounce(from: [commentedOn(thread)])

        #expect(announced.map(\.update) == [.comment])
    }

    /// Dismissing in bulk says done with just as dismissing one row does, so a
    /// thread that comes back after one comes back as news rather than as the next
    /// line of a conversation the user has closed.
    @Test
    func aBulkDismissForgetsTheThreadsItClears() async {
        let api = FakeGitHubAPI()
        let session = await makeSession(api: api)
        let thread = Fixtures.thread(id: "1", latestCommentAPIURL: firstComment)
        seed(thread, in: session)

        await session.applyToEverything(.dismissed)

        let announced = session.ledger.selectThreadsToAnnounce(from: [commentedOn(thread)])

        #expect(announced.map(\.update) == [.reasonForNotifying])
    }

    /// Gives the session a thread it has already told the user about, which is
    /// what makes what happens next a follow-up rather than a first sighting.
    private func seed(_ thread: NotificationThread, in session: AppSession) {
        session.store.replaceAll(with: [thread])
        _ = session.ledger.selectThreadsToAnnounce(from: [thread])
    }

    private func commentedOn(_ thread: NotificationThread) -> NotificationThread {
        Fixtures.thread(
            id: thread.id,
            reason: thread.reason,
            updatedAt: secondUpdate,
            latestCommentAPIURL: secondComment,
        )
    }

    private func makeSession(
        api: FakeGitHubAPI = FakeGitHubAPI(),
        threads: [NotificationThread] = [],
        defaults: UserDefaults? = nil,
    ) async -> AppSession {
        let session = AppSession(
            log: AppLog(subsystem: "tests"),
            api: api,
            storage: InMemoryTokenStorage(),
            defaults: defaults ?? makeDefaults(),
            supportDirectory: Fixtures.temporaryDirectory(),
        )

        // These tests are about what happens to a row, not about which types earn
        // one, so every type is switched on rather than filtering the fixtures
        // out from under them. Tests that are about the filter choose their own.
        session.alertPreferences.select(.everything)

        await session.signIn(withToken: "ghp_valid")

        // Signing in starts the polling loop, which these tests neither need nor
        // want: it ticks every second for as long as the suite runs, and a fetch
        // landing mid-test replaces the rows the test has just arranged.
        session.poller.stop()

        session.store.replaceAll(with: threads)

        return session
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "app-session-tests-\(UUID().uuidString)")!
    }
}
