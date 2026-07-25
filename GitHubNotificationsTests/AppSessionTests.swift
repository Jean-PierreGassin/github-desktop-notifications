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

        await session.signIn(withToken: "ghp_valid")
        session.store.replaceAll(with: threads)

        return session
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "app-session-tests-\(UUID().uuidString)")!
    }
}
