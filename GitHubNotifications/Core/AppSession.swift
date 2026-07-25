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
    let notificationContentPreferences: NotificationContentPreferences
    let workHoursPreferences: WorkHoursPreferences
    let behaviourPreferences: BehaviourPreferences
    let heldAlerts: HeldAlertQueue
    let launchAtLogin: LaunchAtLogin

    private static let rowsPerRepositoryKey = "rowsPerRepository"
    private static let defaultRowsPerRepository = 5

    private static let heldAlertCheckInterval: Duration = .seconds(30)

    private let api: GitHubAPI
    private let ledger: SeenThreadLedger
    private let defaults: UserDefaults

    private var heldAlertLoop: Task<Void, Never>?

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
        notificationContentPreferences = NotificationContentPreferences(defaults: defaults)
        workHoursPreferences = WorkHoursPreferences(defaults: defaults)
        behaviourPreferences = BehaviourPreferences(defaults: defaults)
        heldAlerts = HeldAlertQueue(log: log)
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

        startHeldAlertLoop()
    }

    /// Held alerts are released on their own schedule, independent of polling,
    /// so a quiet inbox still delivers what was saved up.
    private func startHeldAlertLoop() {
        guard heldAlertLoop == nil else {
            return
        }

        heldAlertLoop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.releaseHeldAlertsIfDue()
                try? await Task.sleep(for: Self.heldAlertCheckInterval)
            }
        }
    }

    private func releaseHeldAlertsIfDue() async {
        guard !heldAlerts.isEmpty else {
            return
        }

        let hours = workHoursPreferences.hours

        guard !hours.isEnabled || hours.isHeldDeliveryDue(at: Date()) else {
            return
        }

        let released = heldAlerts.drain()
        log.info("Delivering \(released.count) notifications held outside your hours.")

        await post(released)
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

        let hours = workHoursPreferences.hours

        guard !hours.isEnabled || hours.isWithinHours(Date()) else {
            heldAlerts.hold(alertableThreads)
            log.info("Holding \(alertableThreads.count) notifications until your hours start.")
            return
        }

        log.info("Announcing \(alertableThreads.count) new notifications.")

        Task { await post(alertableThreads) }
    }

    private func post(_ threads: [NotificationThread]) async {
        for thread in NotificationGrouping.sortByPriorityThenRecency(threads) {
            await notifier.announce(thread, settings: notificationContentPreferences.settings)
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
        heldAlerts.clear()
        auth.signOut()
    }

    func open(_ thread: NotificationThread) {
        askAboutMarkingAsReadIfNeeded()

        NSWorkspace.shared.open(ThreadURL.derive(for: thread))

        guard behaviourPreferences.marksAsReadOnOpen else {
            return
        }

        Task { await markAsRead(thread) }
    }

    /// Asked once, the first time a notification is opened, because silently
    /// clearing someone's inbox is a surprise if they use it as a to-do list.
    private func askAboutMarkingAsReadIfNeeded() {
        guard !behaviourPreferences.hasChosenMarkAsReadBehaviour else {
            return
        }

        behaviourPreferences.hasChosenMarkAsReadBehaviour = true

        let prompt = NSAlert()
        prompt.messageText = "Mark notifications as read when you open them?"
        prompt.informativeText = "Opening a notification usually means you have dealt with it, so it can be cleared "
            + "from your inbox automatically. You can change this later in Settings."
        prompt.addButton(withTitle: "Yes")
        prompt.addButton(withTitle: "No, I will mark them myself")

        NSApplication.shared.activate(ignoringOtherApps: true)

        behaviourPreferences.marksAsReadOnOpen = prompt.runModal() == .alertFirstButtonReturn
        log.info("Marking as read on open is \(behaviourPreferences.marksAsReadOnOpen ? "on" : "off").")
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

    func markAsRead(_ thread: NotificationThread) async {
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
