import Foundation
import Testing

@testable import GitHubNotifications

/// Serialized because the URL protocol stub is shared process-wide.
@Suite(.serialized)
struct GitHubClientTests {
    private static let notificationJSON = """
    [{
      "id": "412",
      "unread": true,
      "reason": "review_requested",
      "updated_at": "2026-07-25T04:00:00Z",
      "subject": {
        "title": "Fix token refresh",
        "url": "https://api.github.com/repos/acme/api/pulls/412",
        "latest_comment_url": null,
        "type": "PullRequest"
      },
      "repository": {
        "id": 1,
        "name": "api",
        "full_name": "acme/api",
        "private": true,
        "html_url": "https://github.com/acme/api",
        "owner": { "login": "acme", "avatar_url": "https://avatars.githubusercontent.com/u/1" }
      }
    }]
    """

    @Test
    func decodesNotificationsAndSendsTheConditionalHeader() async throws {
        StubURLProtocol.respond = { _ in
            .init(headers: ["Last-Modified": "Sat, 25 Jul 2026 04:00:00 GMT", "X-Poll-Interval": "75"],
                  body: Self.notificationJSON)
        }

        let response = try await makeClient().fetchNotifications(usingToken: "token", since: "earlier")

        #expect(response.threads.count == 1)
        #expect(response.threads[0].reason == .reviewRequested)
        #expect(response.threads[0].repository.isPrivate)
        #expect(response.pollInterval == 75)
        #expect(response.lastModified == "Sat, 25 Jul 2026 04:00:00 GMT")
        #expect(StubURLProtocol.receivedRequests[0].value(forHTTPHeaderField: "If-Modified-Since") == "earlier")
    }

    /// A conditional 200 carries only what changed, so the whole inbox has to be
    /// re-read or every unchanged notification disappears from the panel.
    @Test
    func rereadsTheWholeInboxAfterAConditionalRequestReportsAChange() async throws {
        StubURLProtocol.respond = { _ in .init(body: Self.notificationJSON) }

        _ = try await makeClient().fetchNotifications(usingToken: "token", since: "earlier")

        #expect(StubURLProtocol.receivedRequests.count == 2)
        #expect(StubURLProtocol.receivedRequests[0].value(forHTTPHeaderField: "If-Modified-Since") == "earlier")
        #expect(StubURLProtocol.receivedRequests[1].value(forHTTPHeaderField: "If-Modified-Since") == nil)
    }

    @Test
    func asksOnlyOnceWhenThereIsNoPreviousTimestamp() async throws {
        StubURLProtocol.respond = { _ in .init(body: Self.notificationJSON) }

        _ = try await makeClient().fetchNotifications(usingToken: "token", since: nil)

        #expect(StubURLProtocol.receivedRequests.count == 1)
    }

    @Test
    func reportsAnUnchangedInboxWithoutTouchingTheStoredThreads() async throws {
        StubURLProtocol.respond = { _ in .init(statusCode: 304, body: "") }

        let response = try await makeClient().fetchNotifications(usingToken: "token", since: "earlier")

        #expect(response.isUnchanged)
        #expect(response.threads.isEmpty)
        #expect(response.lastModified == "earlier")
    }

    @Test
    func followsPaginationUntilGitHubStopsOfferingANextPage() async throws {
        StubURLProtocol.respond = { request in
            let isFirstPage = request.url?.query()?.contains("page=2") != true

            return .init(
                headers: isFirstPage
                    ? ["Link": "<https://api.github.com/notifications?page=2>; rel=\"next\""]
                    : [:],
                body: Self.notificationJSON,
            )
        }

        let response = try await makeClient().fetchNotifications(usingToken: "token", since: nil)

        #expect(response.threads.count == 2)
        #expect(StubURLProtocol.receivedRequests.count == 2)
    }

    @Test
    func reportsARevokedToken() async {
        StubURLProtocol.respond = { _ in .init(statusCode: 401, body: "{}") }

        await #expect(throws: GitHubError.invalidToken) {
            try await makeClient().fetchNotifications(usingToken: "token", since: nil)
        }
    }

    @Test
    func reportsRateLimitingWithTheResetTime() async {
        StubURLProtocol.respond = { _ in
            .init(
                statusCode: 403,
                headers: ["X-RateLimit-Remaining": "0", "X-RateLimit-Reset": "1700000000"],
                body: "{}",
            )
        }

        await #expect(throws: GitHubError.rateLimited(resetAt: Date(timeIntervalSince1970: 1_700_000_000))) {
            try await makeClient().fetchNotifications(usingToken: "token", since: nil)
        }
    }

    @Test
    func reportsASecondaryRateLimitAsASlowDown() async {
        StubURLProtocol.respond = { _ in .init(statusCode: 429, headers: ["Retry-After": "45"], body: "{}") }

        await #expect(throws: GitHubError.askedToSlowDown(retryAfter: 45)) {
            try await makeClient().fetchNotifications(usingToken: "token", since: nil)
        }
    }

    @Test
    func reportsUnreadablePayloads() async {
        StubURLProtocol.respond = { _ in .init(body: "not json") }

        await #expect(throws: GitHubError.malformedResponse) {
            try await makeClient().fetchNotifications(usingToken: "token", since: nil)
        }
    }

    @Test
    func readsTheGrantedScopesWhenValidatingAToken() async throws {
        StubURLProtocol.respond = { _ in
            .init(
                headers: ["X-OAuth-Scopes": "notifications, read:user"],
                body: #"{"login": "octocat", "avatar_url": "https://avatars.githubusercontent.com/u/1"}"#,
            )
        }

        let user = try await makeClient().fetchAuthenticatedUser(usingToken: "token")

        #expect(user.account.login == "octocat")
        #expect(!user.canSeePrivateRepositories)
    }

    @Test
    func authenticatesEveryRequestAsABearerToken() async throws {
        StubURLProtocol.respond = { _ in .init(body: "[]") }

        _ = try await makeClient().fetchNotifications(usingToken: "secret", since: nil)

        #expect(StubURLProtocol.receivedRequests[0].value(forHTTPHeaderField: "Authorization") == "Bearer secret")
    }

    @Test
    func asksForTheLatestReleaseWithoutSpendingTheUsersRateLimit() async throws {
        StubURLProtocol.respond = { _ in .init(body: Self.releaseJSON) }

        let release = try await makeClient().fetchLatestRelease(usingToken: "secret")

        #expect(release?.version == "1.3.0")
        #expect(release?.downloadURL.lastPathComponent == "GitHubNotifications-1.3.0.zip")
        #expect(StubURLProtocol.receivedRequests[0].value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test
    func fallsBackToTheTokenOnceWhenTheAnonymousLimitIsHit() async throws {
        var responses = 0
        StubURLProtocol.respond = { _ in
            responses += 1

            return responses == 1 ? .init(statusCode: 403, body: "") : .init(body: Self.releaseJSON)
        }

        let release = try await makeClient().fetchLatestRelease(usingToken: "secret")

        #expect(release?.version == "1.3.0")
        #expect(StubURLProtocol.receivedRequests.count == 2)
        #expect(StubURLProtocol.receivedRequests[1].value(forHTTPHeaderField: "Authorization") == "Bearer secret")
    }

    @Test
    func givesUpOnTheAnonymousLimitWhenThereIsNoTokenToFallBackOn() async {
        StubURLProtocol.respond = { _ in .init(statusCode: 403, body: "") }

        await #expect(throws: (any Error).self) {
            try await makeClient().fetchLatestRelease(usingToken: nil)
        }

        #expect(StubURLProtocol.receivedRequests.count == 1)
    }

    private static let releaseJSON = """
    {
      "tag_name": "v1.3.0",
      "html_url": "https://github.com/Jean-PierreGassin/github-desktop-notifications/releases/tag/v1.3.0",
      "published_at": "2026-07-25T04:00:00Z",
      "draft": false,
      "prerelease": false,
      "assets": [
        { "name": "GitHubNotifications-1.3.0.dmg", "browser_download_url": "https://example.invalid/app.dmg" },
        { "name": "GitHubNotifications-1.3.0.zip", "browser_download_url":
          "https://example.invalid/GitHubNotifications-1.3.0.zip" }
      ]
    }
    """

    private func makeClient() -> GitHubClient {
        GitHubClient(session: StubURLProtocol.makeSession())
    }
}
