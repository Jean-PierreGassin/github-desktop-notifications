import Foundation

/// Holds the inbox as the panel needs to see it.
///
/// What GitHub returns is only part of that picture: its inbox endpoint answers
/// with unread threads only, so threads read from here are kept in a ledger and
/// merged back in until they fall out of view or leave GitHub's inbox.
///
/// It is also more than the panel needs to see. GitHub decides what lands in an
/// inbox; the user decides which of it concerns them. The whole fetch is kept,
/// because the answer to that second question changes without the inbox
/// changing, and only the part that passes it is published.
@MainActor
@Observable
final class NotificationStore {
    private let readLedger: ReadThreadLedger

    /// Everything the last fetch turned up, whether or not the user wants to see
    /// it. Nothing outside this file reads it: it exists so switching a type back
    /// on can bring its threads back without waiting for the inbox to change.
    private var fetchedThreads: [NotificationThread] = []

    private(set) var threads: [NotificationThread] = []
    private(set) var groups: [RepositoryGroup] = []

    /// The notification types the user asked for. Threads of any other type are
    /// held but never shown, so they raise no row, no count and no bulk action.
    var shownReasons: Set<NotificationReason> = Set(NotificationReason.allCases) {
        didSet { regroup() }
    }

    /// What last changed about each thread, shown on its row beside the reason.
    /// It is handed over by the session rather than worked out here, because the
    /// only thing that knows what a thread looked like before this fetch is the
    /// ledger of what has already been announced.
    private(set) var latestUpdates: [String: ThreadUpdate] = [:]

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

    func replaceAll(with newThreads: [NotificationThread]) {
        let fetchedIdentifiers = Set(newThreads.map(\.id))
        let readElsewhere = readLedger.threads.filter { !fetchedIdentifiers.contains($0.id) }

        fetchedThreads = newThreads.map { thread in
            readLedger.contains(thread.id) ? thread.markedRead() : thread
        } + readElsewhere

        regroup()
    }

    func showLatestUpdates(_ updates: [String: ThreadUpdate]) {
        latestUpdates = updates
    }

    /// Clears the dot without losing the row, and remembers it so the next fetch
    /// does not drop it.
    func markRead(_ identifier: String) {
        guard let index = fetchedThreads.firstIndex(where: { $0.id == identifier }) else {
            return
        }

        let readThread = fetchedThreads[index].markedRead()

        fetchedThreads[index] = readThread
        readLedger.record(readThread)
        regroup()
    }

    /// Puts the dot back after GitHub refuses the change.
    func unmarkRead(_ identifier: String) {
        readLedger.forget(identifier)

        guard let index = fetchedThreads.firstIndex(where: { $0.id == identifier }) else {
            return
        }

        fetchedThreads[index] = fetchedThreads[index].markedUnread()
        regroup()
    }

    /// The index returned is into the whole fetch rather than into the visible
    /// rows, because that is what ``restore(_:at:)`` puts the thread back with.
    /// Filtering keeps the order it was given, so restoring a thread where it was
    /// among the fetched threads restores the row where it was on screen.
    @discardableResult
    func removeThread(withIdentifier identifier: String) -> Int? {
        guard let index = fetchedThreads.firstIndex(where: { $0.id == identifier }) else {
            return nil
        }

        fetchedThreads.remove(at: index)
        readLedger.forget(identifier)
        regroup()

        return index
    }

    /// Returns a removed row to where it was rather than to the end, so a failed
    /// call leaves the panel exactly as it found it.
    func restore(_ thread: NotificationThread, at index: Int) {
        fetchedThreads.insert(thread, at: min(max(index, 0), fetchedThreads.count))

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

        let strandedIdentifiers = Set(
            fetchedThreads.filter { !$0.isUnread && !readLedger.contains($0.id) }.map(\.id),
        )

        guard !strandedIdentifiers.isEmpty else {
            return
        }

        fetchedThreads.removeAll { strandedIdentifiers.contains($0.id) }
        regroup()
    }

    func removeAll() {
        fetchedThreads = []
        threads = []
        groups = []
        latestUpdates = [:]
        readLedger.clear()
    }

    private func regroup() {
        threads = fetchedThreads.filter { shownReasons.contains($0.reason) }
        groups = makeGroups()

        evictOverflowingReadThreads()
    }

    /// A read row that no longer fits its repository's limit is forgotten rather
    /// than kept out of sight, so the ledger cannot grow without bound even if
    /// reconciliation never runs.
    ///
    /// A thread held back only by the type filter is not overflow. It is counted
    /// as kept, so switching its type on again brings the row back rather than
    /// finding it has been quietly thrown away.
    private func evictOverflowingReadThreads() {
        let keptIdentifiers = Set(groups.flatMap { $0.visibleThreads.map(\.id) })
            .union(fetchedThreads.filter { !shownReasons.contains($0.reason) }.map(\.id))
        let strandedIdentifiers = readLedger.identifiers.subtracting(keptIdentifiers)

        guard !strandedIdentifiers.isEmpty else {
            return
        }

        strandedIdentifiers.forEach(readLedger.forget)
        fetchedThreads.removeAll { strandedIdentifiers.contains($0.id) }
        threads = fetchedThreads.filter { shownReasons.contains($0.reason) }
        groups = makeGroups()
    }

    private func makeGroups() -> [RepositoryGroup] {
        NotificationGrouping.makeGroups(from: threads, rowsPerRepository: rowsPerRepository)
    }
}
