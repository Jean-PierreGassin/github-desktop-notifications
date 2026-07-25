import Combine
import SwiftUI

/// The status item itself. It is rendered as soon as the app launches, unlike
/// the panel, so it also owns kicking off the session.
struct MenuBarLabel: View {
    private static let pulseInterval: TimeInterval = 5
    private static let pulseDuration: Duration = .milliseconds(400)

    let session: AppSession

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openWindow) private var openWindow

    @State private var isPulsing = false

    var body: some View {
        Image(nsImage: MenuBarIcon.make(
            hasUnread: hasUnread,
            isDarkMenuBar: colorScheme == .dark,
            isPulsing: isPulsing && hasUnread,
        ))
        .task { await session.start() }
        .onReceive(Timer.publish(every: Self.pulseInterval, on: .main, in: .common).autoconnect()) { _ in
            pulse()
        }
        // The first-run question is a sheet on Settings, so the window has to be
        // brought up behind it. The status item is the only view alive at launch.
        .onChange(of: session.isAskingForClickBehaviour) { _, isAsking in
            guard isAsking else {
                return
            }

            SettingsWindowPresenter.prepareForDisplay()
            openWindow(id: GitHubNotificationsApp.settingsWindowIdentifier)
        }
    }

    private var hasUnread: Bool {
        session.store.unreadCount > 0
    }

    /// A short swell of the badge every few seconds, so unread work keeps
    /// catching the eye without animating constantly.
    private func pulse() {
        guard hasUnread else {
            return
        }

        isPulsing = true

        Task {
            try? await Task.sleep(for: Self.pulseDuration)
            isPulsing = false
        }
    }
}
