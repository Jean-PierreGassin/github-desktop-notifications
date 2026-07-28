import Foundation

/// What has moved on a thread since the app last alerted about it.
///
/// GitHub's reason says why a thread is in your inbox, not what has just
/// happened in it, and it does not move as the thread does: a pull request you
/// were asked to review keeps `review_requested` through every comment, review
/// and check that follows. An alert built from the reason alone therefore
/// repeats itself word for word, which reads as the same notification arriving
/// over and over.
enum ThreadUpdate: String, Sendable, Codable {
    /// Nothing has been announced for this thread yet, or GitHub's reason for it
    /// has changed. Either way, why the thread is in the inbox is the news.
    case reasonForNotifying

    /// A comment on the conversation that was not there last time.
    case comment

    /// A comment left on the diff of a pull request.
    case reviewComment

    /// The thread changed without a new comment: a push, a review, a check, a
    /// closed or merged pull request. GitHub does not say which.
    case otherActivity

    /// The reason is what to say the first time round. After that the user
    /// already knows why the thread is theirs and needs to know what changed.
    func summary(for reason: NotificationReason) -> String {
        switch self {
        case .reasonForNotifying: reason.displayName
        case .comment: "New comment"
        case .reviewComment: "New comment on the diff"
        case .otherActivity: "New activity"
        }
    }

    /// GitHub names no event, so the kind of comment is read from the shape of
    /// the URL it gives for the newest one, the same way ``ThreadURL`` reads it
    /// for the anchor. A URL that points at anything other than a comment, which
    /// is what GitHub sends for a thread that has none, is not an update at all.
    init?(latestCommentAPIURL: URL) {
        let pathSegments = latestCommentAPIURL.pathComponents.filter { $0 != "/" }

        guard pathSegments.count >= 2, pathSegments[pathSegments.count - 2] == "comments" else {
            return nil
        }

        self = pathSegments.contains("pulls") ? .reviewComment : .comment
    }
}

/// A thread and what changed about it, carried together from the poll that
/// noticed the change to the alert that reports it.
///
/// What changed can only be worked out by comparing a thread against the last
/// state announced for it, so it is settled once, where that record is kept,
/// rather than guessed at again when the alert is built.
struct ThreadAnnouncement: Sendable, Equatable, Codable, Identifiable {
    let thread: NotificationThread
    let update: ThreadUpdate

    var id: String { thread.id }
}
