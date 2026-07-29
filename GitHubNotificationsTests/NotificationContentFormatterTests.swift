import Testing

@testable import GitHubNotifications

struct NotificationContentFormatterTests {
    private let thread = Fixtures.thread(reason: .reviewRequested, title: "Fix token refresh")

    @Test
    func showsRepositoryTypeAndTitleByDefault() {
        let content = NotificationContentFormatter.make(for: announcement(), settings: NotificationContentSettings())

        #expect(content.title == "acme/api")
        #expect(content.subtitle == NotificationReason.reviewRequested.displayName)
        #expect(content.body == "Fix token refresh")
    }

    /// A follow-up adds what changed to why the thread is yours rather than
    /// replacing it. "New comment" on its own named neither the pull request the
    /// user owed a review on nor the fact that they owed one.
    @Test
    func saysWhyTheThreadIsYoursAndWhatChangedOnAFollowUp() {
        let content = NotificationContentFormatter.make(
            for: announcement(update: .comment),
            settings: NotificationContentSettings(),
        )

        #expect(content.subtitle == "Review requested from you · New comment")
        #expect(content.body == "Fix token refresh")
    }

    /// The alert and the row for one thread are worded from the same caption, so
    /// a banner can never say something its row contradicts.
    @Test(arguments: [ThreadUpdate.reasonForNotifying, .comment, .reviewComment, .otherActivity])
    func saysExactlyWhatTheRowForTheSameThreadSays(update: ThreadUpdate) {
        let announcement = announcement(update: update)
        let content = NotificationContentFormatter.make(for: announcement, settings: NotificationContentSettings())

        #expect(content.subtitle == announcement.caption)
    }

    @Test
    func dropsTheOwnerWhenTheUserWantsTheShortRepositoryName() {
        var settings = NotificationContentSettings()
        settings.showsFullRepositoryPath = false

        #expect(NotificationContentFormatter.make(for: announcement(), settings: settings).title == "api")
    }

    @Test
    func fallsBackToTheAppNameWhenTheRepositoryIsHidden() {
        var settings = NotificationContentSettings()
        settings.showsRepository = false

        #expect(NotificationContentFormatter.make(for: announcement(), settings: settings).title == "GitHub")
    }

    @Test
    func leavesTheSubtitleEmptyWhenTheReasonIsHidden() {
        var settings = NotificationContentSettings()
        settings.showsNotificationType = false

        #expect(NotificationContentFormatter.make(for: announcement(), settings: settings).subtitle.isEmpty)
    }

    @Test
    func alwaysKeepsTheThreadTitleSoANotificationIsNeverEmpty() {
        var settings = NotificationContentSettings()
        settings.showsRepository = false
        settings.showsNotificationType = false

        #expect(NotificationContentFormatter.make(for: announcement(), settings: settings).body == "Fix token refresh")
    }

    @Test
    func fallsBackToTheReasonWhenTheThreadTitleIsHidden() {
        var settings = NotificationContentSettings()
        settings.showsThreadTitle = false

        let content = NotificationContentFormatter.make(for: announcement(), settings: settings)

        #expect(content.body == NotificationReason.reviewRequested.displayName)
        #expect(content.subtitle.isEmpty)
    }

    @Test
    func keepsTheThreadTitleWhenBothItAndTheReasonAreHidden() {
        var settings = NotificationContentSettings()
        settings.showsThreadTitle = false
        settings.showsNotificationType = false

        #expect(NotificationContentFormatter.make(for: announcement(), settings: settings).body == "Fix token refresh")
    }

    private func announcement(update: ThreadUpdate = .reasonForNotifying) -> ThreadAnnouncement {
        Fixtures.announcement(thread: thread, update: update)
    }
}
