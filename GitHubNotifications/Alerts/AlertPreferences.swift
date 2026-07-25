import Foundation

/// Which notification types are allowed to interrupt the user.
///
/// Everything still shows in the panel; this only decides what raises a macOS
/// alert. High priority is on by default, CI and system events are off.
@MainActor
@Observable
final class AlertPreferences {
    private static let storageKey = "enabledAlertReasons"

    private let defaults: UserDefaults

    private(set) var enabledReasons: Set<NotificationReason>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabledReasons = Self.loadEnabledReasons(from: defaults)
    }

    func allowsAlert(for reason: NotificationReason) -> Bool {
        enabledReasons.contains(reason)
    }

    func isEnabled(_ reason: NotificationReason) -> Bool {
        enabledReasons.contains(reason)
    }

    func setEnabled(_ isEnabled: Bool, for reason: NotificationReason) {
        if isEnabled {
            enabledReasons.insert(reason)
        } else {
            enabledReasons.remove(reason)
        }

        save()
    }

    func setEnabled(_ isEnabled: Bool, forGroup group: NotificationGroup) {
        for reason in reasons(in: group) {
            if isEnabled {
                enabledReasons.insert(reason)
            } else {
                enabledReasons.remove(reason)
            }
        }

        save()
    }

    func isFullyEnabled(_ group: NotificationGroup) -> Bool {
        reasons(in: group).allSatisfy(enabledReasons.contains)
    }

    func isPartiallyEnabled(_ group: NotificationGroup) -> Bool {
        let groupReasons = reasons(in: group)

        return groupReasons.contains(where: enabledReasons.contains) && !groupReasons.allSatisfy(enabledReasons.contains)
    }

    func reasons(in group: NotificationGroup) -> [NotificationReason] {
        NotificationReason.togglableCases.filter { $0.group == group }
    }

    private func save() {
        defaults.set(enabledReasons.map(\.rawValue), forKey: Self.storageKey)
    }

    private static func loadEnabledReasons(from defaults: UserDefaults) -> Set<NotificationReason> {
        guard let storedReasons = defaults.stringArray(forKey: storageKey) else {
            return Set(NotificationReason.togglableCases.filter { $0.group.alertsByDefault })
        }

        return Set(storedReasons.compactMap(NotificationReason.init(rawValue:)))
    }
}
