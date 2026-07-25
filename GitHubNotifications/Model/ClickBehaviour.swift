import Foundation

/// What clicking a notification does to it.
///
/// Read & Dismissed is the default because it is what GitHub's own inbox does
/// when you open a thread. There is deliberately no "do nothing" option: a click
/// that leaves the row exactly as it was makes the panel a list you have to
/// tidy by hand.
enum ClickBehaviour: String, Sendable, CaseIterable, Codable {
    case read
    case dismissed
    case readAndDismissed

    static let `default` = ClickBehaviour.readAndDismissed

    var displayName: String {
        switch self {
        case .read: "Read"
        case .dismissed: "Dismissed"
        case .readAndDismissed: "Read & Dismissed"
        }
    }

    var explanation: String {
        switch self {
        case .read:
            "Keeps the notification here with its unread dot removed, and leaves it in GitHub's notification centre."
        case .dismissed:
            "Removes the notification from this app, but keeps it in GitHub's notification centre."
        case .readAndDismissed:
            "Marks it read, removes it from this app, and clears it from GitHub's notification centre."
        }
    }

    /// What the row button and the bulk button say, so neither can disagree with
    /// what a click already does.
    var actionTitle: String {
        switch self {
        case .read: "Mark as read"
        case .dismissed: "Dismiss"
        case .readAndDismissed: "Mark as read & dismiss"
        }
    }

    var bulkActionTitle: String {
        switch self {
        case .read: "Mark all as read"
        case .dismissed: "Dismiss all"
        case .readAndDismissed: "Mark all as read & dismiss"
        }
    }

    /// Dismissing clears the thread on every device and cannot be undone from
    /// here, so doing it to a whole inbox is worth asking about first.
    var needsBulkConfirmation: Bool {
        self != .read
    }

    var marksAsRead: Bool {
        self != .dismissed
    }

    var dismisses: Bool {
        self != .read
    }
}
