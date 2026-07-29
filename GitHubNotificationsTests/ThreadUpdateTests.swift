import Foundation
import Testing

@testable import GitHubNotifications

struct ThreadUpdateTests {
    @Test(arguments: [
        ("https://api.github.com/repos/acme/api/issues/comments/9", ThreadUpdate.comment),
        ("https://api.github.com/repos/acme/api/pulls/comments/9", ThreadUpdate.reviewComment),
        ("https://api.github.com/repos/acme/api/discussions/comments/9", ThreadUpdate.comment),
    ])
    func readsTheKindOfCommentFromItsURL(url: String, expected: ThreadUpdate) {
        #expect(ThreadUpdate(latestCommentAPIURL: URL(string: url)!) == expected)
    }

    /// GitHub points the latest comment at the thread itself when there are no
    /// comments on it, which is not news about a comment at all.
    @Test(arguments: [
        "https://api.github.com/repos/acme/api/pulls/412",
        "https://api.github.com/repos/acme/api/issues/412",
        "https://api.github.com/repos/acme/api/comments",
    ])
    func isNotACommentWhenTheURLPointsSomewhereElse(url: String) {
        #expect(ThreadUpdate(latestCommentAPIURL: URL(string: url)!) == nil)
    }

    /// The reason is never dropped for the change. An alert reading "New comment"
    /// on its own cannot say whose comment, on what, or why it was worth being
    /// interrupted for.
    @Test(arguments: [
        (ThreadUpdate.comment, "Review requested from you · New comment"),
        (ThreadUpdate.reviewComment, "Review requested from you · New comment on the diff"),
        (ThreadUpdate.otherActivity, "Review requested from you · New activity"),
    ])
    func saysWhyTheThreadIsYoursAndWhatHappened(update: ThreadUpdate, expected: String) {
        #expect(update.caption(for: .reviewRequested) == expected)
    }

    @Test
    func saysTheReasonAloneWhenThatIsItselfTheNews() {
        let caption = ThreadUpdate.reasonForNotifying.caption(for: .reviewRequested)

        #expect(caption == NotificationReason.reviewRequested.displayName)
    }

    /// The pairing that would restate itself is dropped in the caption too, so
    /// nothing reads "New comment on a thread · New comment".
    @Test
    func doesNotRepeatItselfWhenTheReasonAlreadySaysWhatChanged() {
        #expect(ThreadUpdate.comment.caption(for: .comment) == NotificationReason.comment.displayName)
    }

    /// A row prints the reason and the change side by side, so a pairing that
    /// restates itself reads as the row being broken.
    @Test(arguments: [
        (ThreadUpdate.comment, NotificationReason.comment),
        (.otherActivity, .unrecognised),
    ])
    func addsNothingToARowWhoseReasonAlreadySaysIt(update: ThreadUpdate, reason: NotificationReason) {
        #expect(update.changeDescription(alongside: reason) == nil)
    }

    @Test(arguments: [
        (ThreadUpdate.comment, NotificationReason.reviewRequested, "New comment"),
        (.reviewComment, .comment, "New comment on the diff"),
        (.otherActivity, .reviewRequested, "New activity"),
    ])
    func stillSaysWhatChangedWhereTheReasonDoesNotCoverIt(
        update: ThreadUpdate,
        reason: NotificationReason,
        expected: String,
    ) {
        #expect(update.changeDescription(alongside: reason) == expected)
    }
}
