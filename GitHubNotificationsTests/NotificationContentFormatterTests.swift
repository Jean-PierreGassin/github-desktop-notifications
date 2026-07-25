import Testing

@testable import GitHubNotifications

struct NotificationContentFormatterTests {
    private let thread = Fixtures.thread(reason: .reviewRequested, title: "Fix token refresh")

    @Test
    func showsRepositoryTypeAndTitleByDefault() {
        let content = NotificationContentFormatter.make(for: thread, settings: NotificationContentSettings())

        #expect(content.title == "acme/api")
        #expect(content.subtitle == NotificationReason.reviewRequested.displayName)
        #expect(content.body == "Fix token refresh")
    }

    @Test
    func dropsTheOwnerWhenTheUserWantsTheShortRepositoryName() {
        var settings = NotificationContentSettings()
        settings.showsFullRepositoryPath = false

        #expect(NotificationContentFormatter.make(for: thread, settings: settings).title == "api")
    }

    @Test
    func fallsBackToTheAppNameWhenTheRepositoryIsHidden() {
        var settings = NotificationContentSettings()
        settings.showsRepository = false

        #expect(NotificationContentFormatter.make(for: thread, settings: settings).title == "GitHub")
    }

    @Test
    func leavesTheSubtitleEmptyWhenTheReasonIsHidden() {
        var settings = NotificationContentSettings()
        settings.showsNotificationType = false

        #expect(NotificationContentFormatter.make(for: thread, settings: settings).subtitle.isEmpty)
    }

    @Test
    func alwaysKeepsTheThreadTitleSoANotificationIsNeverEmpty() {
        var settings = NotificationContentSettings()
        settings.showsRepository = false
        settings.showsNotificationType = false

        #expect(NotificationContentFormatter.make(for: thread, settings: settings).body == "Fix token refresh")
    }

    @Test
    func fallsBackToTheReasonWhenTheThreadTitleIsHidden() {
        var settings = NotificationContentSettings()
        settings.showsThreadTitle = false

        let content = NotificationContentFormatter.make(for: thread, settings: settings)

        #expect(content.body == NotificationReason.reviewRequested.displayName)
        #expect(content.subtitle.isEmpty)
    }

    @Test
    func keepsTheThreadTitleWhenBothItAndTheReasonAreHidden() {
        var settings = NotificationContentSettings()
        settings.showsThreadTitle = false
        settings.showsNotificationType = false

        #expect(NotificationContentFormatter.make(for: thread, settings: settings).body == "Fix token refresh")
    }
}
