import Combine
import SwiftUI

struct InboxPanel: View {
    private static let panelWidth: CGFloat = 340
    private static let tallestListHeight: CGFloat = 420

    let session: AppSession

    @Environment(\.openWindow) private var openWindow

    @State private var now = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            Divider()

            if session.notifier.isBlockedBySystemSettings {
                notificationsBlockedWarning
            }

            content

            Divider()

            footer
        }
        .padding(12)
        .frame(width: Self.panelWidth)
        .task { await session.notifier.refreshAuthorizationStatus() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { tick in
            now = tick
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            GitHubMarkView(hasUnread: false)
                .frame(width: 16, height: 16)

            Text("GitHub Notifications")
                .font(.headline)

            Spacer()

            if let error = session.poller.lastError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(error.userFacingMessage)
            }

            if session.auth.isSignedIn {
                refreshButton
            }

            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
    }

    private func openSettings() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindow(id: GitHubNotificationsApp.settingsWindowIdentifier)
    }

    private var refreshButton: some View {
        Button {
            Task { await session.poller.refreshNow() }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .buttonStyle(.plain)
        .disabled(!session.poller.canRefreshNow)
        .foregroundStyle(session.poller.canRefreshNow ? .primary : .tertiary)
        .help(refreshHelpText)
    }

    private var refreshHelpText: String {
        guard !session.poller.isFetching else {
            return "Checking GitHub…"
        }

        guard !session.poller.canRefreshNow else {
            return "Check GitHub now"
        }

        let secondsRemaining = Int(session.poller.nextPollDueAt.timeIntervalSince(now).rounded(.up))

        return "GitHub asks us to wait. Next check in \(max(secondsRemaining, 0))s."
    }

    private var notificationsBlockedWarning: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Notifications are turned off for this app.", systemImage: "bell.slash")
                .font(.caption)
                .foregroundStyle(.orange)

            Button("Open notification settings") {
                session.notifier.openSystemNotificationSettings()
            }
            .buttonStyle(.link)
            .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        switch session.auth.state {
        case .signedOut, .failed:
            SignInView(session: session)
        case .validating:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)

                Text("Checking your token with GitHub…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        case let .signedIn(user):
            signedInContent(for: user)
        }
    }

    @ViewBuilder
    private func signedInContent(for user: AuthenticatedUser) -> some View {
        if !user.canSeePrivateRepositories {
            Label(
                "Your token has no repo scope, so private and organisation notifications won't appear.",
                systemImage: "exclamationmark.triangle",
            )
            .font(.caption)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
        }

        if session.store.hasNotifications {
            notificationList
        } else {
            emptyState
        }
    }

    private var notificationList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(session.store.groups) { group in
                    RepositoryGroupView(
                        group: group,
                        onOpenThread: session.open,
                        onMarkThreadDone: { thread in Task { await session.markAsDone(thread) } },
                        onOpenInbox: session.openInbox,
                    )
                }
            }
        }
        .frame(maxHeight: Self.tallestListHeight)
    }

    private var emptyState: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.secondary)

            Text(session.poller.lastSuccessAt == nil ? "Checking your inbox…" : "You're all caught up.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if session.auth.isSignedIn {
                Text(statusSummary)
                    .foregroundStyle(.secondary)

                Spacer()

                if session.store.hasNotifications {
                    Button("Mark all read") {
                        Task { await session.markEverythingAsRead() }
                    }
                    .buttonStyle(.link)
                }

                Button("Sign out", action: session.signOut)
                    .buttonStyle(.link)
            } else {
                Spacer()
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.link)
        }
        .font(.caption)
    }

    private var statusSummary: String {
        let unreadCount = session.store.unreadCount
        let unreadSummary = unreadCount == 1 ? "1 unread" : "\(unreadCount) unread"

        guard let lastSuccessAt = session.poller.lastSuccessAt else {
            return unreadSummary
        }

        let secondsAgo = Int(now.timeIntervalSince(lastSuccessAt))

        return "\(unreadSummary) · checked \(secondsAgo)s ago"
    }
}
