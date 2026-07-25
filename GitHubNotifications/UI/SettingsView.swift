import SwiftUI

struct SettingsView: View {
    private enum Tab: Hashable {
        case notifications
        case workHours
        case general
        case activity
    }

    private static let windowSize = CGSize(width: 900, height: 700)

    let session: AppSession

    @State private var selectedTab = Tab.notifications

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
        .sheet(isPresented: promptBinding) {
            ClickBehaviourPromptView(session: session)
        }
        .onChange(of: session.highlightedSettingsField == nil) { _, _ in
            guard session.highlightedSettingsField != nil else {
                return
            }

            selectedTab = .notifications
        }
    }

    /// Work Hours sits second because it modifies what Notifications sets up.
    /// Activity stays visible: it is how someone debugs their own setup.
    private var tabs: some View {
        TabView(selection: $selectedTab) {
            NotificationSettingsView(session: session)
                .tabItem { Label("Notifications", systemImage: "bell") }
                .tag(Tab.notifications)

            WorkHoursView(session: session)
                .tabItem { Label("Work Hours", systemImage: "clock") }
                .tag(Tab.workHours)

            BehaviourSettingsView(session: session)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(Tab.general)

            LogsView(log: session.log)
                .tabItem { Label("Activity", systemImage: "doc.plaintext") }
                .tag(Tab.activity)
        }
    }

    /// Closing the sheet any other way than Continue keeps the current choice,
    /// which the session treats as answered.
    private var promptBinding: Binding<Bool> {
        Binding(
            get: { session.isAskingForClickBehaviour },
            set: { isPresented in
                guard !isPresented else {
                    return
                }

                session.dismissClickBehaviourPrompt()
            },
        )
    }
}
