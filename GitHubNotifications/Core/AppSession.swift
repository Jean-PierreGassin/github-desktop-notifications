import AppKit
import Foundation

/// Composition root. Everything the UI touches hangs off this one object.
@MainActor
@Observable
final class AppSession {
    static let inboxURL = URL(string: "https://github.com/notifications")!

    let log: AppLog
    let auth: AuthService
    let store: NotificationStore
    let poller: Poller
    let notifier: Notifier
    let alertPreferences: AlertPreferences
    let launchAtLogin: LaunchAtLogin

    private static let rowsPerRepositoryKey = "rowsPerRepository"
    private static let defaultRowsPerRepository = 5

    private let api: GitHubAPI
    private let ledger: SeenThreadLedger
    private let defaults: UserDefaults

    init(
        log: AppLog = AppLog.shared,
        api: GitHubAPI = GitHubClient(),
        storage: TokenStorage = KeychainTokenStorage(),
        defaults: UserDefaults = .standard,
    ) {
        self.log = log
        self.api = api
        self.defaults = defaults

        let storedRowsPerRepository = defaults.integer(forKey: Self.rowsPerRepositoryKey)

        auth = AuthService(api: api, storage: storage, log: log)
        store = NotificationStore(
            rowsPerRepository: storedRowsPerRepository > 0 ? storedRowsPerRepository : Self.defaultRowsPerRepository,
        )
        notifier = Notifier(log: log)
        alertPreferences = AlertPreferences(defaults: defaults)
        launchAtLogin = LaunchAtLogin(log: log)
        ledger = SeenThreadLedger(log: log)
        poller = Poller(api: api, auth: auth, store: store, log: log)
    }

    var rowsPerRepository: Int {
        get { store.rowsPerRepository }
        set {
            store.rowsPerRepository = newValue
            defaults.set(newValue, forKey: Self.rowsPerRepositoryKey)
        }
    }

    /// Unit tests load the app as their host, so the launch work is skipped to
    /// keep them off the network and out of the notification centre.
    var isRunningUnderTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func start() async {
        guard !isRunningUnderTests else {
            return
        }

        log.info("GitHub Notifications started.")

        connectAlerts()
        notifier.installClickHandler()

        await notifier.requestAuthorization()
        await auth.restoreSession()

        if auth.isSignedIn {
            poller.start()
        }
    }

    private func connectAlerts() {
        poller.onThreadsFetched = { [weak self] threads in
            self?.announceNewThreads(among: threads)
        }

        notifier.onAlertClicked = { [weak self] threadIdentifier in
            self?.openThread(withIdentifier: threadIdentifier)
        }
    }

    /// The ledger is always updated, even when alerts are off, so turning alerts
    /// back on does not replay a backlog.
    private func announceNewThreads(among threads: [NotificationThread]) {
        let newThreads = ledger.selectThreadsToAnnounce(from: threads)
        let alertableThreads = newThreads.filter { alertPreferences.allowsAlert(for: $0.reason) }

        guard notifier.canPostNotifications, !alertableThreads.isEmpty else {
            return
        }

        log.info("Announcing \(alertableThreads.count) new notifications.")

        Task {
            for thread in NotificationGrouping.sortByPriorityThenRecency(alertableThreads) {
                await notifier.announce(thread)
            }
        }
    }

    private func openThread(withIdentifier identifier: String) {
        guard let thread = store.threads.first(where: { $0.id == identifier }) else {
            openInbox()
            return
        }

        open(thread)
    }

    func signIn(withToken token: String) async {
        await auth.signIn(withToken: token)

        if auth.isSignedIn {
            poller.reset()
            poller.start()
        }
    }

    func signOut() {
        poller.stop()
        poller.reset()
        store.removeAll()
        ledger.clear()
        auth.signOut()
    }

    func open(_ thread: NotificationThread) {
        NSWorkspace.shared.open(ThreadURL.derive(for: thread))

        Task { await markAsRead(thread) }
    }

    func openInbox() {
        NSWorkspace.shared.open(Self.inboxURL)
    }

    func markAsDone(_ thread: NotificationThread) async {
        guard let token = auth.activeToken else {
            return
        }

        store.removeThread(withIdentifier: thread.id)

        do {
            try await api.markThreadAsDone(threadIdentifier: thread.id, usingToken: token)
        } catch {
            log.warning("Couldn't mark \(thread.subject.title) as done: \(error.localizedDescription)")
        }
    }

    func markEverythingAsRead() async {
        guard let token = auth.activeToken else {
            return
        }

        store.removeAll()

        do {
            try await api.markEverythingAsRead(usingToken: token)
            log.info("Marked the whole inbox as read.")
        } catch {
            log.warning("Couldn't mark everything as read: \(error.localizedDescription)")
        }
    }

    private func markAsRead(_ thread: NotificationThread) async {
        guard let token = auth.activeToken else {
            return
        }

        store.removeThread(withIdentifier: thread.id)

        do {
            try await api.markThreadAsRead(threadIdentifier: thread.id, usingToken: token)
        } catch {
            log.warning("Couldn't mark \(thread.subject.title) as read: \(error.localizedDescription)")
        }
    }
}
