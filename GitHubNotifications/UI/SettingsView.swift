import SwiftUI

struct SettingsView: View {
    let session: AppSession

    var body: some View {
        TabView {
            alertsTab
                .tabItem { Label("Notifications", systemImage: "bell") }

            behaviourTab
                .tabItem { Label("Behaviour", systemImage: "gearshape") }

            LogsView(log: session.log)
                .tabItem { Label("Logs", systemImage: "doc.plaintext") }
        }
        .frame(width: 460, height: 420)
    }

    private var alertsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Everything shows in the menu bar panel. These switches decide what also raises a macOS alert.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(NotificationGroup.allCases, id: \.self) { group in
                    groupSection(for: group)
                }
            }
            .padding(16)
        }
    }

    private func groupSection(for group: NotificationGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: groupBinding(for: group)) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(group.displayName)
                        .fontWeight(.medium)

                    Text(group.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)

            DisclosureGroup("Individual types") {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(session.alertPreferences.reasons(in: group), id: \.self) { reason in
                        Toggle(reason.displayName, isOn: reasonBinding(for: reason))
                            .toggleStyle(.checkbox)
                    }
                }
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.caption)
            .padding(.leading, 4)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    private var behaviourTab: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: launchAtLoginBinding)

                Stepper(
                    "Show up to \(session.rowsPerRepository) notifications per repository",
                    value: rowsPerRepositoryBinding,
                    in: 1 ... 20,
                )
            }

            Section {
                LabeledContent("Signed in as") {
                    Text(signedInDescription)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Checks GitHub every") {
                    Text("\(Int(session.poller.pollInterval))s")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("GitHub sets the polling interval. The app never checks more often than it asks for.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var signedInDescription: String {
        guard case let .signedIn(user) = session.auth.state else {
            return "Not signed in"
        }

        return user.account.login
    }

    private func groupBinding(for group: NotificationGroup) -> Binding<Bool> {
        Binding(
            get: { session.alertPreferences.isFullyEnabled(group) },
            set: { session.alertPreferences.setEnabled($0, forGroup: group) },
        )
    }

    private func reasonBinding(for reason: NotificationReason) -> Binding<Bool> {
        Binding(
            get: { session.alertPreferences.isEnabled(reason) },
            set: { session.alertPreferences.setEnabled($0, for: reason) },
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
            set: { session.rowsPerRepository = $0 },
        )
    }
}
