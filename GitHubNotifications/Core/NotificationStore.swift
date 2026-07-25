import Foundation

/// Holds the inbox as the panel needs to see it.
///
/// What GitHub returns is only part of that picture: its inbox endpoint answers
/// with unread threads only, so threads read from here are kept in a ledger and
/// merged back in until they fall out of view or leave GitHub's inbox.
@MainActor
@Observable
final class NotificationStore {
    private let readLedger: ReadThreadLedger

    private(set) var threads: [NotificationThread] = []
    private(set) var groups: [RepositoryGroup] = []

    var rowsPerRepository: Int {
        didSet { regroup() }
    }

    init(rowsPerRepository: Int = 5, readLedger: ReadThreadLedger) {
        self.rowsPerRepository = rowsPerRepository
        self.readLedger = readLedger
    }

    var unreadCount: Int {
        threads.count { $0.isUnread }
    }

    var hasNotifications: Bool {
        !threads.isEmpty
    }

    func replaceAll(with fetchedThreads: [NotificationThread]) {
        let fetchedIdentifiers = Set(fetchedThreads.map(\.id))
        let readElsewhere = readLedger.threads.filter { !fetchedIdentifiers.contains($0.id) }

        threads = fetchedThreads.map { thread in
            readLedger.contains(thread.id) ? thread.markedRead() : thread
        } + readElsewhere

        regroup()
    }

    /// Clears the dot without losing the row, and remembers it so the next fetch
    /// does not drop it.
    func markRead(_ identifier: String) {
        guard let index = threads.firstIndex(where: { $0.id == identifier }) else {
            return
        }

        let readThread = threads[index].markedRead()

        threads[index] = readThread
        readLedger.record(readThread)
        regroup()
    }

    /// Puts the dot back after GitHub refuses the change.
    func unmarkRead(_ identifier: String) {
        readLedger.forget(identifier)

        guard let index = threads.firstIndex(where: { $0.id == identifier }) else {
            return
        }

        threads[index] = threads[index].markedUnread()
        regroup()
    }

    @discardableResult
    func removeThread(withIdentifier identifier: String) -> Int? {
        guard let index = threads.firstIndex(where: { $0.id == identifier }) else {
            return nil
        }

        threads.remove(at: index)
        readLedger.forget(identifier)
        regroup()

        return index
    }

    /// Returns a removed row to where it was rather than to the end, so a failed
    /// call leaves the panel exactly as it found it.
    func restore(_ thread: NotificationThread, at index: Int) {
        threads.insert(thread, at: min(max(index, 0), threads.count))

        if !thread.isUnread {
            readLedger.record(thread)
        }

        regroup()
    }

    /// The reconciliation fetch reads the whole inbox, read threads included, so
    /// anything the ledger holds that it does not return has been dealt with
    /// somewhere else and is dropped.
    func reconcile(withInboxIdentifiers identifiers: Set<String>) {
        readLedger.keepOnly(identifiers)

        let stranded = threads.filter { !$0.isUnread && !readLedger.contains($0.id) }

        guard !stranded.isEmpty else {
            return
        }

        threads.removeAll { thread in stranded.contains { $0.id == thread.id } }
        regroup()
    }

    func removeAll() {
        threads = []
        groups = []
        readLedger.clear()
    }

    /// A read row that no longer fits its repository's limit is forgotten rather
    /// than kept out of sight, so the ledger cannot grow without bound even if
    /// reconciliation never runs.
    private func regroup() {
        groups = makeGroups()

        let visibleIdentifiers = Set(groups.flatMap { $0.visibleThreads.map(\.id) })
        let strandedIdentifiers = readLedger.identifiers.subtracting(visibleIdentifiers)

        guard !strandedIdentifiers.isEmpty else {
            return
        }

        strandedIdentifiers.forEach(readLedger.forget)
        threads.removeAll { strandedIdentifiers.contains($0.id) }
        groups = makeGroups()
    }

    private func makeGroups() -> [RepositoryGroup] {
        NotificationGrouping.makeGroups(from: threads, rowsPerRepository: rowsPerRepository)
    }
}
