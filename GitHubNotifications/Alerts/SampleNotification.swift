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

    /// Shown as a review you owe that has since been commented on, so the preview
    /// carries the whole line a real alert can carry: why the thread is yours and
    /// what has moved on it. A first-sighting sample would show the shorter half
    /// and leave the longer one to arrive unrehearsed.
    static let announcement = ThreadAnnouncement(
        thread: SampleNotification.thread,
        update: .comment,
    )
}
