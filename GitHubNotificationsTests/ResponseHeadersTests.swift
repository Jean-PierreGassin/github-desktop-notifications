import Foundation
import Testing

@testable import GitHubNotifications

struct ResponseHeadersTests {
    @Test
    func readsTheHeadersThePollingLoopDependsOn() {
        let headers = makeHeaders([
            "X-OAuth-Scopes": "notifications, repo",
            "Last-Modified": "Thu, 25 Oct 2026 15:16:27 GMT",
            "X-Poll-Interval": "90",
            "X-RateLimit-Remaining": "4998",
            "X-RateLimit-Reset": "1700000000",
            "Retry-After": "30",
        ])

        #expect(headers.grantedScopes == [.notifications, .repository])
        #expect(headers.lastModified == "Thu, 25 Oct 2026 15:16:27 GMT")
        #expect(headers.pollInterval == 90)
        #expect(headers.rateLimitRemaining == 4998)
        #expect(headers.rateLimitResetAt == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(headers.retryAfter == 30)
    }

    @Test
    func leavesEverythingAbsentWhenGitHubSendsNothing() {
        let headers = makeHeaders([:])

        #expect(headers.grantedScopes.isEmpty)
        #expect(headers.lastModified == nil)
        #expect(headers.pollInterval == nil)
        #expect(headers.nextPageURL == nil)
    }

    @Test
    func findsTheNextPageLink() {
        let linkHeader = "<https://api.github.com/notifications?page=2>; rel=\"next\", "
            + "<https://api.github.com/notifications?page=9>; rel=\"last\""

        #expect(ResponseHeaders.parseNextPageURL(from: linkHeader)?.absoluteString
            == "https://api.github.com/notifications?page=2")
    }

    @Test
    func findsNoNextPageOnTheLastPage() {
        let linkHeader = "<https://api.github.com/notifications?page=1>; rel=\"prev\", "
            + "<https://api.github.com/notifications?page=1>; rel=\"first\""

        #expect(ResponseHeaders.parseNextPageURL(from: linkHeader) == nil)
    }

    private func makeHeaders(_ fields: [String: String]) -> ResponseHeaders {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.github.com/notifications")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: fields,
        )!

        return ResponseHeaders(response)
    }
}
