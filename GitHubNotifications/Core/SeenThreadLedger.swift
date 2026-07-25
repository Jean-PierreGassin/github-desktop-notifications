import Foundation

/// Remembers which threads have already been announced, so restarting the app
/// does not replay every notification and a first sign-in does not fire dozens
/// of alerts at once.
@MainActor
final class SeenThreadLedger {
    private struct StoredLedger: Codable {
        var hasBeenSeeded: Bool
        var lastAnnouncedUpdates: [String: Date]
    }

    private let fileURL: URL
    private let log: AppLog

    private var lastAnnouncedUpdates: [String: Date] = [:]
    private var hasBeenSeeded = false

    init(fileURL: URL? = nil, log: AppLog) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.log = log

        load()
    }

    /// Returns the threads worth announcing and records them as announced.
    ///
    /// The first run after signing in announces nothing: the whole inbox is
    /// already known to the user.
    func selectThreadsToAnnounce(from threads: [NotificationThread]) -> [NotificationThread] {
        defer { record(threads) }

        guard hasBeenSeeded else {
            hasBeenSeeded = true
            return []
        }

        return threads.filter(isWorthAnnouncing)
    }

    func clear() {
        lastAnnouncedUpdates = [:]
        hasBeenSeeded = false
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func isWorthAnnouncing(_ thread: NotificationThread) -> Bool {
        guard thread.isUnread else {
            return false
        }

        guard let lastAnnouncedUpdate = lastAnnouncedUpdates[thread.id] else {
            return true
        }

        return thread.updatedAt > lastAnnouncedUpdate
    }

    /// Only threads still in the inbox are kept, so the file cannot grow forever.
    private func record(_ threads: [NotificationThread]) {
        lastAnnouncedUpdates = Dictionary(
            threads.map { ($0.id, $0.updatedAt) },
            uniquingKeysWith: { first, _ in first },
        )

        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let stored = try? decoder.decode(StoredLedger.self, from: data) else {
            log.warning("Couldn't read the seen-notifications file; starting fresh.")
            return
        }

        hasBeenSeeded = stored.hasBeenSeeded
        lastAnnouncedUpdates = stored.lastAnnouncedUpdates
    }

    private func save() {
        let stored = StoredLedger(hasBeenSeeded: hasBeenSeeded, lastAnnouncedUpdates: lastAnnouncedUpdates)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
            )
            try encoder.encode(stored).write(to: fileURL, options: .atomic)
        } catch {
            log.warning("Couldn't save the seen-notifications file: \(error.localizedDescription)")
        }
    }

    private static func defaultFileURL() -> URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "GitHubNotifications"

        return applicationSupport
            .appending(path: bundleIdentifier)
            .appending(path: "seen-threads.json")
    }
}
