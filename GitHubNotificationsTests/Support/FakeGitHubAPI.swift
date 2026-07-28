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

    var entireInboxResult: Result<[NotificationThread], GitHubError> = .success([])
    var markThreadResult: Result<Void, GitHubError> = .success(())
    var subjectStatusResult: Result<SubjectStatus, GitHubError> = .success(.open)

    private(set) var fetchCount = 0
    private(set) var entireInboxFetchCount = 0
    private(set) var markedAsRead: [String] = []
    private(set) var markedAsDone: [String] = []
    private(set) var markedEverythingAsReadCount = 0
    private(set) var subjectStatusURLs: [URL] = []

    func fetchAuthenticatedUser(usingToken token: String) async throws -> AuthenticatedUser {
        try userResult.get()
    }

    func fetchNotifications(usingToken token: String, since lastModified: String?) async throws -> NotificationsResponse {
        fetchCount += 1

        return try notificationsResult.get()
    }

    func fetchEntireInbox(usingToken token: String) async throws -> [NotificationThread] {
        entireInboxFetchCount += 1

        return try entireInboxResult.get()
    }

    func markThreadAsRead(threadIdentifier: String, usingToken token: String) async throws {
        markedAsRead.append(threadIdentifier)

        try markThreadResult.get()
    }

    func markThreadAsDone(threadIdentifier: String, usingToken token: String) async throws {
        markedAsDone.append(threadIdentifier)

        try markThreadResult.get()
    }

    func markEverythingAsRead(usingToken token: String) async throws {
        markedEverythingAsReadCount += 1

        try markThreadResult.get()
    }

    func fetchSubjectStatus(at subjectURL: URL, usingToken token: String) async throws -> SubjectStatus {
        subjectStatusURLs.append(subjectURL)

        return try subjectStatusResult.get()
    }
}

final class InMemoryTokenStorage: TokenStorage, @unchecked Sendable {
    private var token: String?

    private(set) var wasLastReadRefused = false

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
