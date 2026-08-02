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

    @Test
    func showsNothingOfATypeTheUserHasNotAskedFor() {
        let store = Fixtures.store()
        store.shownReasons = [.reviewRequested]

        store.replaceAll(with: [
            Fixtures.thread(id: "wanted", reason: .reviewRequested),
            Fixtures.thread(id: "unwanted", reason: .assigned),
        ])

        #expect(store.threads.map(\.id) == ["wanted"])
        #expect(store.unreadCount == 1)
        #expect(store.groups.flatMap { $0.visibleThreads.map(\.id) } == ["wanted"])
    }

    /// The whole fetch is held rather than filtered away, so the answer changing
    /// does not have to wait for GitHub to have news.
    @Test
    func bringsHiddenRowsBackWhenTheirTypeIsAskedForAgain() {
        let store = Fixtures.store()
        store.shownReasons = [.reviewRequested]
        store.replaceAll(with: [
            Fixtures.thread(id: "1", reason: .reviewRequested),
            Fixtures.thread(id: "2", reason: .assigned),
        ])

        store.shownReasons = [.reviewRequested, .assigned]

        #expect(store.threads.map(\.id).sorted() == ["1", "2"])
    }

    /// The row limit evicts read rows that no longer fit, and a row hidden by the
    /// type filter must not be mistaken for one of them.
    @Test
    func doesNotThrowAwayAReadRowThatIsMerelyHidden() {
        let store = Fixtures.store()
        store.replaceAll(with: [
            Fixtures.thread(id: "1", reason: .reviewRequested),
            Fixtures.thread(id: "2", reason: .assigned),
        ])
        store.markRead("2")

        store.shownReasons = [.reviewRequested]
        store.shownReasons = [.reviewRequested, .assigned]

        #expect(store.threads.map(\.id).sorted() == ["1", "2"])
        #expect(store.threads.first { $0.id == "2" }?.isUnread == false)
    }

    @Test
    func showsNothingFromAnOwnerTheUserHasSwitchedOff() {
        let store = Fixtures.store()
        store.mutedOwners = ["acme"]

        store.replaceAll(with: [
            Fixtures.thread(id: "work", repository: Fixtures.repository(fullName: "acme/api")),
            Fixtures.thread(id: "personal", repository: Fixtures.repository(id: 2, fullName: "jp/dotfiles")),
        ])

        #expect(store.threads.map(\.id) == ["personal"])
        #expect(store.unreadCount == 1)
        #expect(store.groups.flatMap { $0.visibleThreads.map(\.id) } == ["personal"])
    }

    /// GitHub spells an owner however they registered, and the muted set is folded
    /// to lower case, so the two only meet if the store folds as well.
    @Test
    func matchesAMutedOwnerWhateverCaseGitHubUses() {
        let store = Fixtures.store()
        store.mutedOwners = ["acme"]

        store.replaceAll(with: [Fixtures.thread(id: "1", repository: Fixtures.repository(fullName: "ACME/api"))])

        #expect(store.threads.isEmpty)
    }

    @Test
    func bringsHiddenRowsBackWhenTheirOwnerIsSwitchedOnAgain() {
        let store = Fixtures.store()
        store.mutedOwners = ["acme"]
        store.replaceAll(with: [Fixtures.thread(id: "1", repository: Fixtures.repository(fullName: "acme/api"))])

        store.mutedOwners = []

        #expect(store.threads.map(\.id) == ["1"])
    }

    /// The row limit evicts read rows that no longer fit, and a row hidden by the
    /// owner filter must not be mistaken for one of them.
    @Test
    func doesNotThrowAwayAReadRowWhoseOwnerIsMerelyMuted() {
        let store = Fixtures.store()
        store.replaceAll(with: [Fixtures.thread(id: "1", repository: Fixtures.repository(fullName: "acme/api"))])
        store.markRead("1")

        store.mutedOwners = ["acme"]
        store.mutedOwners = []

        #expect(store.threads.map(\.id) == ["1"])
        #expect(store.threads.first?.isUnread == false)
    }

    /// The index a removal hands back is into the whole fetch, so a rollback
    /// still puts the row where it was even with rows hidden above it.
    @Test
    func returnsARemovedRowToItsOwnPositionWithHiddenRowsAroundIt() {
        let store = Fixtures.store()
        let threads = [
            Fixtures.thread(id: "hidden", reason: .ciActivity),
            Fixtures.thread(id: "1", reason: .reviewRequested),
            Fixtures.thread(id: "2", reason: .reviewRequested, updatedAt: Date(timeIntervalSince1970: 1)),
        ]
        store.shownReasons = [.reviewRequested]
        store.replaceAll(with: threads)

        let index = store.removeThread(withIdentifier: "1")
        store.restore(threads[1], at: index ?? 0)

        #expect(store.threads.map(\.id) == ["1", "2"])
    }
}
