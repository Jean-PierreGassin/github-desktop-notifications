import SwiftUI

/// The status item itself. It is rendered as soon as the app launches, unlike
/// the panel, so it also owns kicking off the session.
struct MenuBarLabel: View {
    let session: AppSession

    var body: some View {
        GitHubMarkView(hasUnread: session.store.unreadCount > 0)
            .task { await session.start() }
    }
}
