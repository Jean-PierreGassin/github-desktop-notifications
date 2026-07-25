import Combine
import SwiftUI

/// The status item itself. It is rendered as soon as the app launches, unlike
/// the panel, so it also owns kicking off the session.
struct MenuBarLabel: View {
    private static let pulseInterval: TimeInterval = 5
    private static let pulseDuration: Duration = .milliseconds(400)

    let session: AppSession

    @Environment(\.colorScheme) private var colorScheme

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
