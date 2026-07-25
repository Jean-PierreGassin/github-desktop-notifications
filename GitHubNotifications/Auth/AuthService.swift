import Foundation

enum AuthenticationState: Sendable, Equatable {
    case signedOut
    case validating
    case signedIn(AuthenticatedUser)
    case failed(GitHubError)
}

/// Owns the token: validates it, keeps it in the keychain, and throttles repeat
/// attempts so a wrong token can't be hammered against GitHub.
@MainActor
@Observable
final class AuthService {
    private static let longestRetryDelay: TimeInterval = 60

    private let api: GitHubAPI
    private let storage: TokenStorage
    private let log: AppLog

    private var consecutiveFailureCount = 0

    private(set) var state: AuthenticationState = .signedOut
    private(set) var nextAttemptAllowedAt: Date?
    private(set) var activeToken: String?

    init(
        api: GitHubAPI,
        storage: TokenStorage,
        log: AppLog,
    ) {
        self.api = api
        self.storage = storage
        self.log = log
    }

    var isSignedIn: Bool {
        if case .signedIn = state {
            return true
        }

        return false
    }

    var canAttemptSignIn: Bool {
        guard let nextAttemptAllowedAt else {
            return true
        }

        return Date() >= nextAttemptAllowedAt
    }

    func restoreSession() async {
        guard let storedToken = storage.readToken() else {
            log.info("No stored token; waiting for sign in.")
            return
        }

        log.info("Found a stored token; validating it.")
        await validate(token: storedToken, persistOnSuccess: false)
    }

    func signIn(withToken token: String) async {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedToken.isEmpty, canAttemptSignIn else {
            return
        }

        await validate(token: trimmedToken, persistOnSuccess: true)
    }

    func signOut() {
        storage.deleteToken()
        activeToken = nil
        consecutiveFailureCount = 0
        nextAttemptAllowedAt = nil
        state = .signedOut
        log.info("Signed out and cleared the stored token.")
    }

    /// Called when a later request discovers the token has been revoked.
    func handleTokenRejection() {
        storage.deleteToken()
        activeToken = nil
        state = .failed(.invalidToken)
        log.error(GitHubError.invalidToken.userFacingMessage)
    }

    private func validate(token: String, persistOnSuccess: Bool) async {
        state = .validating

        do {
            let user = try await api.fetchAuthenticatedUser(usingToken: token)
            try requireInboxAccess(for: user.grantedScopes)

            if persistOnSuccess {
                try storage.writeToken(token)
            }

            activeToken = token
            consecutiveFailureCount = 0
            nextAttemptAllowedAt = nil
            state = .signedIn(user)
            log.info("Signed in as \(user.account.login).")

            if !user.canSeePrivateRepositories {
                log.warning("Token has no repo scope; private and organisation notifications will be missing.")
            }
        } catch let error as GitHubError {
            recordFailure(error)
        } catch let error as KeychainError {
            recordFailure(.transportFailure(description: "couldn't save to keychain (\(error.localizedDescription))"))
        } catch {
            recordFailure(.transportFailure(description: error.localizedDescription))
        }
    }

    /// - Throws: ``GitHubError/missingRequiredScopes(_:)`` when the token cannot read the inbox.
    private func requireInboxAccess(for grantedScopes: Set<TokenScope>) throws {
        let canReadInbox = grantedScopes.contains(.notifications) || grantedScopes.contains(.repository)

        guard canReadInbox else {
            throw GitHubError.missingRequiredScopes([.notifications])
        }
    }

    private func recordFailure(_ error: GitHubError) {
        consecutiveFailureCount += 1
        activeToken = nil
        state = .failed(error)

        let backoffDelay = min(pow(2, Double(consecutiveFailureCount)), Self.longestRetryDelay)
        nextAttemptAllowedAt = Date().addingTimeInterval(backoffDelay)

        log.error("Sign in failed: \(error.userFacingMessage)")
    }
}
