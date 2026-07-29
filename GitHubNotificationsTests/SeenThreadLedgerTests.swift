import Foundation
import Testing

@testable import GitHubNotifications

@MainActor
struct SeenThreadLedgerTests {
    private let firstUpdate = Date(timeIntervalSince1970: 1_700_000_000)
    private let secondUpdate = Date(timeIntervalSince1970: 1_700_000_600)
    private let thirdUpdate = Date(timeIntervalSince1970: 1_700_001_200)
    private let firstComment = "https://api.github.com/repos/acme/api/issues/comments/1"
    private let secondComment = "https://api.github.com/repos/acme/api/issues/comments/2"

    @Test
    func announcesNothingOnTheFirstFetchAfterSigningIn() {
        let ledger = makeLedger()
        let inbox = [Fixtures.thread(id: "a"), Fixtures.thread(id: "b")]

        #expect(ledger.selectThreadsToAnnounce(from: inbox).isEmpty)
    }

    @Test
    func announcesThreadsThatArriveAfterSeeding() {
        let ledger = makeLedger()
        _ = ledger.selectThreadsToAnnounce(from: [Fixtures.thread(id: "a")])

        let announced = ledger.selectThreadsToAnnounce(from: [Fixtures.thread(id: "a"), Fixtures.thread(id: "b")])

        #expect(announced.map(\.id) == ["b"])
    }

    @Test
    func announcesAThreadAgainWhenItIsUpdated() {
        let ledger = makeLedger()
        _ = ledger.selectThreadsToAnnounce(from: [Fixtures.thread(id: "a", updatedAt: firstUpdate)])

        let announced = ledger.selectThreadsToAnnounce(from: [Fixtures.thread(id: "a", updatedAt: secondUpdate)])

        #expect(announced.map(\.id) == ["a"])
    }

    @Test
    func doesNotAnnounceAnUnchangedThread() {
        let ledger = makeLedger()
        let inbox = [Fixtures.thread(id: "a", updatedAt: firstUpdate)]
        _ = ledger.selectThreadsToAnnounce(from: inbox)

        #expect(ledger.selectThreadsToAnnounce(from: inbox).isEmpty)
    }

    @Test
    func doesNotAnnounceAThreadThatIsAlreadyRead() {
        let ledger = makeLedger()
        _ = ledger.selectThreadsToAnnounce(from: [])

        let announced = ledger.selectThreadsToAnnounce(from: [Fixtures.thread(id: "a", isUnread: false)])

        #expect(announced.isEmpty)
    }

    @Test
    func leadsWithTheReasonTheFirstTimeAThreadIsAnnounced() {
        let ledger = makeLedger()
        _ = ledger.selectThreadsToAnnounce(from: [])

        let announced = ledger.selectThreadsToAnnounce(from: [Fixtures.thread(id: "a", reason: .reviewRequested)])

        #expect(announced.map(\.update) == [.reasonForNotifying])
    }

    /// The point of the change: a thread the user has already been told about
    /// must not arrive a second time wearing the same words.
    @Test
    func saysWhatChangedWhenAThreadIsAnnouncedAgain() {
        let ledger = makeLedger()
        _ = ledger.selectThreadsToAnnounce(from: [reviewRequest(commentAPIURL: firstComment)])

        let announced = ledger.selectThreadsToAnnounce(from: [
            reviewRequest(updatedAt: secondUpdate, commentAPIURL: secondComment),
        ])

        #expect(announced.map(\.update) == [.comment])
    }

    /// GitHub sends the newest comment whether or not a comment is what moved,
    /// so an unchanged one means the update was something else.
    @Test
    func fallsBackToActivityWhenTheThreadMovesWithoutANewComment() {
        let ledger = makeLedger()
        _ = ledger.selectThreadsToAnnounce(from: [reviewRequest(commentAPIURL: firstComment)])

        let announced = ledger.selectThreadsToAnnounce(from: [
            reviewRequest(updatedAt: secondUpdate, commentAPIURL: firstComment),
        ])

        #expect(announced.map(\.update) == [.otherActivity])
    }

    /// A thread that now concerns the user more directly leads with the new
    /// reason, because that is the news rather than the comment carrying it.
    @Test
    func leadsWithTheReasonAgainWhenGitHubChangesIt() {
        let ledger = makeLedger()
        _ = ledger.selectThreadsToAnnounce(from: [Fixtures.thread(id: "a", reason: .subscribed)])

        let announced = ledger.selectThreadsToAnnounce(from: [
            Fixtures.thread(id: "a", reason: .mentioned, updatedAt: secondUpdate, latestCommentAPIURL: secondComment),
        ])

        #expect(announced.map(\.update) == [.reasonForNotifying])
    }

    /// The one door left open for a thread the user has quietened, so it has to
    /// stay a door rather than becoming a gap: a review request that becomes a
    /// mention is news, and is what makes "follow up on threads that are yours"
    /// safe to have as the default.
    @Test
    func leadsWithTheReasonWhenAReviewRequestBecomesAMention() {
        let ledger = makeLedger()
        _ = ledger.selectThreadsToAnnounce(from: [reviewRequest(commentAPIURL: firstComment)])

        let announced = ledger.selectThreadsToAnnounce(from: [
            Fixtures.thread(
                id: "a",
                reason: .mentioned,
                updatedAt: secondUpdate,
                latestCommentAPIURL: secondComment,
            ),
        ])

        #expect(announced.map(\.update) == [.reasonForNotifying])
    }

    /// The hole this closes. Reading a notification takes it out of the unread
    /// inbox and out of every fetch after it, so forgetting threads the moment
    /// they left meant a comment days later brought one back looking like a
    /// thread the app had never seen, and announced the reason all over again.
    /// Reading a notification is the most ordinary thing there is, and it was
    /// undoing every follow-up rule the user had set.
    @Test
    func remembersAThreadThatLeftTheInboxWhenItWasRead() {
        let ledger = makeLedger()
        _ = ledger.selectThreadsToAnnounce(from: [reviewRequest(commentAPIURL: firstComment)])

        _ = ledger.selectThreadsToAnnounce(from: [])

        let announced = ledger.selectThreadsToAnnounce(from: [
            reviewRequest(updatedAt: secondUpdate, commentAPIURL: secondComment),
        ])

        #expect(announced.map(\.update) == [.comment])
    }

    /// Dismissing is not reading. It says done with, exactly as it does on
    /// GitHub, so a thread that comes back after one is news again.
    @Test
    func announcesAThreadAgainAfterItWasDismissed() {
        let ledger = makeLedger()
        _ = ledger.selectThreadsToAnnounce(from: [reviewRequest(commentAPIURL: firstComment)])

        ledger.forget("a")

        let announced = ledger.selectThreadsToAnnounce(from: [
            reviewRequest(updatedAt: secondUpdate, commentAPIURL: secondComment),
        ])

        #expect(announced.map(\.update) == [.reasonForNotifying])
    }

    /// Being asked again after you have actually reviewed. Reviewing makes you a
    /// participant, so what follows is reasoned `subscribed` and goes quiet;
    /// being asked again escalates it straight back to the front.
    @Test
    func leadsWithTheAskWhenAReviewIsRequestedAgainAfterYouReviewed() {
        let ledger = makeLedger()
        _ = ledger.selectThreadsToAnnounce(from: [reviewRequest(commentAPIURL: firstComment)])
        _ = ledger.selectThreadsToAnnounce(from: [
            Fixtures.thread(
                id: "a",
                reason: .subscribed,
                updatedAt: secondUpdate,
                latestCommentAPIURL: firstComment,
            ),
        ])

        let announced = ledger.selectThreadsToAnnounce(from: [
            reviewRequest(updatedAt: thirdUpdate, commentAPIURL: firstComment),
        ])

        #expect(announced.map(\.update) == [.reasonForNotifying])
    }

    /// Once you have been mentioned you are a participant, so GitHub reasons the
    /// notifications after that as `subscribed`. Counting a fall-back as news
    /// would let every quietened thread back in through the mention door.
    @Test
    func doesNotLeadWithTheReasonWhenGitHubFallsBackToAQuieterOne() {
        let ledger = makeLedger()
        _ = ledger.selectThreadsToAnnounce(from: [
            Fixtures.thread(id: "a", reason: .mentioned, latestCommentAPIURL: firstComment),
        ])

        let announced = ledger.selectThreadsToAnnounce(from: [
            Fixtures.thread(
                id: "a",
                reason: .subscribed,
                updatedAt: secondUpdate,
                latestCommentAPIURL: secondComment,
            ),
        ])

        #expect(announced.map(\.update) == [.comment])
    }

    @Test
    func recordsTheLatestChangeAgainstEachThreadForThePanel() {
        let ledger = makeLedger()
        _ = ledger.selectThreadsToAnnounce(from: [reviewRequest(commentAPIURL: firstComment)])

        _ = ledger.selectThreadsToAnnounce(from: [
            reviewRequest(updatedAt: secondUpdate, commentAPIURL: secondComment),
        ])

        #expect(ledger.latestUpdates == ["a": .comment])
    }

    /// Most polls change nothing, and a row must not lose what it says every
    /// time the inbox is read back unchanged.
    @Test
    func keepsShowingTheLatestChangeWhileNothingMoves() {
        let ledger = makeLedger()
        _ = ledger.selectThreadsToAnnounce(from: [reviewRequest(commentAPIURL: firstComment)])
        let commented = reviewRequest(updatedAt: secondUpdate, commentAPIURL: secondComment)
        _ = ledger.selectThreadsToAnnounce(from: [commented])

        _ = ledger.selectThreadsToAnnounce(from: [commented])

        #expect(ledger.latestUpdates == ["a": .comment])
    }

    /// A ledger from a version that recorded only dates has to keep working, or
    /// the first run after updating re-seeds and swallows a poll's alerts.
    @Test
    func readsALedgerWrittenBeforeUpdatesWereRecorded() throws {
        let ledger = try makeLedgerCarriedOverFromDatesOnly()

        let announced = ledger.selectThreadsToAnnounce(from: [Fixtures.thread(id: "a", updatedAt: firstUpdate)])

        #expect(announced.isEmpty)
    }

    /// A carried-over thread has no recorded reason to compare against, so the
    /// first thing said about it is why it is in the inbox, the same as a thread
    /// being announced for the first time.
    @Test
    func leadsWithTheReasonForAThreadCarriedOverFromADatesOnlyLedger() throws {
        let ledger = try makeLedgerCarriedOverFromDatesOnly()

        let announced = ledger.selectThreadsToAnnounce(from: [Fixtures.thread(id: "a", updatedAt: secondUpdate)])

        #expect(announced.map(\.update) == [.reasonForNotifying])
    }

    @Test
    func survivesARestart() {
        let fileURL = temporaryFileURL()
        let firstRun = makeLedger(fileURL: fileURL)
        _ = firstRun.selectThreadsToAnnounce(from: [Fixtures.thread(id: "a", updatedAt: firstUpdate)])

        let secondRun = makeLedger(fileURL: fileURL)
        let announced = secondRun.selectThreadsToAnnounce(from: [Fixtures.thread(id: "a", updatedAt: firstUpdate)])

        #expect(announced.isEmpty)
    }

    /// Remembering threads past the inbox has to stop somewhere, or the file
    /// grows for as long as the app is installed.
    @Test
    func forgetsAThreadThatHasNotBeenInTheInboxForAMonth() throws {
        let fileURL = temporaryFileURL()
        let staleSeenAt = iso8601(Date().addingTimeInterval(-31 * 24 * 60 * 60))
        let stored = "{\"hasBeenSeeded\":true,\"lastAnnouncedUpdates\":{\"a\":{"
            + "\"updatedAt\":\"2023-11-14T22:13:20Z\",\"reason\":\"review_requested\","
            + "\"update\":\"comment\",\"lastSeenAt\":\"\(staleSeenAt)\"}}}"

        try stored.write(to: fileURL, atomically: true, encoding: .utf8)

        let ledger = makeLedger(fileURL: fileURL)

        // Any fetch prunes, so a thread returning after that is news again.
        _ = ledger.selectThreadsToAnnounce(from: [])

        let announced = ledger.selectThreadsToAnnounce(from: [
            reviewRequest(updatedAt: secondUpdate, commentAPIURL: secondComment),
        ])

        #expect(announced.map(\.update) == [.reasonForNotifying])
    }

    @Test
    func startsFreshAfterBeingCleared() {
        let fileURL = temporaryFileURL()
        let ledger = makeLedger(fileURL: fileURL)
        _ = ledger.selectThreadsToAnnounce(from: [Fixtures.thread(id: "a")])

        ledger.clear()

        #expect(ledger.selectThreadsToAnnounce(from: [Fixtures.thread(id: "a")]).isEmpty)
        #expect(ledger.selectThreadsToAnnounce(from: [Fixtures.thread(id: "b")]).map(\.id) == ["b"])
    }

    /// The thread the complaint is about: one pull request whose reason never
    /// moves, however much happens on it.
    private func reviewRequest(updatedAt: Date? = nil, commentAPIURL: String) -> NotificationThread {
        Fixtures.thread(
            id: "a",
            reason: .reviewRequested,
            updatedAt: updatedAt ?? firstUpdate,
            latestCommentAPIURL: commentAPIURL,
        )
    }

    /// A seeded ledger written by a version that held a bare date per thread,
    /// with thread "a" last announced at ``firstUpdate``.
    private func makeLedgerCarriedOverFromDatesOnly() throws -> SeenThreadLedger {
        let fileURL = temporaryFileURL()

        try #"{"hasBeenSeeded":true,"lastAnnouncedUpdates":{"a":"2023-11-14T22:13:20Z"}}"#
            .write(to: fileURL, atomically: true, encoding: .utf8)

        return makeLedger(fileURL: fileURL)
    }

    private func makeLedger(fileURL: URL? = nil) -> SeenThreadLedger {
        SeenThreadLedger(fileURL: fileURL ?? temporaryFileURL(), log: AppLog(subsystem: "tests"))
    }

    private func iso8601(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "ledger-\(UUID().uuidString).json")
    }
}
