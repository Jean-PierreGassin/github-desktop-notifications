import Foundation

/// Drives the polling loop at whatever cadence GitHub asks for.
///
/// A one second ticker decides when the next poll is due rather than a timer per
/// poll, so waking from sleep, a changed poll interval and a manual refresh all
/// fall out of the same check.
@MainActor
@Observable
final class Poller {
    private static let shortestPollInterval: TimeInterval = 60
    private static let offlineRetryDelay: TimeInterval = 15
    private static let tickInterval: Duration = .seconds(1)

    private let api: GitHubAPI
    private let auth: AuthService
    private let store: NotificationStore
    private let log: AppLog

    private var loop: Task<Void, Never>?
    private var lastModified: String?
    private var pausedUntil: Date?

    private(set) var pollInterval: TimeInterval = Poller.shortestPollInterval
    private(set) var lastAttemptAt: Date?
    private(set) var lastSuccessAt: Date?
    private(set) var lastError: GitHubError?
    private(set) var isFetching = false

    /// Called with the full inbox after every fetch that changed something.
    var onThreadsFetched: (([NotificationThread]) -> Void)?

    init(
        api: GitHubAPI,
        auth: AuthService,
        store: NotificationStore,
        log: AppLog,
    ) {
        self.api = api
        self.auth = auth
        self.store = store
        self.log = log
    }

    /// Manual refresh stays locked until GitHub's own poll interval has elapsed,
    /// so a click cannot cost rate limit.
    var canRefreshNow: Bool {
        guard !isFetching, auth.activeToken != nil else {
            return false
        }

        return Date() >= nextPollDueAt
    }

    var nextPollDueAt: Date {
        guard let lastAttemptAt else {
            return .distantPast
        }

        return max(lastAttemptAt.addingTimeInterval(pollInterval), pausedUntil ?? .distantPast)
    }

    func start() {
        guard loop == nil else {
            return
        }

        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollIfDue()
                try? await Task.sleep(for: Self.tickInterval)
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    func reset() {
        lastModified = nil
        lastAttemptAt = nil
        lastSuccessAt = nil
        lastError = nil
        pausedUntil = nil
        pollInterval = Self.shortestPollInterval
    }

    func refreshNow() async {
        guard canRefreshNow else {
            return
        }

        await poll()
    }

    private func pollIfDue() async {
        guard auth.activeToken != nil, !isFetching, Date() >= nextPollDueAt else {
            return
        }

        await poll()
    }

    private func poll() async {
        guard let token = auth.activeToken else {
            return
        }

        isFetching = true
        lastAttemptAt = Date()

        defer { isFetching = false }

        do {
            let response = try await api.fetchNotifications(usingToken: token, since: lastModified)

            lastError = nil
            lastSuccessAt = Date()
            pausedUntil = nil
            adoptPollInterval(response.pollInterval)

            guard !response.isUnchanged else {
                log.debug("Inbox unchanged (304).")
                return
            }

            lastModified = response.lastModified
            store.replaceAll(with: response.threads)
            log.info("Fetched \(response.threads.count) notifications.")
            onThreadsFetched?(response.threads)
        } catch let error as GitHubError {
            handle(error)
        } catch {
            handle(.transportFailure(description: error.localizedDescription))
        }
    }

    private func adoptPollInterval(_ requestedInterval: TimeInterval?) {
        guard let requestedInterval else {
            return
        }

        pollInterval = max(requestedInterval, Self.shortestPollInterval)
    }

    private func handle(_ error: GitHubError) {
        lastError = error
        log.error(error.userFacingMessage)

        switch error {
        case .invalidToken:
            stop()
            auth.handleTokenRejection()
            store.removeAll()
        case let .rateLimited(resetAt):
            pausedUntil = resetAt
        case let .askedToSlowDown(retryAfter):
            pausedUntil = Date().addingTimeInterval(retryAfter)
        case .offline, .transportFailure:
            pausedUntil = Date().addingTimeInterval(Self.offlineRetryDelay)
        case .missingRequiredScopes, .serverFailure, .malformedResponse, .tokenStorageFailure:
            break
        }
    }
}
