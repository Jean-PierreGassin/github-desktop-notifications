import SwiftUI

struct SettingsView: View {
    private static let windowSize = CGSize(width: 900, height: 700)

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
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        .task { await session.notifier.refreshAuthorizationStatus() }
        .onDisappear { SettingsWindowPresenter.returnToMenuBarOnly() }
    }

    /// Work Hours sits second because it modifies what Notifications sets up.
    /// Activity stays visible: it is how someone debugs their own setup.
    private var tabs: some View {
        TabView {
            NotificationSettingsView(session: session)
                .tabItem { Label("Notifications", systemImage: "bell") }

            WorkHoursView(session: session)
                .tabItem { Label("Work Hours", systemImage: "clock") }

            BehaviourSettingsView(session: session)
                .tabItem { Label("General", systemImage: "gearshape") }

            LogsView(log: session.log)
                .tabItem { Label("Activity", systemImage: "doc.plaintext") }
        }
    }
}
