import Foundation

/// The classic personal access token scopes this app cares about.
///
/// The notifications endpoints are only reachable with a classic token: GitHub
/// Apps are unsupported there, and fine-grained tokens have no notifications
/// permission at all.
enum TokenScope: String, Sendable, CaseIterable {
    case notifications
    case repository = "repo"
    case publicRepository = "public_repo"
    case readUser = "read:user"

    var displayName: String {
        switch self {
        case .notifications: "notifications"
        case .repository: "repo"
        case .publicRepository: "public_repo"
        case .readUser: "read:user"
        }
    }

    var purpose: String {
        switch self {
        case .notifications: "Read your notification inbox and mark threads as read."
        case .repository: "See notifications from private and organisation repositories."
        case .publicRepository: "See notifications from public repositories only."
        case .readUser: "Show which account you are signed in as."
        }
    }

    static func parse(headerValue: String) -> Set<TokenScope> {
        let grantedNames = headerValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        return Set(grantedNames.compactMap(TokenScope.init(rawValue:)))
    }
}
