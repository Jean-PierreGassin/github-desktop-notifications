import Foundation

/// Holds the inbox as the panel needs to see it.
@MainActor
@Observable
final class NotificationStore {
    private(set) var threads: [NotificationThread] = []
    private(set) var groups: [RepositoryGroup] = []

    var rowsPerRepository: Int {
        didSet { regroup() }
    }

    init(rowsPerRepository: Int = 5) {
        self.rowsPerRepository = rowsPerRepository
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
