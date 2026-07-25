import Foundation
import Testing

@testable import GitHubNotifications

@MainActor
struct PollerTests {
    @Test(arguments: [(90.0, 90.0), (10.0, 60.0)])
    func obeysGitHubsPollIntervalButNeverPollsFasterThanAMinute(
        requestedInterval: TimeInterval,
        expectedInterval: TimeInterval,
    ) async {
        let api = FakeGitHubAPI()
        api.notificationsResult = .success(makeResponse(pollInterval: requestedInterval))
        let context = await makeContext(api: api)

        await context.poller.pollIfDue()

        #expect(context.poller.pollInterval == expectedInterval)
    }

    @Test
    func waitsForGitHubsIntervalBeforePollingAgain() async {
        let api = FakeGitHubAPI()
        let context = await makeContext(api: api)

        await context.poller.pollIfDue()
        await context.poller.pollIfDue()

        #expect(api.fetchCount == 1)
        #expect(context.poller.nextPollDueAt > Date())
    }

    @Test
    func doesNotPollWithoutAToken() async {
        let api = FakeGitHubAPI()
        let poller = Poller(
            api: api,
            auth: AuthService(api: api, storage: InMemoryTokenStorage(), log: AppLog(subsystem: "tests")),
            store: Fixtures.store(),
            log: AppLog(subsystem: "tests"),
        )

        await poller.pollIfDue()

        #expect(api.fetchCount == 0)
    }

    @Test
    func keepsTheStoredThreadsWhenTheInboxIsUnchanged() async {
        let api = FakeGitHubAPI()
        api.notificationsResult = .success(makeResponse(threads: [Fixtures.thread(id: "a")]))
        let context = await makeContext(api: api)
        await context.poller.pollIfDue()

        api.notificationsResult = .success(makeResponse(isUnchanged: true))
        context.poller.reset()
        await context.poller.pollIfDue()

        #expect(context.store.threads.map(\.id) == ["a"])
    }

    @Test
    func signsOutAndClearsTheInboxWhenTheTokenIsRevoked() async {
        let api = FakeGitHubAPI()
        api.notificationsResult = .success(makeResponse(threads: [Fixtures.thread(id: "a")]))
        let context = await makeContext(api: api)
        await context.poller.pollIfDue()

        api.notificationsResult = .failure(.invalidToken)
        context.poller.reset()
        await context.poller.pollIfDue()

        #expect(context.poller.lastError == .invalidToken)
        #expect(context.store.threads.isEmpty)
        #expect(context.auth.state == .failed(.invalidToken))
    }

    @Test
    func waitsForTheRateLimitToResetBeforeAllowingAnotherRequest() async {
        let resetAt = Date().addingTimeInterval(600)
        let api = FakeGitHubAPI()
        api.notificationsResult = .failure(.rateLimited(resetAt: resetAt))
        let context = await makeContext(api: api)

        await context.poller.pollIfDue()

        #expect(context.poller.lastError == .rateLimited(resetAt: resetAt))
        #expect(context.poller.nextPollDueAt == resetAt)
    }

    @Test
    func clearsTheErrorAfterASuccessfulPoll() async {
        let api = FakeGitHubAPI()
        api.notificationsResult = .failure(.serverFailure(statusCode: 500))
        let context = await makeContext(api: api)
        await context.poller.pollIfDue()

        #expect(context.poller.lastError == .serverFailure(statusCode: 500))

        api.notificationsResult = .success(makeResponse())
        context.poller.reset()
        await context.poller.pollIfDue()

        #expect(context.poller.lastError == nil)
        #expect(context.poller.lastSuccessAt != nil)
    }

    private struct Context {
        let auth: AuthService
        let store: NotificationStore
        let poller: Poller
    }

    private func makeContext(api: FakeGitHubAPI = FakeGitHubAPI()) async -> Context {
        let log = AppLog(subsystem: "tests")
        let auth = AuthService(api: api, storage: InMemoryTokenStorage(), log: log)
        let store = Fixtures.store()

        await auth.signIn(withToken: "ghp_valid")

        return Context(
            auth: auth,
            store: store,
            poller: Poller(api: api, auth: auth, store: store, log: log),
        )
    }

    private func makeResponse(
        threads: [NotificationThread] = [],
        isUnchanged: Bool = false,
        pollInterval: TimeInterval? = nil,
    ) -> NotificationsResponse {
        NotificationsResponse(
            threads: threads,
            isUnchanged: isUnchanged,
            lastModified: "Sat, 25 Jul 2026 04:00:00 GMT",
            pollInterval: pollInterval,
        )
    }
}
