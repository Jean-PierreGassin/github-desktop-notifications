import Foundation

struct RepositoryGroup: Identifiable, Sendable, Equatable {
    let repository: NotificationRepository
    let visibleThreads: [NotificationThread]
    let hiddenThreadCount: Int

    var id: Int { repository.id }

    var threadCount: Int { visibleThreads.count + hiddenThreadCount }
}

/// Pure grouping and ordering rules for the panel.
///
/// Repositories are ordered by the most urgent thing inside them, then by how
/// recently they changed. Threads inside a repository follow the same rule, and
/// anything past the row limit is reported as a hidden count rather than
/// stretching the panel.
enum NotificationGrouping {
    static func makeGroups(from threads: [NotificationThread], rowsPerRepository: Int) -> [RepositoryGroup] {
        let threadsByRepository = Dictionary(grouping: threads) { $0.repository.id }

        let groups = threadsByRepository.values.compactMap { repositoryThreads -> RepositoryGroup? in
            guard let repository = repositoryThreads.first?.repository else {
                return nil
            }

            let orderedThreads = sortByReadStateThenPriority(repositoryThreads)
            let visibleThreads = Array(orderedThreads.prefix(max(rowsPerRepository, 1)))

            return RepositoryGroup(
                repository: repository,
                visibleThreads: visibleThreads,
                hiddenThreadCount: orderedThreads.count - visibleThreads.count,
            )
        }

        return sortByMostUrgentThread(groups)
    }

    /// Read rows sink below unread ones within their repository, then the usual
    /// priority-then-recency order applies inside each band. Something already
    /// dealt with should never sit above something that still needs the user.
    static func sortByReadStateThenPriority(_ threads: [NotificationThread]) -> [NotificationThread] {
        threads.sorted { leading, trailing in
            guard leading.isUnread == trailing.isUnread else {
                return leading.isUnread
            }

            return isAheadByPriorityThenRecency(leading, trailing)
        }
    }

    /// The order alerts are posted in, so the most urgent thing a poll turned up
    /// is the one that lands first.
    static func sortByPriorityThenRecency(_ announcements: [ThreadAnnouncement]) -> [ThreadAnnouncement] {
        announcements.sorted { isAheadByPriorityThenRecency($0.thread, $1.thread) }
    }

    private static func isAheadByPriorityThenRecency(
        _ leading: NotificationThread,
        _ trailing: NotificationThread,
    ) -> Bool {
        guard leading.reason.priorityRank == trailing.reason.priorityRank else {
            return leading.reason.priorityRank < trailing.reason.priorityRank
        }

        return leading.updatedAt > trailing.updatedAt
    }

    private static func sortByMostUrgentThread(_ groups: [RepositoryGroup]) -> [RepositoryGroup] {
        groups.sorted { leading, trailing in
            let leadingRank = highestPriorityRank(in: leading)
            let trailingRank = highestPriorityRank(in: trailing)

            guard leadingRank == trailingRank else {
                return leadingRank < trailingRank
            }

            return mostRecentUpdate(in: leading) > mostRecentUpdate(in: trailing)
        }
    }

    private static func highestPriorityRank(in group: RepositoryGroup) -> Int {
        group.visibleThreads.map(\.reason.priorityRank).min() ?? Int.max
    }

    private static func mostRecentUpdate(in group: RepositoryGroup) -> Date {
        group.visibleThreads.map(\.updatedAt).max() ?? .distantPast
    }
}
