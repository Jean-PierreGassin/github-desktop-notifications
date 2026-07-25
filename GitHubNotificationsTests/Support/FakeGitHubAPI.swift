import Foundation

@testable import GitHubNotifications

final class FakeGitHubAPI: GitHubAPI, @unchecked Sendable {
    var userResult: Result<AuthenticatedUser, GitHubError> = .success(
        AuthenticatedUser(
            account: GitHubAccount(login: "octocat", avatarURL: nil),
            grantedScopes: [.notifications, .repository, .readUser],
        ),
    )
    var notificationsResult: Result<NotificationsResponse, GitHubError> = .success(
        NotificationsResponse(threads: [], isUnchanged: false, lastModified: nil, pollInterval: nil),
    )

    private(set) var fetchCount = 0

    func fetchAuthenticatedUser(usingToken token: String) async throws -> AuthenticatedUser {
        try userResult.get()
    }

    func fetchNotifications(usingToken token: String, since lastModified: String?) async throws -> NotificationsResponse {
        fetchCount += 1

        return try notificationsResult.get()
    }

    func markThreadAsRead(threadIdentifier: String, usingToken token: String) async throws {}

    func markThreadAsDone(threadIdentifier: String, usingToken token: String) async throws {}

    func markEverythingAsRead(usingToken token: String) async throws {}
}

final class InMemoryTokenStorage: TokenStorage, @unchecked Sendable {
    private var token: String?

    init(token: String? = nil) {
        self.token = token
    }

    func readToken() -> String? {
        token
    }

    func writeToken(_ newToken: String) throws {
        token = newToken
    }

    func deleteToken() {
        token = nil
    }
}
