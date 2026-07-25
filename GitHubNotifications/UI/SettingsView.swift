import SwiftUI

struct SettingsView: View {
    let session: AppSession

    var body: some View {
        VStack(spacing: 0) {
            if session.notifier.needsPermission {
                WarningBanner(
                    message: session.notifier.permissionMessage,
                    actionTitle: session.notifier.permissionActionTitle,
                    action: { Task { await session.notifier.resolvePermission() } },
                    symbolName: "bell.slash.fill",
                )
                .padding([.horizontal, .top], 16)
            }

            tabs
        }
        .frame(width: 900, height: 700)
        .task { await session.notifier.refreshAuthorizationStatus() }
        .onDisappear { SettingsWindowPresenter.returnToMenuBarOnly() }
    }

    private var tabs: some View {
        TabView {
            NotificationSettingsView(session: session)
                .tabItem { Label("Notifications", systemImage: "bell") }

            BehaviourSettingsView(session: session)
                .tabItem { Label("General", systemImage: "gearshape") }

            LogsView(log: session.log)
                .tabItem { Label("Activity", systemImage: "doc.plaintext") }
        }
    }
}

struct BehaviourSettingsView: View {
    let session: AppSession

    var body: some View {
        Form {
            Section {
                Toggle("Open at login", isOn: launchAtLoginBinding)

                Toggle("Mark a notification as read when I open it", isOn: marksAsReadBinding)

                LabeledContent("Notifications shown per repository") {
                    HStack(spacing: 6) {
                        TextField("", value: rowsPerRepositoryBinding, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 52)
                            .multilineTextAlignment(.center)

                        Stepper("", value: rowsPerRepositoryBinding, in: 1 ... 20)
                            .labelsHidden()
                    }
                }
            } header: {
                Text("Menu bar")
            } footer: {
                Text("Anything beyond the limit is summarised, with a link to your inbox on github.com.")
                    .foregroundStyle(.secondary)
            }

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
        .formStyle(.grouped)
        .font(.callout)
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
            set: { session.rowsPerRepository = min(max($0, 1), 20) },
        )
    }
}
