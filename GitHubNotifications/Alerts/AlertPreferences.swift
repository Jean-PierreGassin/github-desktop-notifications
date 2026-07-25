import Foundation

/// The ready-made choices offered in Settings. Anything the user assembles
/// themselves is kept as ``custom`` and remembered.
enum AlertPreset: String, Sendable, CaseIterable, Codable {
    case essential
    case exceptSystemEvents
    case everything
    case custom

    var displayName: String {
        switch self {
        case .essential: "Only what needs you"
        case .exceptSystemEvents: "Everything except CI and system events"
        case .everything: "Everything"
        case .custom: "Custom"
        }
    }

    var summary: String {
        switch self {
        case .essential: "Reviews, mentions, assignments, security and invitations."
        case .exceptSystemEvents: "All activity on threads you follow, without workflow runs."
        case .everything: "Every notification that reaches your inbox."
        case .custom: "The types you picked below."
        }
    }

    /// The reasons this preset alerts on, or `nil` when the user is choosing
    /// them individually.
    var reasons: Set<NotificationReason>? {
        switch self {
        case .essential:
            Set(NotificationReason.togglableCases.filter { $0.group == .highPriority })
        case .exceptSystemEvents:
            Set(NotificationReason.togglableCases.filter { $0.group != .systemEvents })
        case .everything:
            Set(NotificationReason.togglableCases)
        case .custom:
            nil
        }
    }
}

/// Which notification types are allowed to interrupt the user.
///
/// Everything still shows in the panel; this only decides what raises a macOS
/// alert.
@MainActor
@Observable
final class AlertPreferences {
    /// The one definition of what "default" means here, shared by the
    /// initialiser and by the reset control in Settings.
    static let defaultPreset = AlertPreset.essential

    private static let presetKey = "alertPreset"
    private static let customReasonsKey = "customAlertReasons"

    private let defaults: UserDefaults

    private var customReasons: Set<NotificationReason>

    private(set) var preset: AlertPreset

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        preset = defaults.string(forKey: Self.presetKey).flatMap(AlertPreset.init(rawValue:)) ?? Self.defaultPreset
        customReasons = Set(
            (defaults.stringArray(forKey: Self.customReasonsKey) ?? []).compactMap(NotificationReason.init(rawValue:)),
        )
    }

    var enabledReasons: Set<NotificationReason> {
        preset.reasons ?? customReasons
    }

    func allowsAlert(for reason: NotificationReason) -> Bool {
        enabledReasons.contains(reason)
    }

    func isEnabled(_ reason: NotificationReason) -> Bool {
        enabledReasons.contains(reason)
    }

    func select(_ newPreset: AlertPreset) {
        preset = newPreset
        save()
    }

    /// Picking types by hand always lands the user on their own custom set,
    /// starting from whatever the current preset already alerts on.
    func setEnabled(_ isEnabled: Bool, for reason: NotificationReason) {
        var reasons = enabledReasons

        if isEnabled {
            reasons.insert(reason)
        } else {
            reasons.remove(reason)
        }

        customReasons = reasons
        preset = matchingPreset(for: reasons) ?? .custom
        save()
    }

    func reasons(in group: NotificationGroup) -> [NotificationReason] {
        NotificationReason.togglableCases.filter { $0.group == group }
    }

    /// Drops the hand-picked set as well as the preset, so resetting cannot
    /// leave a stale custom selection waiting to reappear.
    func resetToDefaults() {
        preset = Self.defaultPreset
        customReasons = []
        save()
    }

    /// Keeps the selection honest: hand-picking exactly what a preset covers
    /// shows that preset rather than "Custom".
    private func matchingPreset(for reasons: Set<NotificationReason>) -> AlertPreset? {
        AlertPreset.allCases.first { $0.reasons == reasons }
    }

    private func save() {
        defaults.set(preset.rawValue, forKey: Self.presetKey)
        defaults.set(customReasons.map(\.rawValue), forKey: Self.customReasonsKey)
    }
}
