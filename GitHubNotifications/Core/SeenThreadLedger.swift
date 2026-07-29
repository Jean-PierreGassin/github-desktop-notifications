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

        /// When the thread was last in the inbox, so entries for threads that
        /// have left it can be aged out rather than kept for ever.
        let lastSeenAt: Date

        enum CodingKeys: String, CodingKey {
            case updatedAt
            case reason
            case latestCommentAPIURL
            case update
            case lastSeenAt
        }

        init(_ announcement: ThreadAnnouncement, seenAt: Date) {
            updatedAt = announcement.thread.updatedAt
            reason = announcement.thread.reason
            latestCommentAPIURL = announcement.thread.subject.latestCommentAPIURL
            update = announcement.update
            lastSeenAt = seenAt
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
                lastSeenAt = updatedAt
                return
            }

            let container = try decoder.container(keyedBy: CodingKeys.self)

            updatedAt = try container.decode(Date.self, forKey: .updatedAt)
            reason = try container.decodeIfPresent(NotificationReason.self, forKey: .reason)
            latestCommentAPIURL = try container.decodeIfPresent(URL.self, forKey: .latestCommentAPIURL)
            update = try container.decodeIfPresent(ThreadUpdate.self, forKey: .update)
            lastSeenAt = try container.decodeIfPresent(Date.self, forKey: .lastSeenAt) ?? updatedAt
        }
    }

    private struct StoredLedger: Codable {
        var hasBeenSeeded: Bool
        var lastAnnouncedUpdates: [String: AnnouncedState]
    }

    /// How long a thread is remembered after it leaves the inbox, and how many
    /// are remembered at once. Both exist only to bound the file: a thread is
    /// normally forgotten because it went quiet, not because either was hit.
    private static let retentionPeriod: TimeInterval = 30 * 24 * 60 * 60
    private static let retentionLimit = 2000

    private let fileURL: URL
    private let log: AppLog

    private var lastAnnouncedUpdates: [String: AnnouncedState] = [:]
    private var hasBeenSeeded = false

    init(fileURL: URL? = nil, log: AppLog) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.log = log

        load()
    }

    /// What last changed about each thread, keyed by thread, for the panel to
    /// show beside the reason. A thread carried over from a ledger written before
    /// changes were recorded has nothing to show yet.
    ///
    /// Threads that have left the inbox are in here too. The panel looks rows up
    /// by identifier, so entries it has no row for cost nothing.
    var latestUpdates: [String: ThreadUpdate] {
        lastAnnouncedUpdates.compactMapValues(\.update)
    }

    /// Returns the threads worth announcing, each paired with what has changed
    /// about it, and records every thread in the inbox as announced.
    ///
    /// The first run after signing in announces nothing: the whole inbox is
    /// already known to the user.
    ///
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

    /// Drops what is remembered about a thread the user has dismissed.
    ///
    /// Reading a notification and dismissing it are different statements. Read
    /// means seen, so the thread is remembered and whatever happens next is
    /// reported as what it is. Dismissed means done with, exactly as it does on
    /// GitHub, so if the thread ever comes back it comes back as news.
    func forget(_ identifier: String) {
        guard lastAnnouncedUpdates.removeValue(forKey: identifier) != nil else {
            return
        }

        save()
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

    /// Threads that have left the inbox are kept, and aged out rather than
    /// dropped on sight.
    ///
    /// The inbox endpoint returns unread threads only, so reading a notification
    /// takes it out of every fetch that follows. Forgetting it there and then
    /// meant that anything happening on it afterwards - a comment, another
    /// reviewer's approval - brought it back looking like a thread the app had
    /// never seen, and announced it as the reason all over again. Reading a
    /// notification is the most ordinary thing there is, and it was quietly
    /// undoing every follow-up rule the user had set.
    private func record(_ announcements: [ThreadAnnouncement]) {
        let now = Date()

        for announcement in announcements {
            lastAnnouncedUpdates[announcement.id] = AnnouncedState(announcement, seenAt: now)
        }

        forgetThreadsGoneQuiet(asOf: now)
        save()
    }

    /// Keeping threads past the inbox has to stop somewhere. A thread not seen
    /// for a month is one the user dealt with long ago, and anything that
    /// happens on it after that is worth hearing about as though it were new.
    private func forgetThreadsGoneQuiet(asOf now: Date) {
        lastAnnouncedUpdates = lastAnnouncedUpdates.filter { _, state in
            now.timeIntervalSince(state.lastSeenAt) < Self.retentionPeriod
        }

        guard lastAnnouncedUpdates.count > Self.retentionLimit else {
            return
        }

        let survivors = lastAnnouncedUpdates
            .sorted { $0.value.lastSeenAt > $1.value.lastSeenAt }
            .prefix(Self.retentionLimit)

        lastAnnouncedUpdates = Dictionary(uniqueKeysWithValues: survivors.map { ($0.key, $0.value) })
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
