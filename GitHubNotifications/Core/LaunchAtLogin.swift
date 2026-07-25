import Foundation
import ServiceManagement

/// Registers the app as a login item through the modern, approval-free API.
@MainActor
@Observable
final class LaunchAtLogin {
    private let log: AppLog

    var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else {
                return
            }

            apply(isEnabled)
        }
    }

    init(log: AppLog) {
        self.log = log
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    private func apply(_ shouldLaunchAtLogin: Bool) {
        do {
            if shouldLaunchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            log.info("Launch at login is now \(shouldLaunchAtLogin ? "on" : "off").")
        } catch {
            log.error("Couldn't change launch at login: \(error.localizedDescription)")
            isEnabled = SMAppService.mainApp.status == .enabled
        }
    }
}
