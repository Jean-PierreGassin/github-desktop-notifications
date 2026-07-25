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
        case .reviewRequested: "Review requested"
        case .approvalRequested: "Approval requested"
        case .assigned: "Assigned to you"
        case .mentioned: "You were mentioned"
        case .teamMentioned: "Your team was mentioned"
        case .invitation: "Invitation"
        case .securityAlert: "Security alert"
        case .securityAdvisoryCredit: "Security credit"
        case .author: "Activity on your thread"
        case .comment: "New comment"
        case .manual: "Manually subscribed"
        case .subscribed: "Watching this repo"
        case .stateChange: "Status changed"
        case .ciActivity: "Workflow run"
        case .memberFeatureRequested: "Feature request"
        case .unrecognised: "Other activity"
        }
    }

    var symbolName: String {
        switch self {
        case .reviewRequested, .approvalRequested: "checkmark.circle"
        case .assigned: "person.crop.circle"
        case .mentioned, .teamMentioned: "at"
        case .invitation: "envelope"
        case .securityAlert, .securityAdvisoryCredit: "shield.lefthalf.filled"
        case .author: "pencil"
        case .comment: "bubble.left"
        case .manual, .subscribed: "eye"
        case .stateChange: "arrow.triangle.branch"
        case .ciActivity: "hammer"
        case .memberFeatureRequested: "sparkles"
        case .unrecognised: "bell"
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
