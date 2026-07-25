import Foundation
import Testing

@testable import GitHubNotifications

@MainActor
struct NotificationStoreTests {
    @Test
    func keepsAReadRowThatGitHubStopsReturning() {
        let store = Fixtures.store()
        store.replaceAll(with: [Fixtures.thread(id: "1"), Fixtures.thread(id: "2")])

        store.markRead("1")
        store.replaceAll(with: [Fixtures.thread(id: "2")])

        #expect(store.threads.map(\.id).sorted() == ["1", "2"])
        #expect(store.threads.first { $0.id == "1" }?.isUnread == false)
        #expect(store.unreadCount == 1)
    }

    @Test
    func sinksReadRowsBelowUnreadOnesInTheirRepository() {
        let store = Fixtures.store()
        store.replaceAll(with: [
            Fixtures.thread(id: "urgent", reason: .reviewRequested),
            Fixtures.thread(id: "quiet", reason: .subscribed),
        ])

        store.markRead("urgent")

        #expect(store.groups.first?.visibleThreads.map(\.id) == ["quiet", "urgent"])
    }

    @Test
    func forgetsAReadRowOnceItNoLongerFits() {
        let store = Fixtures.store(rowsPerRepository: 2)
        store.replaceAll(with: [
            Fixtures.thread(id: "1"),
            Fixtures.thread(id: "2"),
            Fixtures.thread(id: "3"),
        ])

        store.markRead("1")
        store.replaceAll(with: [
            Fixtures.thread(id: "2"),
            Fixtures.thread(id: "3"),
            Fixtures.thread(id: "4"),
        ])

        #expect(!store.threads.contains { $0.id == "1" })
    }

    @Test
    func dropsReadRowsTheInboxNoLongerHolds() {
        let store = Fixtures.store()
        store.replaceAll(with: [Fixtures.thread(id: "1"), Fixtures.thread(id: "2")])
        store.markRead("1")

        store.reconcile(withInboxIdentifiers: ["2"])

        #expect(store.threads.map(\.id) == ["2"])
    }

    @Test
    func keepsReadRowsTheInboxStillHolds() {
        let store = Fixtures.store()
        store.replaceAll(with: [Fixtures.thread(id: "1")])
        store.markRead("1")

        store.reconcile(withInboxIdentifiers: ["1"])

        #expect(store.threads.map(\.id) == ["1"])
    }

    @Test
    func putsTheDotBackWhenAReadIsReversed() {
        let store = Fixtures.store()
        store.replaceAll(with: [Fixtures.thread(id: "1")])
        store.markRead("1")

        store.unmarkRead("1")

        #expect(store.unreadCount == 1)
        #expect(store.threads.first?.isUnread == true)
    }

    @Test
    func returnsARemovedRowToItsOwnPosition() {
        let store = Fixtures.store()
        let threads = [Fixtures.thread(id: "1"), Fixtures.thread(id: "2"), Fixtures.thread(id: "3")]
        store.replaceAll(with: threads)

        let index = store.removeThread(withIdentifier: "2")
        store.restore(threads[1], at: index ?? 0)

        #expect(store.threads.map(\.id) == ["1", "2", "3"])
    }
}
