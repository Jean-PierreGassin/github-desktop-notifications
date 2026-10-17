import Foundation
import Testing

@testable import GitHubNotifications

@MainActor
struct ThreadActivityCacheTests {
    private static let updatedAt = Date(timeIntervalSince1970: 1_700_000_000)

    private let pullRequest = Fixtures.thread(id: "a", updatedAt: ThreadActivityCacheTests.updatedAt)

    @Test
    func describesAThreadFromItsTimeline() async throws {
        let api = FakeGitHubAPI()
        api.timelineResult = .success([try approval()])
        let cache = await makeCache(api: api)

        let activity = await cache.describe(pullRequest)

        #expect(activity == .reviewed(by: GitHubActor(login: "alice", isBot: false), verdict: .approved))
        #expect(api.timelineURLs.map(\.absoluteString) == ["https://api.github.com/repos/acme/api/issues/412/timeline"])
    }

    /// An alert reads the timeline before it is posted, and the row drawn for
    /// the same thread must not spend a second request on it.
    @Test
    func readsATimelineOnlyOnceWhileNothingAboutTheThreadMoves() async throws {
        let api = FakeGitHubAPI()
        api.timelineResult = .success([try approval()])
        let cache = await makeCache(api: api)

        _ = await cache.describe(pullRequest)
        let shownOnRow = cache.activity(for: pullRequest)

        #expect(shownOnRow != nil)
        #expect(api.timelineURLs.count == 1)
    }

    @Test
    func fillsInARowOnceItsTimelineLands() async throws {
        let api = FakeGitHubAPI()
        api.timelineResult = .success([try approval()])
        let cache = await makeCache(api: api)

        #expect(cache.activity(for: pullRequest) == nil)

        try await waitUntil { cache.hasSettled }

        #expect(cache.activity(for: pullRequest) != nil)
    }

    @Test
    func leavesTheThreadUndescribedWhenTheTimelineCannotBeRead() async throws {
        let api = FakeGitHubAPI()
        api.timelineResult = .failure(.serverFailure(statusCode: 404))
        let cache = await makeCache(api: api)

        #expect(await cache.describe(pullRequest) == nil)
    }

    @Test
    func forgetsEverythingOnSignOut() async throws {
        let api = FakeGitHubAPI()
        api.timelineResult = .success([try approval()])
        let cache = await makeCache(api: api)
        _ = await cache.describe(pullRequest)

        cache.clear()

        #expect(cache.activity(for: pullRequest) == nil)
    }

    private func approval() throws -> TimelineEvent {
        let submittedAt = Self.updatedAt.addingTimeInterval(-5).formatted(.iso8601)
        let json = #"{"event": "reviewed", "user": {"login": "alice", "type": "User"}, "state": "approved", "submitted_at": "\#(submittedAt)"}"#

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(TimelineEvent.self, from: Data(json.utf8))
    }

    private func makeCache(api: FakeGitHubAPI) async -> ThreadActivityCache {
        let log = AppLog(subsystem: "tests")
        let auth = AuthService(api: api, storage: InMemoryTokenStorage(), log: log)

        await auth.signIn(withToken: "ghp_valid")

        return ThreadActivityCache(api: api, auth: auth, log: log)
    }
}
