import Foundation
import Testing

@testable import GitHubNotifications

struct ThreadActivityTests {
    private static let updatedAt = Date(timeIntervalSince1970: 1_700_000_000)
    private static let viewer = "octocat"

    @Test
    func namesABotByItsNameRatherThanItsLogin() throws {
        let events = try timeline(#"{"event": "commented", "actor": {"login": "coderabbitai[bot]", "type": "Bot"}, "created_at": "\#(at(-5))"}"#)

        let activity = latest(in: events)

        #expect(activity?.description == "coderabbitai (bot) commented")
    }

    @Test(arguments: [
        ("approved", "@alice approved"),
        ("changes_requested", "@alice requested changes"),
        ("commented", "@alice left a review"),
    ])
    func saysWhatAReviewConcluded(state: String, expected: String) throws {
        let events = try timeline(#"{"event": "reviewed", "user": {"login": "alice", "type": "User"}, "state": "\#(state)", "submitted_at": "\#(at(-5))"}"#)

        #expect(latest(in: events)?.description == expected)
    }

    @Test
    func picksTheNewestEventThatCausedTheNotification() throws {
        let events = try timeline(
            #"{"event": "commented", "actor": {"login": "alice", "type": "User"}, "created_at": "\#(at(-120))"}"#,
            #"{"event": "merged", "actor": {"login": "bob", "type": "User"}, "created_at": "\#(at(-3))"}"#,
            #"{"event": "labeled", "actor": {"login": "bob", "type": "User"}, "created_at": "\#(at(-2))"}"#,
        )

        #expect(latest(in: events) == .merged(by: GitHubActor(login: "bob", isBot: false)))
    }

    /// GitHub never notifies anyone about their own actions, so the user's reply
    /// after an alert is not what the alert was about.
    @Test
    func skipsTheUsersOwnEvents() throws {
        let events = try timeline(
            #"{"event": "commented", "actor": {"login": "alice", "type": "User"}, "created_at": "\#(at(-30))"}"#,
            #"{"event": "commented", "actor": {"login": "OctoCat", "type": "User"}, "created_at": "\#(at(-5))"}"#,
        )

        #expect(latest(in: events)?.description == "@alice commented")
    }

    /// An event long before the thread moved is history. Describing the
    /// thread with it would repeat an old alert word for word.
    @Test
    func saysNothingWhenNoEventIsCloseEnoughToHaveCausedIt() throws {
        let events = try timeline(#"{"event": "commented", "actor": {"login": "alice", "type": "User"}, "created_at": "\#(at(-3600))"}"#)

        #expect(latest(in: events) == nil)
    }

    @Test
    func ignoresEventsThatHappenedAfterTheNotification() throws {
        let events = try timeline(#"{"event": "closed", "actor": {"login": "alice", "type": "User"}, "created_at": "\#(at(600))"}"#)

        #expect(latest(in: events) == nil)
    }

    @Test
    func tellsAReviewRequestedFromTheUserApartFromOneForSomeoneElse() throws {
        let fromViewer = try timeline(#"{"event": "review_requested", "actor": {"login": "alice", "type": "User"}, "requested_reviewer": {"login": "octocat", "type": "User"}, "created_at": "\#(at(-5))"}"#)
        let fromTeam = try timeline(#"{"event": "review_requested", "actor": {"login": "alice", "type": "User"}, "requested_team": {"name": "platform"}, "created_at": "\#(at(-5))"}"#)

        #expect(latest(in: fromViewer)?.description == "@alice requested your review")
        #expect(latest(in: fromTeam)?.description == "@alice requested a review from platform")
    }

    @Test
    func readsACommentNamingTheUserAsAMention() throws {
        let events = try timeline(#"{"event": "commented", "actor": {"login": "alice", "type": "User"}, "body": "@octocat can you look?", "created_at": "\#(at(-5))"}"#)

        #expect(latest(in: events, reason: .mentioned)?.description == "@alice mentioned you")
        #expect(latest(in: events, reason: .subscribed)?.description == "@alice commented")
    }

    @Test
    func countsPushedCommitsByWhenTheyWereCommitted() throws {
        let events = try timeline(#"{"event": "committed", "committer": {"date": "\#(at(-20))"}}"#)

        #expect(latest(in: events) == .pushedCommits)
    }

    @Test
    func leadsWithTheReasonAndThenWhatHappened() {
        let activity = ThreadActivity.commented(by: GitHubActor(login: "sonarqubecloud[bot]", isBot: true))

        #expect(activity.caption(for: .reviewRequested) == "Review requested from you · sonarqubecloud (bot) commented")
    }

    @Test
    func dropsTheReasonWhenTheEventIsTheReasonItself() {
        let activity = ThreadActivity.reviewRequestedFromYou(by: GitHubActor(login: "alice", isBot: false))

        #expect(activity.caption(for: .reviewRequested) == "@alice requested your review")
    }

    @Test(arguments: [
        ("https://api.github.com/repos/acme/api/pulls/412", "https://api.github.com/repos/acme/api/issues/412/timeline"),
        ("https://api.github.com/repos/acme/api/issues/7", "https://api.github.com/repos/acme/api/issues/7/timeline"),
    ])
    func findsTheTimelineOfAPullRequestOrIssue(subjectURL: String, expected: String) {
        let timelineURL = TimelineEvent.timelineURL(forSubjectAt: URL(string: subjectURL)!)

        #expect(timelineURL?.absoluteString == expected)
    }

    @Test(arguments: [
        "https://api.github.com/repos/acme/api/releases/1",
        "https://api.github.com/repos/acme/api/commits/abc123",
    ])
    func findsNoTimelineForOtherSubjects(subjectURL: String) {
        #expect(TimelineEvent.timelineURL(forSubjectAt: URL(string: subjectURL)!) == nil)
    }

    private func latest(in events: [TimelineEvent], reason: NotificationReason = .reviewRequested) -> ThreadActivity? {
        let thread = Fixtures.thread(reason: reason, updatedAt: Self.updatedAt)

        return ThreadActivity.latest(in: events, for: thread, viewerLogin: Self.viewer)
    }

    private func at(_ offset: TimeInterval) -> String {
        Self.updatedAt.addingTimeInterval(offset).formatted(.iso8601)
    }

    private func timeline(_ events: String...) throws -> [TimelineEvent] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode([TimelineEvent].self, from: Data("[\(events.joined(separator: ","))]".utf8))
    }
}
