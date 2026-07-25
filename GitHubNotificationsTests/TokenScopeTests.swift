import Testing

@testable import GitHubNotifications

struct TokenScopeTests {
    @Test
    func parsesTheScopeHeaderIntoKnownScopes() {
        let grantedScopes = TokenScope.parse(headerValue: "notifications, repo, read:user")

        #expect(grantedScopes == [.notifications, .repository, .readUser])
    }

    @Test
    func ignoresScopesTheAppDoesNotUse() {
        let grantedScopes = TokenScope.parse(headerValue: "gist, workflow, notifications")

        #expect(grantedScopes == [.notifications])
    }

    @Test
    func returnsNoScopesForAnEmptyHeader() {
        #expect(TokenScope.parse(headerValue: "").isEmpty)
    }
}
