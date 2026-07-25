import Foundation
import Testing

@testable import GitHubNotifications

struct ThreadURLTests {
    @Test(arguments: [
        ("https://api.github.com/repos/acme/api/pulls/412", "https://github.com/acme/api/pull/412"),
        ("https://api.github.com/repos/acme/api/issues/88", "https://github.com/acme/api/issues/88"),
        ("https://api.github.com/repos/acme/api/commits/abc123", "https://github.com/acme/api/commit/abc123"),
        ("https://api.github.com/repos/acme/api/discussions/9", "https://github.com/acme/api/discussions/9"),
    ])
    func mapsSubjectAPIURLsToWebPages(subjectURL: String, expectedURL: String) {
        let thread = Fixtures.thread(subjectAPIURL: subjectURL)

        #expect(ThreadURL.derive(for: thread).absoluteString == expectedURL)
    }

    @Test(arguments: [
        (NotificationSubjectType.checkSuite, "https://github.com/acme/api/actions"),
        (NotificationSubjectType.repositoryVulnerabilityAlert, "https://github.com/acme/api/security/dependabot"),
        (NotificationSubjectType.discussion, "https://github.com/acme/api/discussions"),
        (NotificationSubjectType.repositoryInvitation, "https://github.com/acme/api/invitations"),
        (NotificationSubjectType.release, "https://github.com/acme/api/releases"),
    ])
    func fallsBackToARepositorySectionWhenGitHubGivesNoSubjectURL(
        subjectType: NotificationSubjectType,
        expectedURL: String,
    ) {
        let thread = Fixtures.thread(subjectType: subjectType, subjectAPIURL: nil)

        #expect(ThreadURL.derive(for: thread).absoluteString == expectedURL)
    }

    @Test
    func fallsBackToTheRepositoryItselfForAnUnrecognisedSubject() {
        let thread = Fixtures.thread(subjectType: .unrecognised, subjectAPIURL: nil)

        #expect(ThreadURL.derive(for: thread).absoluteString == "https://github.com/acme/api")
    }

    @Test
    func anchorsToTheLatestIssueComment() {
        let thread = Fixtures.thread(
            subjectAPIURL: "https://api.github.com/repos/acme/api/issues/88",
            latestCommentAPIURL: "https://api.github.com/repos/acme/api/issues/comments/771",
        )

        #expect(ThreadURL.derive(for: thread).absoluteString == "https://github.com/acme/api/issues/88#issuecomment-771")
    }

    @Test
    func anchorsToTheLatestReviewComment() {
        let thread = Fixtures.thread(
            subjectAPIURL: "https://api.github.com/repos/acme/api/pulls/412",
            latestCommentAPIURL: "https://api.github.com/repos/acme/api/pulls/comments/912",
        )

        #expect(ThreadURL.derive(for: thread).absoluteString == "https://github.com/acme/api/pull/412#discussion_r912")
    }

    @Test
    func ignoresALatestCommentURLThatIsNotAComment() {
        let thread = Fixtures.thread(
            subjectAPIURL: "https://api.github.com/repos/acme/api/pulls/412",
            latestCommentAPIURL: "https://api.github.com/repos/acme/api/pulls/412",
        )

        #expect(ThreadURL.derive(for: thread).absoluteString == "https://github.com/acme/api/pull/412")
    }

    @Test
    func ignoresASubjectURLThatIsNotARepositoryResource() {
        let thread = Fixtures.thread(
            subjectType: .unrecognised,
            subjectAPIURL: "https://api.github.com/user/12",
        )

        #expect(ThreadURL.derive(for: thread).absoluteString == "https://github.com/acme/api")
    }
}
