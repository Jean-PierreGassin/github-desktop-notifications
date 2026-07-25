import Combine
import SwiftUI

struct InboxPanel: View {
    private static let panelWidth: CGFloat = 410

    let session: AppSession

    @Environment(\.openWindow) private var openWindow

    @State private var now = Date()
    @State private var isConfirmingBulkAction = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Divider()

            if session.notifier.needsPermission {
                notificationsBlockedWarning
            }

            if let failure = session.lastActionFailure {
                WarningBanner(
                    message: failure,
                    actionTitle: "Dismiss",
                    action: session.dismissFailure,
                )
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
                    clickBehaviour: session.behaviourPreferences.clickBehaviour,
                    onOpenThread: session.open,
                    onApplyToThread: { behaviour, thread in
                        Task { await session.apply(behaviour, to: thread) }
                    },
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
                Text(session.bulkProgress ?? statusSummary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                if session.auth.isSignedIn, session.store.hasNotifications {
                    bulkButton
                }

                Spacer(minLength: 0)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .appButton(.standard)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The bulk action follows the click setting, so it is labelled with it.
    /// Dismissing is destructive on every device and cannot be undone from here,
    /// which is what earns both the confirmation and the red.
    private var bulkButton: some View {
        let behaviour = session.behaviourPreferences.clickBehaviour

        return Button(behaviour.bulkActionTitle) {
            guard behaviour.needsBulkConfirmation else {
                Task { await session.applyToEverything(behaviour) }
                return
            }

            isConfirmingBulkAction = true
        }
        .appButton(behaviour.needsBulkConfirmation ? .destructive : .standard)
        .disabled(session.bulkProgress != nil)
        .confirmationDialog(
            "\(behaviour.bulkActionTitle)?",
            isPresented: $isConfirmingBulkAction,
        ) {
            Button(behaviour.bulkActionTitle, role: .destructive) {
                Task { await session.applyToEverything(behaviour) }
            }
        } message: {
            Text("This clears \(session.store.threads.count) notifications from GitHub on every device, "
                + "and cannot be undone from here.")
        }
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
