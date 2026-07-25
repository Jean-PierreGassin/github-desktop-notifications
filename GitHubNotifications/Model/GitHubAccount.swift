import Foundation

struct GitHubAccount: Sendable, Equatable, Codable {
    let login: String
    let avatarURL: URL?

    enum CodingKeys: String, CodingKey {
        case login
        case avatarURL = "avatar_url"
    }
}

/// The result of validating a token: who it belongs to, and what it is allowed
/// to do.
struct AuthenticatedUser: Sendable, Equatable {
    let account: GitHubAccount
    let grantedScopes: Set<TokenScope>

    var canSeePrivateRepositories: Bool {
        grantedScopes.contains(.repository)
    }
}
