#if DEBUG
import Foundation
import Testing

@testable import GitHubNotifications

@MainActor
struct DebugInboxTests {
    @Test
    func startsWithVariedRowsForTestingActions() {
        let inbox = DebugInbox(now: Date(timeIntervalSince1970: 1_700_000_000))

        #expect(inbox.threads.count == 3)
        #expect(inbox.threads.contains { !$0.isUnread })
        #expect(Set(inbox.threads.map(\.repository.id)).count == 2)
        #expect(Set(inbox.threads.map(\.reason)).count == 3)
    }

    @Test
    func sampleActionsStayLocalAndPersistAcrossFetchMerges() {
        let inbox = DebugInbox()
        let threadToRead = inbox.threads[0]
        let threadToDismiss = inbox.threads[1]

        inbox.apply(.read, to: threadToRead)
        inbox.apply(.dismissed, to: threadToDismiss)

        let mergedThreads = inbox.merge(with: [Fixtures.thread(id: "real")])

        #expect(mergedThreads.first?.id == "real")
        #expect(mergedThreads.first { $0.id == threadToRead.id }?.isUnread == false)
        #expect(!mergedThreads.contains { $0.id == threadToDismiss.id })
    }
}
#endif
