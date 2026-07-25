import AppKit
import Combine
import SwiftUI

/// Walks the user through creating a classic personal access token and states
/// plainly what it can do and where it is kept.
struct SignInView: View {
    private static let tokenCreationURL = URL(
        string: "https://github.com/settings/tokens/new"
            + "?scopes=notifications,repo,read:user"
            + "&default_expires_at=none"
            + "&description=GitHub%20Notifications%20for%20macOS",
    )!
    private static let tokenSettingsURL = URL(string: "https://github.com/settings/tokens")!

    private static let requiredScopes: [TokenScope] = [.notifications, .repository, .readUser]

    let session: AppSession

    @State private var token = ""
    @State private var now = Date()
    @State private var clipboardNotice: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connect your GitHub account")
                .font(.title3)
                .fontWeight(.semibold)

            createTokenStep

            scopeTable

            pasteTokenStep

            securityNote

            if case let .failed(error) = session.auth.state {
                Text(error.userFacingMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task { detectTokenOnClipboard() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { tick in
            now = tick
        }
    }

    private var createTokenStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                NSWorkspace.shared.open(Self.tokenCreationURL)
            } label: {
                Label("Create a token on GitHub", systemImage: "arrow.up.forward.square")
            }
            .buttonStyle(.bordered)

            classicTokenExplanation
        }
    }

    private var classicTokenExplanation: some View {
        (
            Text("This opens GitHub's ")
                + Text("classic").bold()
                + Text(" token page with the right scopes ticked. Fine-grained tokens cannot read your notification ")
                + Text("inbox, so they will not work here.")
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var scopeTable: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 8) {
            ForEach(Self.requiredScopes, id: \.self) { scope in
                GridRow {
                    Text(scope.displayName)
                        .font(.system(.callout, design: .monospaced))
                        .gridColumnAlignment(.leading)

                    Text(scope.purpose)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private var pasteTokenStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SecureField("Paste your token", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .onSubmit(submit)

                Button("Sign in", action: submit)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmit)
                    .help(submitHelpText)
            }

            if let clipboardNotice {
                Text(clipboardNotice)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            singleSignOnExplanation
        }
    }

    private var singleSignOnExplanation: some View {
        (
            Text("Organisations using SAML single sign-on need one extra step: choose Configure SSO on the token and ")
                + Text("authorise it yourself. ")
                + Text("No organisation admin has to approve it.").bold()
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var securityNote: some View {
        InfoBubble(symbolName: "lock.shield") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your token is stored in the macOS keychain and is only ever sent to api.github.com.")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    NSWorkspace.shared.open(Self.tokenSettingsURL)
                } label: {
                    Label("Review or revoke tokens", systemImage: "arrow.up.forward.square")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var canSubmit: Bool {
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && session.auth.canAttemptSignIn
            && session.auth.state != .validating
    }

    private var submitHelpText: String {
        guard let allowedAt = session.auth.nextAttemptAllowedAt, allowedAt > now else {
            return "Check this token with GitHub"
        }

        let secondsRemaining = Int(allowedAt.timeIntervalSince(now).rounded(.up))

        return "Waiting \(secondsRemaining)s before contacting GitHub again"
    }

    /// Saves a paste when a token is already on the clipboard, and explains the
    /// problem when the clipboard holds a token GitHub will reject.
    private func detectTokenOnClipboard() {
        guard token.isEmpty, let candidate = NSPasteboard.general.string(forType: .string) else {
            return
        }

        switch TokenFormat.classify(candidate) {
        case .classic:
            token = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            clipboardNotice = "Filled in from your clipboard."
        case .fineGrained:
            clipboardNotice = "The token on your clipboard is fine-grained. GitHub only allows classic tokens to read "
                + "notifications."
        case .unrecognised:
            clipboardNotice = nil
        }
    }

    private func submit() {
        Task {
            await session.signIn(withToken: token)

            if session.auth.isSignedIn {
                token = ""
                clipboardNotice = nil
            }
        }
    }
}
