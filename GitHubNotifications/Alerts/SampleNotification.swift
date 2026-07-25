import Foundation

/// A representative notification used for the settings preview and the test
/// alert, so both show exactly what a real one will look like.
enum SampleNotification {
    static let thread = NotificationThread(
        id: "sample",
        isUnread: true,
        reason: .reviewRequested,
        updatedAt: Date(),
        subject: NotificationSubject(
            title: "Refresh expired tokens before retrying",
            type: .pullRequest,
            apiURL: nil,
            latestCommentAPIURL: nil,
        ),
        repository: NotificationRepository(
            id: 0,
            name: "platform-api",
            fullName: "your-org/platform-api",
            isPrivate: true,
            htmlURL: URL(string: "https://github.com")!,
            owner: RepositoryOwner(login: "your-org", avatarURL: nil),
        ),
    )
}
