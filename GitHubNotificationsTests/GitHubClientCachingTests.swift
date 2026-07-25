import Foundation
import Testing

@testable import GitHubNotifications

/// The client handles freshness itself with `If-Modified-Since`. A caching
/// session on top of that replays old inboxes, which presents as notifications
/// silently never arriving.
struct GitHubClientCachingTests {
    @Test
    func buildsRequestsThatRefuseTheLocalCache() {
        let request = GitHubClient().makeRequest(path: "/notifications", token: "token")

        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
    }

    @Test
    func usesASessionWithNoCacheOfItsOwn() {
        let session = GitHubClient.makeUncachedSession()

        #expect(session.configuration.urlCache == nil)
        #expect(session.configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
    }
}
