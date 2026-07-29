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

/// How much of what happens next on a thread is worth interrupting for.
///
/// The reason a thread is in the inbox settles early and then stops moving: a
/// pull request you were asked to review keeps `review_requested` through every
/// push, comment and check that follows. Choosing threads by reason alone
/// therefore cannot separate the request from the fortnight of activity after
/// it, and a busy thread goes on alerting for as long as it stays busy.
///
/// This is the other half of that choice. Not which threads may interrupt, but
/// which changes to them are worth it.
enum FollowUpAlerts: String, Sendable, CaseIterable, Codable {
    case everything
    case comments
    case nothing

    var displayName: String {
        switch self {
        case .everything: "Everything that happens"
        case .comments: "Only new comments"
        case .nothing: "Nothing else"
        }
    }

    var summary: String {
        switch self {
        case .everything: "Every change to a thread you have already heard about."
        case .comments: "Replies and review comments, but not pushes, checks or merges."
        case .nothing: "Only the first alert about a thread, and any time GitHub changes why it concerns you."
        }
    }

    /// The changes this choice alerts on.
    ///
    /// ``ThreadUpdate/reasonForNotifying`` is in every one of them, including
    /// ``nothing``. It means the thread is new to the user, or that GitHub has
    /// re-reasoned it because it now concerns them more directly, and neither is
    /// follow-up noise. Leaving it out of the quietest choice would turn that
    /// choice into silence.
    var updates: Set<ThreadUpdate> {
        switch self {
        case .everything: [.reasonForNotifying, .comment, .reviewComment, .otherActivity]
        case .comments: [.reasonForNotifying, .comment, .reviewComment]
        case .nothing: [.reasonForNotifying]
        }
    }
}

/// How much of the GitHub inbox the menu bar panel is a view of.
///
/// A type switched off used to be silent and still take a row, which is the
/// worst of both: the setting looked as though it had not worked, and the panel
/// filled with threads the user had already said they did not want.
///
/// Both answers are legitimate, which is why this is asked rather than assumed.
/// Alerting on little and reading the rest at leisure is a real way to use the
/// app, and so is wanting a type gone entirely.
enum PanelContents: String, Sendable, CaseIterable, Codable {
    case chosenTypes
    case everything

    var displayName: String {
        switch self {
        case .chosenTypes: "Only the types switched on below"
        case .everything: "Everything in your GitHub inbox"
        }
    }

    var summary: String {
        switch self {
        case .chosenTypes:
            "A type switched off takes no row, no count and no place in a bulk action. "
                + "Switching it back on returns whatever is still in your inbox."
        case .everything:
            "Every thread GitHub puts in your inbox gets a row, including types you never want alerts for."
        }
    }
}

/// Which notifications the user wants: which types of thread reach them, which
/// of those may interrupt, and how much of what happens afterwards is worth
/// interrupting for.
///
/// The follow-up choice is about interrupting only. Every change to a thread the
/// panel shows still reaches its row, because a row that says what last happened
/// is the answer to an alert missed, held or never asked for.
@MainActor
@Observable
final class AlertPreferences {
    /// The one definition of what "default" means here, shared by the
    /// initialiser and by the reset control in Settings.
    static let defaultPreset = AlertPreset.essential

    /// Comments are the follow-up worth hearing about. Pushes, checks and merges
    /// are the bulk of what happens on a thread and the least of what needs the
    /// user, so they land in the panel and nowhere else.
    static let defaultFollowUpAlerts = FollowUpAlerts.comments

    /// A type the user has switched off is one they have said they do not want,
    /// and the panel takes them at their word. The other choice is one picker
    /// away and the section says so.
    static let defaultPanelContents = PanelContents.chosenTypes

    private static let presetKey = "alertPreset"
    private static let customReasonsKey = "customAlertReasons"
    private static let followUpAlertsKey = "followUpAlerts"
    private static let panelContentsKey = "panelContents"

    private let defaults: UserDefaults

    private var customReasons: Set<NotificationReason>

    private(set) var preset: AlertPreset

    var followUpAlerts: FollowUpAlerts {
        didSet { save() }
    }

    var panelContents: PanelContents {
        didSet { save() }
    }

    /// Called whenever what the panel may show changes, so it can be re-filtered
    /// there and then. Polling is conditional and an unchanged inbox answers 304,
    /// so waiting for the next fetch could leave a switched-off type on screen
    /// until something unrelated happened.
    var onShownReasonsChanged: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        preset = defaults.string(forKey: Self.presetKey).flatMap(AlertPreset.init(rawValue:)) ?? Self.defaultPreset
        customReasons = Set(
            (defaults.stringArray(forKey: Self.customReasonsKey) ?? []).compactMap(NotificationReason.init(rawValue:)),
        )
        followUpAlerts = defaults.string(forKey: Self.followUpAlertsKey)
            .flatMap(FollowUpAlerts.init(rawValue:)) ?? Self.defaultFollowUpAlerts
        panelContents = defaults.string(forKey: Self.panelContentsKey)
            .flatMap(PanelContents.init(rawValue:)) ?? Self.defaultPanelContents
    }

    var enabledReasons: Set<NotificationReason> {
        preset.reasons ?? customReasons
    }

    /// The types the panel is allowed to show.
    ///
    /// ``NotificationReason/unrecognised`` is always among them. It is not in the
    /// settings list, so it cannot have been switched off, and dropping it would
    /// hide a thread the user has no control to bring back the day GitHub adds a
    /// reason this app has no name for yet.
    var shownReasons: Set<NotificationReason> {
        switch panelContents {
        case .everything: Set(NotificationReason.allCases)
        case .chosenTypes: enabledReasons.union([.unrecognised])
        }
    }

    func allowsAlert(for reason: NotificationReason) -> Bool {
        enabledReasons.contains(reason)
    }

    func allowsAlert(about update: ThreadUpdate) -> Bool {
        followUpAlerts.updates.contains(update)
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

    /// Drops the hand-picked set as well as the presets, so resetting cannot
    /// leave a stale custom selection waiting to reappear.
    func resetToDefaults() {
        preset = Self.defaultPreset
        customReasons = []
        followUpAlerts = Self.defaultFollowUpAlerts
        panelContents = Self.defaultPanelContents
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
        defaults.set(followUpAlerts.rawValue, forKey: Self.followUpAlertsKey)
        defaults.set(panelContents.rawValue, forKey: Self.panelContentsKey)

        onShownReasonsChanged?()
    }
}
