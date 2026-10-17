import Foundation

/// Works out and keeps what last happened on each pull request or issue in the
/// inbox, read from its timeline.
///
/// Rows ask the way they ask ``SubjectStatusCache``: they get whatever is known
/// and a fetch runs behind them. An alert cannot wait for a row to be drawn, so
/// it asks with ``describe(_:)`` and waits for the answer before it is posted.
///
/// A timeline that cannot be read leaves the thread described the way it was
/// before, by its reason and what the inbox alone can tell.
@MainActor
@Observable
final class ThreadActivityCache {
    private let api: GitHubAPI
    private let auth: AuthService
    private let log: AppLog

    private var activities: [String: ThreadActivity] = [:]
    private var fetchedFor: [String: Date] = [:]
    private var inFlight: Set<String> = []
    private var generation = 0

    init(api: GitHubAPI, auth: AuthService, log: AppLog) {
        self.api = api
        self.auth = auth
        self.log = log
    }

    /// Whether every fetch started from a row has landed, for tests to wait on.
    var hasSettled: Bool {
        inFlight.isEmpty
    }

    /// The activity if it is already to hand, and a fetch started when the
    /// thread has moved since its timeline was last read.
    func activity(for thread: NotificationThread) -> ThreadActivity? {
        guard Self.timelineURL(for: thread) != nil, auth.activeToken != nil else {
            return nil
        }

        if fetchedFor[thread.id] != thread.updatedAt, !inFlight.contains(thread.id) {
            let identifier = thread.id

            inFlight.insert(identifier)

            Task { [weak self] in
                _ = await self?.describe(thread)
                self?.inFlight.remove(identifier)
            }
        }

        return activities[thread.id]
    }

    /// What happened on the thread to bring it back, reading the timeline only
    /// when the thread has moved since it was last read.
    func describe(_ thread: NotificationThread) async -> ThreadActivity? {
        guard fetchedFor[thread.id] != thread.updatedAt else {
            return activities[thread.id]
        }

        guard let timelineURL = Self.timelineURL(for: thread), let token = auth.activeToken else {
            return nil
        }

        let fetchGeneration = generation
        let viewerLogin = auth.signedInLogin
        let events = try? await api.fetchTimeline(at: timelineURL, usingToken: token)

        guard generation == fetchGeneration else {
            return nil
        }

        fetchedFor[thread.id] = thread.updatedAt

        guard let events else {
            activities[thread.id] = nil
            log.debug("Couldn't read the timeline of \(timelineURL.deletingLastPathComponent().lastPathComponent).")
            return nil
        }

        let activity = ThreadActivity.latest(in: events, for: thread, viewerLogin: viewerLogin)
        activities[thread.id] = activity

        return activity
    }

    /// Signing out must not leave the next account reading the last one's
    /// activity.
    func clear() {
        generation += 1
        activities = [:]
        fetchedFor = [:]
        inFlight = []
    }

    private static func timelineURL(for thread: NotificationThread) -> URL? {
        guard let subjectURL = thread.subject.apiURL else {
            return nil
        }

        return TimelineEvent.timelineURL(forSubjectAt: subjectURL)
    }
}
