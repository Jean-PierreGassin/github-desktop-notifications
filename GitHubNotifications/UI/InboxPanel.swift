import Combine
import SwiftUI

struct InboxPanel: View {
    private static let panelWidth: CGFloat = 410

    let session: AppSession

    @Environment(\.openWindow) private var openWindow

    @State private var now = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Divider()

            if session.notifier.needsPermission {
                notificationsBlockedWarning
            }

            content

            Divider()

            footer
        }
        .padding(14)
        .frame(width: Self.panelWidth)
        .task { await session.notifier.refreshAuthorizationStatus() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { tick in
            now = tick
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            GitHubMarkView(hasUnread: false, size: 18)

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

            Button(action: openSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
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
            return "Checking GitHub"
        }

        guard !session.poller.canRefreshNow else {
            return "Check GitHub now"
        }

        let secondsRemaining = Int(session.poller.nextPollDueAt.timeIntervalSince(now).rounded(.up))

        return "GitHub sets the pace here. Next check in \(max(secondsRemaining, 0))s."
    }

    private var notificationsBlockedWarning: some View {
        WarningBanner(
            message: session.notifier.permissionMessage,
            actionTitle: session.notifier.permissionActionTitle,
            action: { Task { await session.notifier.resolvePermission() } },
            symbolName: "bell.slash.fill",
        )
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

                Text("Checking your token with GitHub")
                    .font(.body)
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
                "This token has no repo scope, so private and organisation notifications are hidden.",
                systemImage: "exclamationmark.triangle",
            )
            .font(.callout)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
        }

        if session.store.hasNotifications {
            notificationList
        } else {
            emptyState
        }
    }

    /// The panel grows with its contents rather than scrolling, so the list is
    /// bounded by repository as well as by row.
    private var notificationList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(session.store.visibleGroups) { group in
                RepositoryGroupView(
                    group: group,
                    onOpenThread: session.open,
                    onMarkThreadRead: { thread in Task { await session.markAsRead(thread) } },
                    onDismissThread: { thread in Task { await session.markAsDone(thread) } },
                    onOpenInbox: session.openInbox,
                )
            }

            if session.store.hiddenRepositoryCount > 0 {
                Button(action: session.openInbox) {
                    Text("\(session.store.hiddenRepositoryCount) more repositories")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.plain)
                .help("Open your inbox on github.com to see the rest")
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.secondary)

            Text(session.poller.lastSuccessAt == nil ? "Checking your inbox" : "Nothing needs you right now.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if session.auth.isSignedIn {
                Text(statusSummary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                if session.auth.isSignedIn, session.store.hasNotifications {
                    Button("Mark all read") {
                        Task { await session.markEverythingAsRead() }
                    }
                    .appButton(.standard)
                }

                Spacer(minLength: 0)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .appButton(.destructive)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func openSettings() {
        SettingsWindowPresenter.prepareForDisplay()
        openWindow(id: GitHubNotificationsApp.settingsWindowIdentifier)
    }
}
