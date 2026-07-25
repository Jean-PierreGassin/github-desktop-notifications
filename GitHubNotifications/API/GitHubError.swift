import Foundation

/// Every failure the app can surface, each carrying the sentence shown to the
/// user when they hover the warning glyph.
enum GitHubError: Error, Sendable, Equatable {
    case invalidToken
    case missingRequiredScopes(Set<TokenScope>)
    case rateLimited(resetAt: Date)
    case askedToSlowDown(retryAfter: TimeInterval)
    case offline
    case serverFailure(statusCode: Int)
    case malformedResponse
    case transportFailure(description: String)
    case tokenStorageFailure(description: String)

    var userFacingMessage: String {
        switch self {
        case .invalidToken:
            "GitHub no longer accepts your token. Sign in again with a new one."
        case let .missingRequiredScopes(scopes):
            "Your token is missing the \(scopeList(scopes)) scope. Create a new token with it enabled."
        case let .rateLimited(resetAt):
            "GitHub rate limited us. Polling resumes \(relativeDescription(of: resetAt))."
        case let .askedToSlowDown(retryAfter):
            "GitHub asked us to slow down. Retrying in \(Int(retryAfter.rounded())) seconds."
        case .offline:
            "You're offline. Polling resumes when the network comes back."
        case let .serverFailure(statusCode):
            "GitHub returned an unexpected error (\(statusCode)). We'll try again shortly."
        case .malformedResponse:
            "GitHub returned something we couldn't read. We'll try again shortly."
        case let .transportFailure(description):
            "Couldn't reach GitHub: \(description)"
        case let .tokenStorageFailure(description):
            "Couldn't save your token to the keychain (\(description)). Choose Always Allow if macOS asks for "
                + "permission, or delete the \"GitHub Notifications\" entry in Keychain Access and sign in again."
        }
    }

    private func scopeList(_ scopes: Set<TokenScope>) -> String {
        scopes
            .map(\.displayName)
            .sorted()
            .joined(separator: " and ")
    }

    private func relativeDescription(of date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full

        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
