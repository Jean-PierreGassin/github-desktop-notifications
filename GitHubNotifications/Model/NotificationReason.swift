import Foundation

/// The curated buckets the user toggles in Settings. Order is also the sort
/// order used everywhere in the panel.
enum NotificationGroup: String, Sendable, CaseIterable, Codable {
    case highPriority
    case medium
    case low
    case systemEvents

    var displayName: String {
        switch self {
        case .highPriority: "High priority"
        case .medium: "Medium priority"
        case .low: "Low priority"
        case .systemEvents: "CI and system events"
        }
    }

    var summary: String {
        switch self {
        case .highPriority: "Someone is waiting on you."
        case .medium: "Activity on threads you are part of."
        case .low: "Everything else you are watching."
        case .systemEvents: "Workflow runs and account housekeeping."
        }
    }

    var alertsByDefault: Bool {
        self == .highPriority
    }

    var priorityRank: Int {
        switch self {
        case .highPriority: 0
        case .medium: 1
        case .low: 2
        case .systemEvents: 3
        }
    }
}

/// Why GitHub put a thread in your inbox.
enum NotificationReason: String, Sendable, CaseIterable, Codable {
    case reviewRequested = "review_requested"
    case approvalRequested = "approval_requested"
    case assigned = "assign"
    case mentioned = "mention"
    case teamMentioned = "team_mention"
    case invitation
    case securityAlert = "security_alert"
    case securityAdvisoryCredit = "security_advisory_credit"
    case author
    case comment
    case manual
    case subscribed
    case stateChange = "state_change"
    case ciActivity = "ci_activity"
    case memberFeatureRequested = "member_feature_requested"
    case unrecognised

    /// Reasons the user can toggle. ``unrecognised`` exists only so a new GitHub
    /// reason cannot break decoding.
    static var togglableCases: [NotificationReason] {
        allCases.filter { $0 != .unrecognised }
    }

    var displayName: String {
        switch self {
        case .reviewRequested: "Review requested from you"
        case .approvalRequested: "Your approval needed to run"
        case .assigned: "Assigned to you"
        case .mentioned: "You were mentioned"
        case .teamMentioned: "Your team was mentioned"
        case .invitation: "You were invited"
        case .securityAlert: "Security alert"
        case .securityAdvisoryCredit: "Credited on an advisory"
        case .author: "Reply on something you opened"
        case .comment: "New comment on a thread"
        case .manual: "Thread you subscribed to"
        case .subscribed: "Repository you watch"
        case .stateChange: "Closed, merged or reopened"
        case .ciActivity: "Workflow run finished"
        case .memberFeatureRequested: "Organisation feature request"
        case .unrecognised: "Other activity"
        }
    }

    /// The longer form used where there is room to explain, such as settings.
    var explanation: String {
        switch self {
        case .reviewRequested: "Someone asked you to review a pull request."
        case .approvalRequested: "A workflow run is waiting on your approval."
        case .assigned: "You were assigned to an issue or pull request."
        case .mentioned: "Someone wrote your @username."
        case .teamMentioned: "Someone mentioned a team you belong to."
        case .invitation: "You were invited to a repository or organisation."
        case .securityAlert: "A vulnerability was found in a repository you can see."
        case .securityAdvisoryCredit: "You were credited on a security advisory."
        case .author: "Activity on an issue, pull request or discussion you opened."
        case .comment: "A new comment on a thread you are part of."
        case .manual: "A thread you subscribed to by hand."
        case .subscribed: "Activity in a repository you watch."
        case .stateChange: "An issue or pull request was closed, merged or reopened."
        case .ciActivity: "A GitHub Actions workflow you triggered finished."
        case .memberFeatureRequested: "Someone in your organisation requested a feature."
        case .unrecognised: "A notification type this app does not recognise yet."
        }
    }

    /// Circled variants throughout, so no row's icon is optically lighter than
    /// its neighbours. A bare `at` or `pencil` next to `checkmark.circle` reads
    /// as a different size even at the same point size.
    var symbolName: String {
        switch self {
        case .reviewRequested, .approvalRequested: "checkmark.circle"
        case .assigned: "person.crop.circle"
        case .mentioned, .teamMentioned: "at.circle"
        case .invitation: "envelope.circle"
        case .securityAlert, .securityAdvisoryCredit: "exclamationmark.shield"
        case .author: "pencil.circle"
        case .comment: "bubble.left.circle"
        case .manual, .subscribed: "eye.circle"
        case .stateChange: "arrow.triangle.branch"
        case .ciActivity: "hammer.circle"
        case .memberFeatureRequested: "sparkles"
        case .unrecognised: "bell.circle"
        }
    }

    /// Whether a thread that reached you for this reason is yours, in the sense
    /// that what happens on it next is still your business.
    ///
    /// Being asked to review a pull request makes the request yours. It does not
    /// make the approvals, the pushes and the other reviewers' comments that
    /// follow yours: you were asked for one thing, and you either do it or you
    /// don't. A thread you opened, were assigned, were named on or joined in on
    /// is the opposite, and what happens next on it is the whole point of it.
    ///
    /// This does not silence anything for good. GitHub re-reasons a thread when
    /// it starts concerning you differently - a review request becomes a mention
    /// the moment someone writes your name on it - and a changed reason is news
    /// under every follow-up setting there is.
    var makesTheThreadYours: Bool {
        switch self {
        case .author, .assigned, .mentioned, .comment, .manual:
            true
        case .reviewRequested, .approvalRequested, .teamMentioned, .invitation, .securityAlert,
             .securityAdvisoryCredit, .subscribed, .stateChange, .ciActivity, .memberFeatureRequested,
             .unrecognised:
            false
        }
    }

    var group: NotificationGroup {
        switch self {
        case .reviewRequested, .approvalRequested, .assigned, .mentioned, .teamMentioned,
             .invitation, .securityAlert, .securityAdvisoryCredit:
            .highPriority
        case .author, .comment, .manual:
            .medium
        case .subscribed, .stateChange, .unrecognised:
            .low
        case .ciActivity, .memberFeatureRequested:
            .systemEvents
        }
    }

    var priorityRank: Int {
        group.priorityRank
    }

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)

        self = NotificationReason(rawValue: rawValue) ?? .unrecognised
    }
}
