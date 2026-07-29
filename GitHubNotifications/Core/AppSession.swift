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
    let avatars: AvatarCache
    let subjectStatuses: SubjectStatusCache
    let updatePreferences: UpdatePreferences
    let updates: UpdateChecker

    static let defaultRowsPerRepository = 10

    /// Read rows count against this limit as well as unread ones, so it is lower
    /// than it was: ten rows of one repository is already a wall of text.
    static let rowsPerRepositoryLimits = 1 ... 10

    private static let rowsPerRepositoryKey = "rowsPerRepository"

    private static let heldAlertCheckInterval: Duration = .seconds(30)

    /// Reconciliation is a full, unconditional read of the inbox, so it runs
    /// rarely. Losing it degrades gracefully: read rows then linger until the
    /// visible-row limit evicts them.
    private static let reconciliationInterval: Duration = .seconds(3600)

    private let api: GitHubAPI
    private let ledger: SeenThreadLedger
    private let readLedger: ReadThreadLedger
    private let defaults: UserDefaults

    private var heldAlertLoop: Task<Void, Never>?
    private var reconciliationLoop: Task<Void, Never>?

    /// The last action that GitHub refused, shown in the panel. The row it
    /// touched has already been put back by the time this is set.
    private(set) var lastActionFailure: String?

    /// How far through a bulk dismiss the app is, so a hundred sequential
    /// deletes do not look like a freeze.
    private(set) var bulkProgress: String?

    /// Set once, right after the first successful sign-in. The menu bar opens
    /// Settings when it turns true, and Settings shows the choice as a sheet.
    private(set) var isAskingForClickBehaviour = false

    /// The setting to draw attention to once the sheet closes, so the user is
    /// shown where the choice they just made lives.
    private(set) var highlightedSettingsField: SettingsField?

    /// `supportDirectory` exists so tests can keep their ledgers out of the real
    /// Application Support folder.
    init(
        log: AppLog = AppLog.shared,
        api: GitHubAPI = GitHubClient(),
        releases: ReleaseSource = GitHubClient(),
        storage: TokenStorage = KeychainTokenStorage(),
        defaults: UserDefaults = .standard,
        supportDirectory: URL? = nil,
    ) {
        self.log = log
        self.api = api
        self.defaults = defaults

        let storedRowsPerRepository = defaults.integer(forKey: Self.rowsPerRepositoryKey)

        auth = AuthService(api: api, storage: storage, log: log)
        readLedger = ReadThreadLedger(fileURL: supportDirectory?.appending(path: "read-threads.json"), log: log)
        store = NotificationStore(
            rowsPerRepository: Self.clampRowsPerRepository(storedRowsPerRepository),
            readLedger: readLedger,
        )
        notifier = Notifier(log: log)
        alertPreferences = AlertPreferences(defaults: defaults)
        notificationContentPreferences = NotificationContentPreferences(defaults: defaults)
        workHoursPreferences = WorkHoursPreferences(defaults: defaults)
        behaviourPreferences = BehaviourPreferences(defaults: defaults)
        heldAlerts = HeldAlertQueue(fileURL: supportDirectory?.appending(path: "held-alerts.json"), log: log)
        launchAtLogin = LaunchAtLogin(log: log)
        ledger = SeenThreadLedger(fileURL: supportDirectory?.appending(path: "seen-threads.json"), log: log)
        avatars = AvatarCache(directory: supportDirectory?.appending(path: "avatars"), log: log)
        subjectStatuses = SubjectStatusCache(api: api, auth: auth, log: log)
        updatePreferences = UpdatePreferences(defaults: defaults)
        updates = UpdateChecker(source: releases, preferences: updatePreferences, log: log)
        poller = Poller(api: api, auth: auth, store: store, log: log)

        connectTypeFilter()
    }

    /// Keeps the panel showing what the user has asked it to show. Switching a
    /// type off used to silence it and leave the row, which read as the setting
    /// not having worked.
    private func connectTypeFilter() {
        store.shownReasons = alertPreferences.shownReasons

        alertPreferences.onShownReasonsChanged = { [weak self] in
            guard let self else {
                return
            }

            store.shownReasons = alertPreferences.shownReasons
        }
    }

    var rowsPerRepository: Int {
        get { store.rowsPerRepository }
        set {
            let clamped = Self.clampRowsPerRepository(newValue)

            store.rowsPerRepository = clamped
            defaults.set(clamped, forKey: Self.rowsPerRepositoryKey)
        }
    }

    /// A value stored before the limit dropped to ten is clamped on read rather
    /// than left to show more rows than the panel is built for.
    private static func clampRowsPerRepository(_ storedValue: Int) -> Int {
        guard storedValue > 0 else {
            return defaultRowsPerRepository
        }

        return min(max(storedValue, rowsPerRepositoryLimits.lowerBound), rowsPerRepositoryLimits.upperBound)
    }

    /// The menu bar section's reset. Launching at login is a system registration
    /// rather than a stored value, so it is turned off rather than forgotten.
    func resetMenuBarPreferences() {
        rowsPerRepository = Self.defaultRowsPerRepository
        launchAtLogin.isEnabled = false
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

        log.info("GitHub Notifications \(AppVersion.current) started.")

        connectAlerts()
        notifier.installClickHandler()

        await notifier.requestAuthorization()
        await auth.restoreSession()

        if auth.isSignedIn {
            poller.start()
            askForClickBehaviourIfNeeded()
            await reconcileReadThreads()
        }

        installPendingUpdateOnQuit()
        startHeldAlertLoop()
        startReconciliationLoop()

        // After the poller, so a launch never fires two calls at once.
        await updates.checkIfDue(usingToken: auth.activeToken)
    }

    /// The swap runs from a script that waits for this process to exit, so all
    /// that is needed here is to start it on the way out.
    private func installPendingUpdateOnQuit() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main,
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updates.performPendingInstallOnQuit()
            }
        }
    }

    /// Polling stays unread-only and conditional, which is what makes an idle
    /// inbox free. This is the one call that reads the whole inbox, and it exists
    /// only to find out which locally-held read threads still exist.
    private func startReconciliationLoop() {
        guard reconciliationLoop == nil else {
            return
        }

        reconciliationLoop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.reconciliationInterval)
                await self?.reconcileReadThreads()

                // The checker keeps its own daily floor; this only gives it the
                // chance to notice a day has passed without a relaunch.
                await self?.updates.checkIfDue(usingToken: self?.auth.activeToken)
            }
        }
    }

    private func reconcileReadThreads() async {
        guard let token = auth.activeToken else {
            return
        }

        do {
            let inbox = try await api.fetchEntireInbox(usingToken: token)

            store.reconcile(withInboxIdentifiers: Set(inbox.map(\.id)))
        } catch {
            log.debug("Couldn't reconcile read notifications: \(error.localizedDescription)")
        }
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
            self?.handleFetchedThreads(threads)
        }

        notifier.onAlertClicked = { [weak self] threadIdentifier in
            self?.openThread(withIdentifier: threadIdentifier)
        }
    }

    /// The ledger is always updated, even when alerts are off, so turning alerts
    /// back on does not replay a backlog.
    ///
    /// What last changed reaches the panel whether or not it is worth an alert.
    /// A row that says what happened is the answer to an alert missed, held or
    /// never asked for, and it is why a busy thread does not need a banner per
    /// event to stay legible.
    private func handleFetchedThreads(_ threads: [NotificationThread]) {
        let announcements = ledger.selectThreadsToAnnounce(from: threads)

        store.showLatestUpdates(ledger.latestUpdates)
        announce(announcements)
    }

    private func announce(_ announcements: [ThreadAnnouncement]) {
        let alertable = announcements.filter(isWorthInterruptingFor)

        guard notifier.canPostNotifications, !alertable.isEmpty else {
            return
        }

        let hours = workHoursPreferences.hours

        guard !hours.isEnabled || hours.isWithinHours(Date()) else {
            heldAlerts.hold(alertable)
            log.info("Holding \(alertable.count) notifications until your hours start.")
            return
        }

        log.info("Announcing \(alertable.count) new notifications.")

        Task { await post(alertable) }
    }

    /// Two questions rather than one: whether this kind of thread may interrupt
    /// at all, and whether this particular change to it has earned an alert of
    /// its own. The second is what keeps a pull request from alerting on every
    /// push and green tick for as long as it is open.
    private func isWorthInterruptingFor(_ announcement: ThreadAnnouncement) -> Bool {
        alertPreferences.allowsAlert(for: announcement.thread.reason)
            && alertPreferences.allowsAlert(about: announcement.update)
    }

    private func post(_ announcements: [ThreadAnnouncement]) async {
        for announcement in NotificationGrouping.sortByPriorityThenRecency(announcements) {
            await notifier.announce(announcement, settings: notificationContentPreferences.settings)
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

        guard auth.isSignedIn else {
            return
        }

        poller.reset()
        poller.start()
        askForClickBehaviourIfNeeded()
    }

    /// Asked once, straight after signing in, because what a click does to
    /// someone's inbox is not a thing to discover by accident.
    private func askForClickBehaviourIfNeeded() {
        guard !behaviourPreferences.hasChosenClickBehaviour else {
            return
        }

        isAskingForClickBehaviour = true
    }

    func chooseClickBehaviour(_ behaviour: ClickBehaviour) {
        behaviourPreferences.clickBehaviour = behaviour
        behaviourPreferences.hasChosenClickBehaviour = true
        isAskingForClickBehaviour = false
        highlightedSettingsField = .clickBehaviour

        log.info("Clicking a notification now marks it \(behaviour.displayName.lowercased()).")
    }

    /// Closing the sheet without answering keeps whatever is already set and
    /// does not ask again. The question is a courtesy, not a gate.
    func dismissClickBehaviourPrompt() {
        guard isAskingForClickBehaviour else {
            return
        }

        chooseClickBehaviour(behaviourPreferences.clickBehaviour)
    }

    func clearSettingsHighlight() {
        highlightedSettingsField = nil
    }

    func signOut() {
        poller.stop()
        poller.reset()
        store.removeAll()
        ledger.clear()
        heldAlerts.clear()
        subjectStatuses.clear()
        auth.signOut()
    }

    /// Opening always goes to the browser first; what happens to the row is
    /// whatever the user chose, applied by the one path below.
    func open(_ thread: NotificationThread) {
        NSWorkspace.shared.open(ThreadURL.derive(for: thread))

        Task { await apply(behaviourPreferences.clickBehaviour, to: thread) }
    }

    func openInbox() {
        NSWorkspace.shared.open(Self.inboxURL)
    }

    func dismissFailure() {
        lastActionFailure = nil
    }

    /// The single entry point for a row click, the row button and the context
    /// menu, so a button can never do something a click would not.
    ///
    /// The panel changes first and GitHub is told afterwards. A refusal puts the
    /// row back exactly where it was rather than leaving the panel lying.
    func apply(_ behaviour: ClickBehaviour, to thread: NotificationThread) async {
        guard let token = auth.activeToken else {
            return
        }

        // The position comes back from the removal itself rather than being read
        // off the visible rows beforehand: with types hidden, the two are not the
        // same index, and a rollback has to use the one the store restores with.
        let originalIndex = applyLocally(behaviour, to: thread)

        do {
            if behaviour.marksAsRead {
                try await api.markThreadAsRead(threadIdentifier: thread.id, usingToken: token)
            }

            if behaviour.dismisses {
                try await api.markThreadAsDone(threadIdentifier: thread.id, usingToken: token)
            }
        } catch {
            rollBack(behaviour, of: thread, to: originalIndex)
            report(error, whileApplying: behaviour, to: thread)
        }
    }

    /// Returns where a dismissed thread was, for putting it back if GitHub
    /// refuses. Marking read leaves the row where it is, so there is nothing to
    /// remember.
    private func applyLocally(_ behaviour: ClickBehaviour, to thread: NotificationThread) -> Int? {
        guard behaviour.dismisses else {
            store.markRead(thread.id)
            return nil
        }

        return store.removeThread(withIdentifier: thread.id)
    }

    private func rollBack(_ behaviour: ClickBehaviour, of thread: NotificationThread, to index: Int?) {
        guard behaviour.dismisses else {
            store.unmarkRead(thread.id)
            return
        }

        store.restore(thread, at: index ?? 0)
    }

    private func report(_ error: Error, whileApplying behaviour: ClickBehaviour, to thread: NotificationThread) {
        let reason = (error as? GitHubError)?.userFacingMessage ?? error.localizedDescription

        lastActionFailure = "Couldn't \(behaviour.actionTitle.lowercased()) \(thread.subject.title). \(reason)"
        log.warning(lastActionFailure ?? "")
    }

    /// Marking the whole inbox read is one request. Dismissing has no bulk
    /// endpoint at all, so it is one request per thread, run in order with
    /// progress reported rather than freezing the panel.
    func applyToEverything(_ behaviour: ClickBehaviour) async {
        guard let token = auth.activeToken else {
            return
        }

        if behaviour.marksAsRead {
            await markEverythingAsRead(usingToken: token, keepingRows: !behaviour.dismisses)
        }

        guard behaviour.dismisses else {
            return
        }

        await dismissEverything(usingToken: token)
    }

    /// Under plain Read the rows stay, so each one is marked read locally too.
    /// Under a dismissing behaviour they are about to go anyway.
    private func markEverythingAsRead(usingToken token: String, keepingRows: Bool) async {
        do {
            try await api.markEverythingAsRead(usingToken: token)
            log.info("Marked the whole inbox as read.")

            guard keepingRows else {
                return
            }

            store.threads.map(\.id).forEach(store.markRead)
        } catch {
            lastActionFailure = "Couldn't mark everything as read. \(userFacingReason(for: error))"
            log.warning(lastActionFailure ?? "")
        }
    }

    private func dismissEverything(usingToken token: String) async {
        let threads = store.threads

        defer { bulkProgress = nil }

        for (offset, thread) in threads.enumerated() {
            bulkProgress = "Dismissing \(offset + 1) of \(threads.count)"

            do {
                try await api.markThreadAsDone(threadIdentifier: thread.id, usingToken: token)
                store.removeThread(withIdentifier: thread.id)
            } catch {
                lastActionFailure = "Stopped after \(offset) of \(threads.count). \(userFacingReason(for: error))"
                log.warning(lastActionFailure ?? "")
                return
            }
        }

        log.info("Dismissed \(threads.count) notifications.")
    }

    private func userFacingReason(for error: Error) -> String {
        (error as? GitHubError)?.userFacingMessage ?? error.localizedDescription
    }
}
