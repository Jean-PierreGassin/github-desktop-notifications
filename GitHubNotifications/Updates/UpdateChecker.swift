import Foundation

enum UpdateState: Equatable {
    case idle
    case checking
    case upToDate(checkedAt: Date)
    case available(Release)
    case downloading
    case readyToInstall(Release)
    case installsOnQuit(Release)
    case failed(String)
}

/// Finds updates and decides what to do about them.
///
/// Checking is automatic; installing never is. The two are kept apart here so
/// that nothing this class does on a timer can change what is on disk.
@MainActor
@Observable
final class UpdateChecker {
    /// Once a day. A menu bar app that phones home more often than it is opened
    /// is spending someone else's bandwidth on nothing.
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    private let source: ReleaseSource
    private let installer: UpdateInstalling
    private let preferences: UpdatePreferences
    private let log: AppLog
    private let currentVersion: String
    private let now: () -> Date

    private(set) var state = UpdateState.idle

    /// Held so the termination handler can act on a download already verified,
    /// rather than doing anything slow or fallible while quitting.
    private(set) var pendingInstall: URL?

    init(
        source: ReleaseSource,
        installer: UpdateInstalling = UpdateInstaller(),
        preferences: UpdatePreferences,
        log: AppLog,
        currentVersion: String = AppVersion.current,
        now: @escaping () -> Date = Date.init,
    ) {
        self.source = source
        self.installer = installer
        self.preferences = preferences
        self.log = log
        self.currentVersion = currentVersion
        self.now = now
    }

    var installedVersion: String {
        currentVersion
    }

    /// The automatic path. Silent about its failures: there is no value in
    /// telling someone their update check failed while they are reading their
    /// notifications.
    func checkIfDue(usingToken token: String?) async {
        guard preferences.checksAutomatically, isCheckDue else {
            return
        }

        await check(usingToken: token, isManual: false)
    }

    func check(usingToken token: String?, isManual: Bool) async {
        guard !isBusy else {
            return
        }

        state = .checking

        do {
            let release = try await source.fetchLatestRelease(usingToken: token)

            preferences.lastCheckedAt = now()

            guard let release, isWorthOffering(release) else {
                state = .upToDate(checkedAt: now())
                return
            }

            log.info("Version \(release.version) is available.")
            state = .available(release)
        } catch {
            report(error, isManual: isManual)
        }
    }

    /// Downloads and verifies, and stops there. What happens to the bundle is
    /// the user's next decision, not this one's.
    func download(_ release: Release) async {
        state = .downloading

        do {
            pendingInstall = try await installer.downloadAndVerify(release)
            state = .readyToInstall(release)
        } catch {
            pendingInstall = nil
            state = .failed(message(for: error))
            log.error("Couldn't prepare version \(release.version): \(message(for: error))")
        }
    }

    func installAndRestart(_ release: Release) {
        guard let pendingInstall else {
            return
        }

        do {
            try installer.install(from: pendingInstall, relaunching: true)
        } catch {
            state = .failed(message(for: error))
            log.error("Couldn't install version \(release.version): \(message(for: error))")
        }
    }

    /// The bundle is already verified, so quitting is never blocked on the
    /// network or on crypto.
    func installOnQuit(_ release: Release) {
        guard pendingInstall != nil else {
            return
        }

        state = .installsOnQuit(release)
        log.info("Version \(release.version) will be installed when you quit.")
    }

    func performPendingInstallOnQuit() {
        guard case .installsOnQuit = state, let pendingInstall else {
            return
        }

        try? installer.install(from: pendingInstall, relaunching: false)
    }

    func dismissFailure() {
        state = .idle
    }

    private var isBusy: Bool {
        switch state {
        case .checking, .downloading: true
        default: false
        }
    }

    private var isCheckDue: Bool {
        guard let lastCheckedAt = preferences.lastCheckedAt else {
            return true
        }

        return now().timeIntervalSince(lastCheckedAt) >= Self.checkInterval
    }

    /// Strictly newer only. A retracted tag, or a version built locally that is
    /// ahead of the published one, must never pull the user backwards.
    private func isWorthOffering(_ release: Release) -> Bool {
        AppVersion.compare(release.version, currentVersion) == .orderedDescending
    }

    private func report(_ error: Error, isManual: Bool) {
        let description = message(for: error)

        guard isManual else {
            state = .idle
            log.warning("Update check failed: \(description)")
            return
        }

        state = .failed(description)
        log.error("Update check failed: \(description)")
    }

    private func message(for error: Error) -> String {
        (error as? GitHubError)?.userFacingMessage
            ?? (error as? UpdateFailure)?.description
            ?? error.localizedDescription
    }
}
