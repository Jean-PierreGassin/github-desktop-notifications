import SwiftUI

struct BehaviourSettingsView: View {
    private static let rowLimits = 1 ... 20

    let session: AppSession

    var body: some View {
        Form {
            notifications

            menuBar

            updates

            connection
        }
        .formStyle(.grouped)
        .font(.callout)
    }

    private var notifications: some View {
        Section {
            Toggle("Mark a notification as read when I open it", isOn: marksAsReadBinding)
        } header: {
            SettingsSectionHeader(title: "Notifications") { session.behaviourPreferences.resetToDefaults() }
        } footer: {
            Text("Opening a notification usually means you have dealt with it, but some people keep their inbox "
                + "as a to-do list.")
                .foregroundStyle(.secondary)
        }
    }

    private var menuBar: some View {
        Section {
            Toggle("Open at login", isOn: launchAtLoginBinding)

            LabeledContent("Notifications shown per repository") {
                HStack(spacing: 6) {
                    TextField("", value: rowsPerRepositoryBinding, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 52)
                        .multilineTextAlignment(.center)

                    Stepper("", value: rowsPerRepositoryBinding, in: Self.rowLimits)
                        .labelsHidden()
                }
            }
        } header: {
            SettingsSectionHeader(title: "Menu bar") { session.resetMenuBarPreferences() }
        } footer: {
            Text("Anything beyond the limit is summarised, with a link to your inbox on github.com.")
                .foregroundStyle(.secondary)
        }
    }

    /// The section the update controls land in. Until then it carries the one
    /// fact it can already answer, which is what you are running.
    private var updates: some View {
        Section("Updates") {
            LabeledContent("Version") {
                Text(AppVersion.current)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Nothing here is a preference, so there is nothing to reset. The token is
    /// reachable only by signing out, never displayed.
    private var connection: some View {
        Section {
            LabeledContent("Account") {
                Text(accountDescription)
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Checks GitHub every") {
                Text("\(Int(session.poller.pollInterval)) seconds")
                    .foregroundStyle(.secondary)
            }

            if session.auth.isSignedIn {
                LabeledContent("Session") {
                    Button("Sign out", action: session.signOut)
                        .appButton(.destructive, size: .small)
                }
            }
        } header: {
            Text("Connection")
        } footer: {
            Text("GitHub sets this interval and the app never asks more often. "
                + "Unchanged inboxes cost nothing against your rate limit.")
                .foregroundStyle(.secondary)
        }
    }

    private var accountDescription: String {
        guard case let .signedIn(user) = session.auth.state else {
            return "Not connected"
        }

        return user.account.login
    }

    private var marksAsReadBinding: Binding<Bool> {
        Binding(
            get: { session.behaviourPreferences.marksAsReadOnOpen },
            set: { session.behaviourPreferences.marksAsReadOnOpen = $0 },
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { session.launchAtLogin.isEnabled },
            set: { session.launchAtLogin.isEnabled = $0 },
        )
    }

    private var rowsPerRepositoryBinding: Binding<Int> {
        Binding(
            get: { session.rowsPerRepository },
            set: { session.rowsPerRepository = min(max($0, Self.rowLimits.lowerBound), Self.rowLimits.upperBound) },
        )
    }
}
