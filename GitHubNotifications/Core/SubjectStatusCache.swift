import Foundation

/// Fetches and keeps where each notification's pull request or issue stands.
///
/// The inbox endpoint says nothing about this, so every status costs a request
/// against the subject itself. Asking for the whole inbox would spend hundreds
/// of them on rows nobody is looking at, so this works the way ``AvatarCache``
/// does: a row asks, gets whatever is already known, and a fetch runs behind it.
/// Only rows actually on screen ever cost anything.
///
/// A status is decoration in the same sense an avatar is. A slow fetch, a token
/// without access to a private repository, or a rate limit all end the same way,
/// with no badge on the row rather than an error in front of the user.
@MainActor
@Observable
final class SubjectStatusCache {
    /// Subjects with a state worth reading. GitHub gives no REST resource for
    /// the rest of them, and a release or a workflow run has no open-or-closed
    /// to report anyway.
    private static let fetchableTypes: Set<NotificationSubjectType> = [.pullRequest, .issue]

    private let api: GitHubAPI
    private let auth: AuthService
    private let log: AppLog

    private var statuses: [String: SubjectStatus] = [:]
    private var fetchedFor: [String: Date] = [:]
    private var inFlight: Set<String> = []

    init(api: GitHubAPI, auth: AuthService, log: AppLog) {
        self.api = api
        self.auth = auth
        self.log = log
    }

    /// The status if it is already to hand, and a fetch started when the thread
    /// has moved since it was last read.
    ///
    /// The last known status is returned while a refetch runs, so a badge does
    /// not blink out of the row every time the thread it belongs to updates.
    func status(for thread: NotificationThread) -> SubjectStatus? {
        guard let subjectURL = fetchableSubjectURL(for: thread) else {
            return nil
        }

        if fetchedFor[thread.id] != thread.updatedAt {
            fetch(thread, at: subjectURL)
        }

        return statuses[thread.id]
    }

    /// Signing out must not leave the next account looking at the last one's
    /// pull requests.
    func clear() {
        statuses = [:]
        fetchedFor = [:]
        inFlight = []
    }

    private func fetchableSubjectURL(for thread: NotificationThread) -> URL? {
        guard Self.fetchableTypes.contains(thread.subject.type) else {
            return nil
        }

        return thread.subject.apiURL
    }

    private func fetch(_ thread: NotificationThread, at subjectURL: URL) {
        guard let token = auth.activeToken, !inFlight.contains(thread.id) else {
            return
        }

        let identifier = thread.id
        let updatedAt = thread.updatedAt

        inFlight.insert(identifier)

        Task { [weak self] in
            defer { self?.inFlight.remove(identifier) }

            guard let status = try? await self?.api.fetchSubjectStatus(at: subjectURL, usingToken: token) else {
                // Recorded as read anyway, so a subject this token cannot see is
                // not asked for again on every redraw of the panel.
                self?.fetchedFor[identifier] = updatedAt
                self?.log.debug("Couldn't read the status of \(subjectURL.lastPathComponent).")
                return
            }

            self?.statuses[identifier] = status
            self?.fetchedFor[identifier] = updatedAt
        }
    }
}
