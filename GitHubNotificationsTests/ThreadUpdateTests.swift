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

    @Test(arguments: [
        (ThreadUpdate.comment, "New comment"),
        (ThreadUpdate.reviewComment, "New comment on the diff"),
        (ThreadUpdate.otherActivity, "New activity"),
    ])
    func saysWhatHappenedRatherThanWhyTheThreadIsInTheInbox(update: ThreadUpdate, expected: String) {
        #expect(update.summary(for: .reviewRequested) == expected)
    }

    @Test
    func fallsBackToTheReasonWhenThatIsItselfTheNews() {
        let summary = ThreadUpdate.reasonForNotifying.summary(for: .reviewRequested)

        #expect(summary == NotificationReason.reviewRequested.displayName)
    }
}
