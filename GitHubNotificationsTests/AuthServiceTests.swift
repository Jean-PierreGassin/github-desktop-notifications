import Foundation
import Testing

@testable import GitHubNotifications

@MainActor
struct AuthServiceTests {
    @Test
    func signsInAndKeepsTheTokenForLaterRequests() async {
        let storage = InMemoryTokenStorage()
        let auth = makeAuthService(storage: storage)

        await auth.signIn(withToken: "  ghp_valid  ")

        #expect(auth.isSignedIn)
        #expect(auth.activeToken == "ghp_valid")
        #expect(storage.readToken() == "ghp_valid")
    }

    @Test
    func rejectsATokenThatCannotReadTheInbox() async {
        let api = FakeGitHubAPI()
        api.userResult = .success(
            AuthenticatedUser(account: GitHubAccount(login: "octocat", avatarURL: nil), grantedScopes: [.readUser]),
        )
        let storage = InMemoryTokenStorage()
        let auth = makeAuthService(api: api, storage: storage)

        await auth.signIn(withToken: "ghp_wrong_scopes")

        #expect(auth.state == .failed(.missingRequiredScopes([.notifications])))
        #expect(storage.readToken() == nil)
    }

    @Test
    func acceptsATokenWithOnlyTheRepoScope() async {
        let api = FakeGitHubAPI()
        api.userResult = .success(
            AuthenticatedUser(account: GitHubAccount(login: "octocat", avatarURL: nil), grantedScopes: [.repository]),
        )

        let auth = makeAuthService(api: api)
        await auth.signIn(withToken: "ghp_repo_only")

        #expect(auth.isSignedIn)
    }

    @Test
    func throttlesRepeatAttemptsAfterAFailure() async {
        let api = FakeGitHubAPI()
        api.userResult = .failure(.invalidToken)
        let auth = makeAuthService(api: api)

        await auth.signIn(withToken: "ghp_bad")

        #expect(auth.state == .failed(.invalidToken))
        #expect(!auth.canAttemptSignIn)

        await auth.signIn(withToken: "ghp_bad_again")

        #expect(auth.state == .failed(.invalidToken))
    }

    @Test
    func restoresAStoredTokenOnLaunch() async {
        let auth = makeAuthService(storage: InMemoryTokenStorage(token: "ghp_stored"))

        await auth.restoreSession()

        #expect(auth.isSignedIn)
    }

    @Test
    func staysSignedOutWhenThereIsNoStoredToken() async {
        let auth = makeAuthService()

        await auth.restoreSession()

        #expect(auth.state == .signedOut)
    }

    @Test
    func forgetsEverythingOnSignOut() async {
        let storage = InMemoryTokenStorage()
        let auth = makeAuthService(storage: storage)
        await auth.signIn(withToken: "ghp_valid")

        auth.signOut()

        #expect(auth.state == .signedOut)
        #expect(auth.activeToken == nil)
        #expect(storage.readToken() == nil)
        #expect(auth.canAttemptSignIn)
    }

    @Test
    func dropsTheTokenWhenALaterRequestFindsItRevoked() async {
        let storage = InMemoryTokenStorage()
        let auth = makeAuthService(storage: storage)
        await auth.signIn(withToken: "ghp_valid")

        auth.handleTokenRejection()

        #expect(auth.state == .failed(.invalidToken))
        #expect(storage.readToken() == nil)
    }

    private func makeAuthService(
        api: FakeGitHubAPI = FakeGitHubAPI(),
        storage: TokenStorage = InMemoryTokenStorage(),
    ) -> AuthService {
        AuthService(api: api, storage: storage, log: AppLog(subsystem: "tests"))
    }
}
