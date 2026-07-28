import Foundation
import Testing

@testable import GitHubNotifications

@MainActor
struct SubjectStatusCacheTests {
    private let pullRequest = Fixtures.thread(id: "a", subjectType: .pullRequest)

    @Test
    func answersWithoutWaitingAndFillsInAfterwards() async throws {
        let api = FakeGitHubAPI()
        api.subjectStatusResult = .success(.merged)
        let cache = await makeCache(api: api)

        #expect(cache.status(for: pullRequest) == nil)

        try await settle()

        #expect(cache.status(for: pullRequest) == .merged)
    }

    @Test
    func readsASubjectOnlyOnceWhileNothingAboutItMoves() async throws {
        let api = FakeGitHubAPI()
        let cache = await makeCache(api: api)
        _ = cache.status(for: pullRequest)

        try await settle()
        _ = cache.status(for: pullRequest)
        try await settle()

        #expect(api.subjectStatusURLs.count == 1)
    }

    /// A thread that has moved may well have changed state with it, so the
    /// status is read again rather than trusted from before the change.
    @Test
    func readsASubjectAgainOnceItsThreadHasMoved() async throws {
        let api = FakeGitHubAPI()
        let cache = await makeCache(api: api)
        _ = cache.status(for: pullRequest)

        try await settle()
        _ = cache.status(for: Fixtures.thread(id: "a", updatedAt: .now, subjectType: .pullRequest))
        try await settle()

        #expect(api.subjectStatusURLs.count == 2)
    }

    /// The badge would otherwise blink out of the row on every poll that touched
    /// the thread, which reads as the panel glitching rather than as a refresh.
    @Test
    func keepsShowingTheLastKnownStatusWhileItIsBeingReadAgain() async throws {
        let api = FakeGitHubAPI()
        api.subjectStatusResult = .success(.draft)
        let cache = await makeCache(api: api)
        _ = cache.status(for: pullRequest)

        try await settle()

        #expect(cache.status(for: Fixtures.thread(id: "a", updatedAt: .now, subjectType: .pullRequest)) == .draft)
    }

    @Test(arguments: [NotificationSubjectType.commit, .release, .discussion, .checkSuite])
    func neverAsksAboutSubjectsWithNoStateToRead(subjectType: NotificationSubjectType) async throws {
        let api = FakeGitHubAPI()
        let cache = await makeCache(api: api)

        _ = cache.status(for: Fixtures.thread(id: "a", subjectType: subjectType))

        try await settle()

        #expect(api.subjectStatusURLs.isEmpty)
    }

    @Test
    func leavesTheRowWithoutABadgeWhenTheSubjectCannotBeRead() async throws {
        let api = FakeGitHubAPI()
        api.subjectStatusResult = .failure(.serverFailure(statusCode: 404))
        let cache = await makeCache(api: api)

        _ = cache.status(for: pullRequest)

        try await settle()

        #expect(cache.status(for: pullRequest) == nil)
    }

    /// A subject this token cannot see must not be asked for again on every
    /// redraw of the panel, or a private repository becomes a request loop.
    @Test
    func doesNotKeepRetryingASubjectItCannotRead() async throws {
        let api = FakeGitHubAPI()
        api.subjectStatusResult = .failure(.serverFailure(statusCode: 404))
        let cache = await makeCache(api: api)
        _ = cache.status(for: pullRequest)

        try await settle()
        _ = cache.status(for: pullRequest)
        try await settle()

        #expect(api.subjectStatusURLs.count == 1)
    }

    @Test
    func forgetsEverythingOnSignOutSoTheNextAccountStartsClean() async throws {
        let api = FakeGitHubAPI()
        api.subjectStatusResult = .success(.merged)
        let cache = await makeCache(api: api)
        _ = cache.status(for: pullRequest)

        try await settle()
        cache.clear()

        #expect(cache.status(for: pullRequest) == nil)
    }

    private func makeCache(api: FakeGitHubAPI) async -> SubjectStatusCache {
        let log = AppLog(subsystem: "tests")
        let auth = AuthService(api: api, storage: InMemoryTokenStorage(), log: log)

        await auth.signIn(withToken: "ghp_valid")

        return SubjectStatusCache(api: api, auth: auth, log: log)
    }

    private func settle() async throws {
        try await Task.sleep(for: .milliseconds(100))
    }
}
