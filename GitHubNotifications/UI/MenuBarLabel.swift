import AppKit
import Combine
import SwiftUI

/// The status item itself. It is rendered as soon as the app launches, unlike
/// the panel, so it also owns kicking off the session.
struct MenuBarLabel: View {
    private static let pulseInterval: TimeInterval = 5
    private static let frameInterval: Duration = .milliseconds(16)

    let session: AppSession

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openWindow) private var openWindow

    @State private var frameIndex = 0
    @State private var isReducingMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

    var body: some View {
        Image(nsImage: icon)
            .task { await session.start() }
            .onReceive(Timer.publish(every: Self.pulseInterval, on: .main, in: .common).autoconnect()) { _ in
                pulse()
            }
            .onReceive(
                NSWorkspace.shared.notificationCenter
                    .publisher(for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification),
            ) { _ in
                isReducingMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
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

    private var icon: NSImage {
        guard hasUnread, frameIndex > 0 else {
            return MenuBarIcon.make(hasUnread: hasUnread, isDarkMenuBar: colorScheme == .dark)
        }

        return MenuBarIcon.pulseFrames(isDarkMenuBar: colorScheme == .dark)[frameIndex]
    }

    /// A short swell of the badge every few seconds, so unread work keeps
    /// catching the eye without animating constantly. The frames are already
    /// drawn; this only steps an index through them.
    ///
    /// Reduce Motion turns it off rather than slowing it down: a looping
    /// attention animation is exactly what the setting is asking about.
    private func pulse() {
        guard hasUnread, !isReducingMotion else {
            return
        }

        Task {
            for index in 1 ..< MenuBarIcon.pulseFrameCount {
                frameIndex = index

                try? await Task.sleep(for: Self.frameInterval)
            }

            frameIndex = 0
        }
    }
}
