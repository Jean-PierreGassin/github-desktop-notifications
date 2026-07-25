import Combine
import SwiftUI

/// Walks the user through creating a classic personal access token and explains,
/// in plain words, what it can do and where it is kept.
struct SignInView: View {
    private static let tokenCreationURL = URL(
        string: "https://github.com/settings/tokens/new"
            + "?scopes=notifications,repo,read:user"
            + "&description=GitHub%20Notifications%20for%20macOS",
    )!
    private static let tokenSettingsURL = URL(string: "https://github.com/settings/tokens")!

    let session: AppSession

    @State private var token = ""
    @State private var now = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connect your GitHub account")
                .font(.headline)

            steps

            scopeExplanation

            tokenField

            safetyNote

            if case let .failed(error) = session.auth.state {
                Text(error.userFacingMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { tick in
            now = tick
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 6) {
            Link("1. Create a token on GitHub", destination: Self.tokenCreationURL)
                .font(.callout)

            Text("The scopes below are pre-selected for you. If your organisation uses SAML single sign-on, "
                + "press Configure SSO on the token afterwards and authorise it. No admin approval is needed.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("2. Paste it here")
                .font(.callout)
        }
    }

    private var scopeExplanation: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(TokenScope.allCases.filter { $0 != .publicRepository }, id: \.self) { scope in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(scope.displayName)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)

                    Text(scope.purpose)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
    }

    private var tokenField: some View {
        HStack(spacing: 8) {
            SecureField("ghp_…", text: $token)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)

            Button("Sign in", action: submit)
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
                .help(submitHelpText)
        }
    }

    private var safetyNote: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your token is stored in the macOS keychain and is only ever sent to api.github.com.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Link("Review or revoke your tokens", destination: Self.tokenSettingsURL)
                .font(.caption)
        }
    }

    private var canSubmit: Bool {
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && session.auth.canAttemptSignIn
            && session.auth.state != .validating
    }

    private var submitHelpText: String {
        guard let allowedAt = session.auth.nextAttemptAllowedAt, allowedAt > now else {
            return "Validate this token with GitHub"
        }

        let secondsRemaining = Int(allowedAt.timeIntervalSince(now).rounded(.up))

        return "Waiting \(secondsRemaining)s before trying GitHub again"
    }

    private func submit() {
        Task {
            await session.signIn(withToken: token)

            if session.auth.isSignedIn {
                token = ""
            }
        }
    }
}
