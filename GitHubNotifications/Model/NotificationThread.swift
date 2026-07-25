import Foundation

enum NotificationSubjectType: String, Sendable, Codable {
    case issue = "Issue"
    case pullRequest = "PullRequest"
    case commit = "Commit"
    case release = "Release"
    case discussion = "Discussion"
    case checkSuite = "CheckSuite"
    case repositoryVulnerabilityAlert = "RepositoryVulnerabilityAlert"
    case repositoryInvitation = "RepositoryInvitation"
    case repositoryDependabotAlertsThread = "RepositoryDependabotAlertsThread"
    case unrecognised

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)

        self = NotificationSubjectType(rawValue: rawValue) ?? .unrecognised
    }
}

struct NotificationSubject: Sendable, Equatable, Codable {
    let title: String
    let type: NotificationSubjectType
    let apiURL: URL?
    let latestCommentAPIURL: URL?

    enum CodingKeys: String, CodingKey {
        case title
        case type
        case apiURL = "url"
        case latestCommentAPIURL = "latest_comment_url"
    }
}

struct RepositoryOwner: Sendable, Equatable, Codable {
    let login: String
    let avatarURL: URL?

    enum CodingKeys: String, CodingKey {
        case login
        case avatarURL = "avatar_url"
    }
}

struct NotificationRepository: Sendable, Equatable, Codable, Identifiable {
    let id: Int
    let name: String
    let fullName: String
    let isPrivate: Bool
    let htmlURL: URL
    let owner: RepositoryOwner

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case isPrivate = "private"
        case htmlURL = "html_url"
        case owner
    }
}

struct NotificationThread: Sendable, Equatable, Codable, Identifiable {
    let id: String
    let isUnread: Bool
    let reason: NotificationReason
    let updatedAt: Date
    let subject: NotificationSubject
    let repository: NotificationRepository

    enum CodingKeys: String, CodingKey {
        case id
        case isUnread = "unread"
        case reason
        case updatedAt = "updated_at"
        case subject
        case repository
    }

    /// GitHub's inbox endpoint returns unread threads only, so a thread the user
    /// has read never comes back marked read - it simply stops coming back. The
    /// read copy is made here and kept locally.
    func markedRead() -> NotificationThread {
        marked(unread: false)
    }

    /// Used to put a row back when GitHub refuses the change behind it.
    func markedUnread() -> NotificationThread {
        marked(unread: true)
    }

    private func marked(unread: Bool) -> NotificationThread {
        NotificationThread(
            id: id,
            isUnread: unread,
            reason: reason,
            updatedAt: updatedAt,
            subject: subject,
            repository: repository,
        )
    }
}
