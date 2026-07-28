import Foundation

/// Keeps alerts that arrived outside the user's hours until it is time to
/// deliver them. Held alerts survive a restart, because the point of holding
/// them is that the user is not at the machine.
@MainActor
@Observable
final class HeldAlertQueue {
    private let fileURL: URL
    private let log: AppLog

    private(set) var heldAnnouncements: [ThreadAnnouncement] = []

    init(fileURL: URL? = nil, log: AppLog) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.log = log

        load()
    }

    var isEmpty: Bool {
        heldAnnouncements.isEmpty
    }

    func hold(_ announcements: [ThreadAnnouncement]) {
        guard !announcements.isEmpty else {
            return
        }

        let alreadyHeld = Set(heldAnnouncements.map(\.id))
        heldAnnouncements.append(contentsOf: announcements.filter { !alreadyHeld.contains($0.id) })

        save()
    }

    func drain() -> [ThreadAnnouncement] {
        let released = heldAnnouncements

        heldAnnouncements = []
        save()

        return released
    }

    func clear() {
        heldAnnouncements = []
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let stored = try? decoder.decode([ThreadAnnouncement].self, from: data) {
            heldAnnouncements = stored
            return
        }

        // A file written before held alerts carried what had changed holds bare
        // threads. They are released saying why the thread is in the inbox,
        // which is what they would have said on the night they were held.
        guard let threads = try? decoder.decode([NotificationThread].self, from: data) else {
            log.warning("Couldn't read held notifications; starting with none.")
            return
        }

        heldAnnouncements = threads.map { ThreadAnnouncement(thread: $0, update: .reasonForNotifying) }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
            )
            try encoder.encode(heldAnnouncements).write(to: fileURL, options: .atomic)
        } catch {
            log.warning("Couldn't save held notifications: \(error.localizedDescription)")
        }
    }

    private static func defaultFileURL() -> URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "GitHubNotifications"

        return applicationSupport
            .appending(path: bundleIdentifier)
            .appending(path: "held-alerts.json")
    }
}
