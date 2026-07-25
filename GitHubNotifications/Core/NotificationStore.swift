import Foundation

/// Holds the inbox as the panel needs to see it.
@MainActor
@Observable
final class NotificationStore {
    /// The panel never scrolls, so the number of repositories on show is
    /// bounded too. The rest are summarised with a link to the inbox.
    private static let mostRepositoriesShown = 8

    private(set) var threads: [NotificationThread] = []
    private(set) var groups: [RepositoryGroup] = []

    var rowsPerRepository: Int {
        didSet { regroup() }
    }

    init(rowsPerRepository: Int = 5) {
        self.rowsPerRepository = rowsPerRepository
    }

    var visibleGroups: [RepositoryGroup] {
        Array(groups.prefix(Self.mostRepositoriesShown))
    }

    var hiddenRepositoryCount: Int {
        max(groups.count - Self.mostRepositoriesShown, 0)
    }

    var unreadCount: Int {
        threads.count { $0.isUnread }
    }

    var hasNotifications: Bool {
        !threads.isEmpty
    }

    func replaceAll(with fetchedThreads: [NotificationThread]) {
        threads = fetchedThreads
        regroup()
    }

    func removeThread(withIdentifier identifier: String) {
        threads.removeAll { $0.id == identifier }
        regroup()
    }

    func removeAll() {
        threads = []
        groups = []
    }

    private func regroup() {
        groups = NotificationGrouping.makeGroups(from: threads, rowsPerRepository: rowsPerRepository)
    }
}
