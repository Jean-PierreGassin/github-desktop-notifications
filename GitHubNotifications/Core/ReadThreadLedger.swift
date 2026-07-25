import Foundation

/// Keeps the threads the user has read but wants to keep looking at.
///
/// GitHub's inbox endpoint answers with unread threads only, so a thread marked
/// read vanishes from the very next fetch. Under the Read click behaviour the
/// row is supposed to stay with its dot cleared, which it can only do from a
/// local copy. This is that copy, on disk so it survives a restart.
@MainActor
final class ReadThreadLedger {
    private struct Entry: Codable {
        let thread: NotificationThread
        let readAt: Date
    }

    private let fileURL: URL
    private let log: AppLog

    private var entries: [String: Entry] = [:]

    init(fileURL: URL? = nil, log: AppLog) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.log = log

        load()
    }

    var threads: [NotificationThread] {
        entries.values.map(\.thread)
    }

    var identifiers: Set<String> {
        Set(entries.keys)
    }

    func contains(_ identifier: String) -> Bool {
        entries[identifier] != nil
    }

    func record(_ thread: NotificationThread) {
        entries[thread.id] = Entry(thread: thread.markedRead(), readAt: Date())
        save()
    }

    func forget(_ identifier: String) {
        guard entries.removeValue(forKey: identifier) != nil else {
            return
        }

        save()
    }

    /// Drops everything GitHub's own inbox no longer holds, so a thread dealt
    /// with on another device stops being shown here.
    func keepOnly(_ identifiers: Set<String>) {
        let survivors = entries.filter { identifiers.contains($0.key) }

        guard survivors.count != entries.count else {
            return
        }

        entries = survivors
        save()
    }

    func clear() {
        entries = [:]
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let stored = try? decoder.decode([String: Entry].self, from: data) else {
            log.warning("Couldn't read the read-notifications file; starting fresh.")
            return
        }

        entries = stored
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
            )
            try encoder.encode(entries).write(to: fileURL, options: .atomic)
        } catch {
            log.warning("Couldn't save the read-notifications file: \(error.localizedDescription)")
        }
    }

    private static func defaultFileURL() -> URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "GitHubNotifications"

        return applicationSupport
            .appending(path: bundleIdentifier)
            .appending(path: "read-threads.json")
    }
}
