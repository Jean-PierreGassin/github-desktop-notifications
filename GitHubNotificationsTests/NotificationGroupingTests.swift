import Foundation
import Testing

@testable import GitHubNotifications

struct NotificationGroupingTests {
    private let olderUpdate = Date(timeIntervalSince1970: 1_700_000_000)
    private let newerUpdate = Date(timeIntervalSince1970: 1_700_009_999)

    @Test
    func ordersThreadsByPriorityBeforeRecency() {
        let threads = [
            Fixtures.thread(id: "recent-but-low", reason: .subscribed, updatedAt: newerUpdate),
            Fixtures.thread(id: "older-but-urgent", reason: .reviewRequested, updatedAt: olderUpdate),
        ]

        let groups = NotificationGrouping.makeGroups(from: threads, rowsPerRepository: 5)

        #expect(groups[0].visibleThreads.map(\.id) == ["older-but-urgent", "recent-but-low"])
    }

    @Test
    func ordersThreadsOfEqualPriorityByRecency() {
        let threads = [
            Fixtures.thread(id: "older", reason: .comment, updatedAt: olderUpdate),
            Fixtures.thread(id: "newer", reason: .comment, updatedAt: newerUpdate),
        ]

        let groups = NotificationGrouping.makeGroups(from: threads, rowsPerRepository: 5)

        #expect(groups[0].visibleThreads.map(\.id) == ["newer", "older"])
    }

    @Test
    func ordersRepositoriesByTheirMostUrgentThread() {
        let busyRepository = Fixtures.repository(id: 1, fullName: "acme/web")
        let urgentRepository = Fixtures.repository(id: 2, fullName: "acme/api")

        let threads = [
            Fixtures.thread(id: "chatter", reason: .comment, updatedAt: newerUpdate, repository: busyRepository),
            Fixtures.thread(id: "review", reason: .reviewRequested, updatedAt: olderUpdate, repository: urgentRepository),
        ]

        let groups = NotificationGrouping.makeGroups(from: threads, rowsPerRepository: 5)

        #expect(groups.map(\.repository.fullName) == ["acme/api", "acme/web"])
    }

    @Test
    func capsRowsPerRepositoryAndReportsTheRemainder() {
        let threads = (1 ... 7).map { index in
            Fixtures.thread(id: "\(index)", updatedAt: olderUpdate.addingTimeInterval(Double(index)))
        }

        let groups = NotificationGrouping.makeGroups(from: threads, rowsPerRepository: 3)

        #expect(groups[0].visibleThreads.count == 3)
        #expect(groups[0].hiddenThreadCount == 4)
        #expect(groups[0].threadCount == 7)
    }

    @Test
    func keepsTheMostImportantThreadsWhenTruncating() {
        let threads = [
            Fixtures.thread(id: "noise-1", reason: .ciActivity, updatedAt: newerUpdate),
            Fixtures.thread(id: "noise-2", reason: .ciActivity, updatedAt: newerUpdate),
            Fixtures.thread(id: "mention", reason: .mentioned, updatedAt: olderUpdate),
        ]

        let groups = NotificationGrouping.makeGroups(from: threads, rowsPerRepository: 1)

        #expect(groups[0].visibleThreads.map(\.id) == ["mention"])
        #expect(groups[0].hiddenThreadCount == 2)
    }

    @Test
    func treatsARowLimitBelowOneAsOne() {
        let threads = [Fixtures.thread(id: "only")]

        let groups = NotificationGrouping.makeGroups(from: threads, rowsPerRepository: 0)

        #expect(groups[0].visibleThreads.count == 1)
    }

    @Test
    func producesNoGroupsForAnEmptyInbox() {
        #expect(NotificationGrouping.makeGroups(from: [], rowsPerRepository: 5).isEmpty)
    }
}
