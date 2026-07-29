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

    /// What changed, on its own, for the panel rows that already say why the
    /// thread is there. There is nothing to add when the reason is the news.
    var changeDescription: String? {
        switch self {
        case .reasonForNotifying: nil
        case .comment: "New comment"
        case .reviewComment: "New comment on the diff"
        case .otherActivity: "New activity"
        }
    }

    /// The one line the app says about a thread: why it reached the user, and
    /// what has moved on it since. Both the panel row and the macOS alert print
    /// this, so the two can never describe the same thread differently.
    ///
    /// The reason is always there. Leading with the change alone answered "what
    /// happened" while dropping "why is this mine", which left an alert reading
    /// "New comment" with nothing to say whose comment, on what, or why it was
    /// worth interrupting for.
    func caption(for reason: NotificationReason) -> String {
        guard let change = changeDescription(alongside: reason) else {
            return reason.displayName
        }

        return "\(reason.displayName) · \(change)"
    }

    /// What changed, for a caption that is already showing `reason` next to it,
    /// or nothing when the reason has said it.
    ///
    /// A caption prints the two together, so a pairing that restates itself
    /// reads as a bug rather than as detail: "New comment on a thread · New
    /// comment".
    func changeDescription(alongside reason: NotificationReason) -> String? {
        guard !reasonsThatAlreadySayIt.contains(reason) else {
            return nil
        }

        return changeDescription
    }

    /// Reasons whose own wording already covers this change. Kept narrow on
    /// purpose: only where the row would say the same thing twice, not merely
    /// where the two are related. A diff comment on a thread you are following
    /// for its comments is still worth the distinction.
    private var reasonsThatAlreadySayIt: Set<NotificationReason> {
        switch self {
        case .comment: [.comment]
        case .otherActivity: [.unrecognised]
        case .reasonForNotifying, .reviewComment: []
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

    /// Why this thread reached the user and what has moved on it, worded exactly
    /// as its row in the panel words it.
    var caption: String {
        update.caption(for: thread.reason)
    }
}
