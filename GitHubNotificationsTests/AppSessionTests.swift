import Foundation
import Testing

@testable import GitHubNotifications

@MainActor
struct AppSessionTests {
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
        session.alertPreferences.panelContents = .chosenTypes
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

    /// Polling is conditional, so an unchanged inbox answers 304 and the panel is
    /// never handed a fresh list. Switching a type back on has to bring its rows
    /// back on the spot rather than whenever GitHub next has news.
    @Test
    func bringsATypeBackAsSoonAsItIsSwitchedOnAgain() async {
        let session = await makeSession()
        session.alertPreferences.panelContents = .chosenTypes
        session.alertPreferences.select(.essential)
        session.store.replaceAll(with: [Fixtures.thread(id: "1", reason: .comment)])

        #expect(session.store.threads.isEmpty)

        session.alertPreferences.setEnabled(true, for: .comment)

        #expect(session.store.threads.map(\.id) == ["1"])
    }

    @Test
    func showsTheWholeInboxForAUserWhoAsksForIt() async {
        let session = await makeSession()
        session.alertPreferences.select(.essential)
        session.alertPreferences.panelContents = .everything

        session.store.replaceAll(with: [Fixtures.thread(id: "1", reason: .ciActivity)])

        #expect(session.store.threads.map(\.id) == ["1"])
        #expect(!session.alertPreferences.allowsAlert(for: .ciActivity))
    }

    /// A hidden type must not be dismissed by a bulk action either. The panel
    /// says how many rows the button will clear, and the button has to mean it.
    @Test
    func leavesHiddenTypesOutOfABulkDismiss() async {
        let api = FakeGitHubAPI()
        let session = await makeSession(api: api)
        session.alertPreferences.panelContents = .chosenTypes
        session.alertPreferences.select(.essential)
        session.store.replaceAll(with: [
            Fixtures.thread(id: "wanted", reason: .reviewRequested),
            Fixtures.thread(id: "hidden", reason: .ciActivity),
        ])

        await session.applyToEverything(.dismissed)

        #expect(api.markedAsDone == ["wanted"])
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

        // These tests are about what happens to a row, not about which rows the
        // user has asked for, so the panel is left showing everything rather
        // than filtering the fixtures out from under them.
        session.alertPreferences.panelContents = .everything

        await session.signIn(withToken: "ghp_valid")
        session.store.replaceAll(with: threads)

        return session
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "app-session-tests-\(UUID().uuidString)")!
    }
}
