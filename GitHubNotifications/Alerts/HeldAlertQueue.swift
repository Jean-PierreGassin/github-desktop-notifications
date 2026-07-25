import Foundation

/// Keeps alerts that arrived outside the user's hours until it is time to
/// deliver them. Held alerts survive a restart, because the point of holding
/// them is that the user is not at the machine.
@MainActor
@Observable
final class HeldAlertQueue {
    private let fileURL: URL
    private let log: AppLog

    private(set) var heldThreads: [NotificationThread] = []

    init(fileURL: URL? = nil, log: AppLog) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.log = log

        load()
    }

    var isEmpty: Bool {
        heldThreads.isEmpty
    }

    func hold(_ threads: [NotificationThread]) {
        guard !threads.isEmpty else {
            return
        }

        let alreadyHeld = Set(heldThreads.map(\.id))
        heldThreads.append(contentsOf: threads.filter { !alreadyHeld.contains($0.id) })

        save()
    }

    func drain() -> [NotificationThread] {
        let released = heldThreads

        heldThreads = []
        save()

        return released
    }

    func clear() {
        heldThreads = []
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let stored = try? decoder.decode([NotificationThread].self, from: data) else {
            log.warning("Couldn't read held notifications; starting with none.")
            return
        }

        heldThreads = stored
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
            )
            try encoder.encode(heldThreads).write(to: fileURL, options: .atomic)
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

/// Persists the work hours settings.
@MainActor
@Observable
final class WorkHoursPreferences {
    private static let storageKey = "workHours"

    private let defaults: UserDefaults

    var hours: WorkHours {
        didSet { save() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        guard let stored = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode(WorkHours.self, from: stored)
        else {
            hours = WorkHours()
            return
        }

        hours = decoded
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(hours) else {
            return
        }

        defaults.set(encoded, forKey: Self.storageKey)
    }
}
