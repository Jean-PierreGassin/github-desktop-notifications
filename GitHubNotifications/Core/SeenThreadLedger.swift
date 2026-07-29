import Foundation

/// Remembers which threads have already been announced, so restarting the app
/// does not replay every notification and a first sign-in does not fire dozens
/// of alerts at once.
@MainActor
final class SeenThreadLedger {
    /// What was known about a thread when it was last announced, so the next
    /// alert can say what has changed rather than repeat why the thread is here.
    private struct AnnouncedState: Codable {
        let updatedAt: Date
        let reason: NotificationReason?
        let latestCommentAPIURL: URL?
        let update: ThreadUpdate?

        enum CodingKeys: String, CodingKey {
            case updatedAt
            case reason
            case latestCommentAPIURL
            case update
        }

        init(_ announcement: ThreadAnnouncement) {
            updatedAt = announcement.thread.updatedAt
            reason = announcement.thread.reason
            latestCommentAPIURL = announcement.thread.subject.latestCommentAPIURL
            update = announcement.update
        }

        /// A ledger written before alerts said what had changed holds a bare
        /// date per thread. One is read as a thread whose reason, comments and
        /// change were never recorded, rather than failing the file and
        /// re-seeding, which would swallow a poll's worth of alerts on the first
        /// run after an update.
        init(from decoder: Decoder) throws {
            if let updatedAt = try? decoder.singleValueContainer().decode(Date.self) {
                self.updatedAt = updatedAt
                reason = nil
                latestCommentAPIURL = nil
                update = nil
                return
            }

            let container = try decoder.container(keyedBy: CodingKeys.self)

            updatedAt = try container.decode(Date.self, forKey: .updatedAt)
            reason = try container.decodeIfPresent(NotificationReason.self, forKey: .reason)
            latestCommentAPIURL = try container.decodeIfPresent(URL.self, forKey: .latestCommentAPIURL)
            update = try container.decodeIfPresent(ThreadUpdate.self, forKey: .update)
        }
    }

    private struct StoredLedger: Codable {
        var hasBeenSeeded: Bool
        var lastAnnouncedUpdates: [String: AnnouncedState]
    }

    private let fileURL: URL
    private let log: AppLog

    private var lastAnnouncedUpdates: [String: AnnouncedState] = [:]
    private var hasBeenSeeded = false

    init(fileURL: URL? = nil, log: AppLog) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.log = log

        load()
    }

    /// What last changed about each thread still in the inbox, keyed by thread,
    /// for the panel to show beside the reason. A thread carried over from a
    /// ledger written before changes were recorded has nothing to show yet.
    var latestUpdates: [String: ThreadUpdate] {
        lastAnnouncedUpdates.compactMapValues(\.update)
    }

    /// Returns the threads worth announcing, each paired with what has changed
    /// about it, and records every thread in the inbox as announced.
    ///
    /// The first run after signing in announces nothing: the whole inbox is
    /// already known to the user.
    func selectThreadsToAnnounce(from threads: [NotificationThread]) -> [ThreadAnnouncement] {
        let announcements = threads.map { ThreadAnnouncement(thread: $0, update: update(for: $0)) }

        defer { record(announcements) }

        guard hasBeenSeeded else {
            hasBeenSeeded = true
            return []
        }

        return announcements.filter { isWorthAnnouncing($0.thread) }
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

        return thread.updatedAt > lastAnnouncedUpdate.updatedAt
    }

    /// Comparing against the last announcement is the only way to tell a comment
    /// that has just arrived from one that was already there: GitHub gives the
    /// newest comment's URL whether or not a comment is what caused the update.
    ///
    /// A thread nothing has been said about yet, and one GitHub has re-reasoned
    /// because it now concerns the user more directly, both lead with the reason.
    private func update(for thread: NotificationThread) -> ThreadUpdate {
        guard let lastAnnouncedUpdate = lastAnnouncedUpdates[thread.id] else {
            return .reasonForNotifying
        }

        // Most polls change nothing, and a row must not lose what it says every
        // time the inbox is read back unchanged.
        guard thread.updatedAt > lastAnnouncedUpdate.updatedAt else {
            return lastAnnouncedUpdate.update ?? .reasonForNotifying
        }

        if isNews(thread.reason, replacing: lastAnnouncedUpdate.reason) {
            return .reasonForNotifying
        }

        guard let latestCommentAPIURL = thread.subject.latestCommentAPIURL,
              latestCommentAPIURL != lastAnnouncedUpdate.latestCommentAPIURL,
              let commentUpdate = ThreadUpdate(latestCommentAPIURL: latestCommentAPIURL)
        else {
            return .otherActivity
        }

        return commentUpdate
    }

    /// Whether GitHub changing why a thread concerns the user is itself the news.
    ///
    /// An escalation is: a repository you watch turns into a pull request you
    /// have been asked to review, a review request turns into a mention. A
    /// fall-back is not. Once someone has mentioned you on a thread you are a
    /// participant in it, so the notifications after that arrive as `subscribed`,
    /// and counting that as news would hand every thread the user has quietened
    /// a way back in through the one door left open for mentions.
    ///
    /// The fall-back is not swallowed, only demoted: it goes on to be read as
    /// whatever actually changed, and answers to the follow-up settings like any
    /// other activity.
    private func isNews(_ reason: NotificationReason, replacing previousReason: NotificationReason?) -> Bool {
        // A ledger written before reasons were recorded knows nothing of this
        // thread's history, so its reason has not been said yet.
        guard let previousReason else {
            return true
        }

        guard previousReason != reason else {
            return false
        }

        return reason.priorityRank <= previousReason.priorityRank
    }

    /// Only threads still in the inbox are kept, so the file cannot grow forever.
    private func record(_ announcements: [ThreadAnnouncement]) {
        lastAnnouncedUpdates = Dictionary(
            announcements.map { ($0.id, AnnouncedState($0)) },
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
