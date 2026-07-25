import Combine
import SwiftUI

struct InboxPanel: View {
    private static let panelWidth: CGFloat = 410

    /// The panel is a popover, not a window: past about three quarters of the
    /// screen it stops growing and scrolls instead of running off the display.
    private static let maximumScreenFraction: CGFloat = 0.75
    private static let fallbackMaximumHeight: CGFloat = 700
    private static let overflowFadeHeight: CGFloat = 24

    let session: AppSession

    @Environment(\.openWindow) private var openWindow

    @State private var now = Date()
    @State private var isConfirmingBulkAction = false
    @State private var listHeight: CGFloat = 0

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

            if session.poller.lastError != nil {
                // The only signal left that polling is unhealthy, now that there
                // is no refresh button to press, so it carries the resume time.
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(pollingProblemDescription)
            }

            Button(action: openSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
    }

    private var pollingProblemDescription: String {
        guard let error = session.poller.lastError else {
            return ""
        }

        return "\(error.userFacingMessage)\n\nTrying again \(nextCheckDescription)."
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

    /// Every repository is listed. Below the height cap the panel sizes to its
    /// contents exactly as before, so the list is not in a scroll view at all;
    /// past the cap it moves into one at a definite height.
    ///
    /// The order matters. A scroll view given no definite height inside a menu
    /// bar window collapses and shows nothing, so the measurement has to come
    /// from the plain list rather than from inside the scroll view.
    @ViewBuilder
    private var notificationList: some View {
        if listHeight > Self.maximumListHeight {
            ScrollView {
                groupList
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: Self.maximumListHeight)
            .overlay(alignment: .bottom) { overflowFade }
        } else {
            groupList
        }
    }

    private var groupList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(session.store.groups.enumerated()), id: \.element.id) { index, group in
                RepositoryGroupView(
                    group: group,
                    clickBehaviour: session.behaviourPreferences.clickBehaviour,
                    avatars: session.avatars,
                    showsDivider: index > 0,
                    onOpenThread: session.open,
                    onApplyToThread: { behaviour, thread in
                        Task { await session.apply(behaviour, to: thread) }
                    },
                    onOpenInbox: session.openInbox,
                )
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.height } action: { height in
            listHeight = height
        }
    }

    /// Roughly three quarters of the screen the panel is on, so a long inbox
    /// still leaves the desktop visible.
    private static var maximumListHeight: CGFloat {
        guard let visibleHeight = NSScreen.main?.visibleFrame.height else {
            return fallbackMaximumHeight
        }

        return visibleHeight * maximumScreenFraction
    }

    /// An overlay scroll bar only appears once you are already scrolling, which
    /// is no use as a sign that there is more below.
    private var overflowFade: some View {
        LinearGradient(
            colors: [.clear, Color(nsColor: .windowBackgroundColor)],
            startPoint: .top,
            endPoint: .bottom,
        )
        .frame(height: Self.overflowFadeHeight)
        .allowsHitTesting(false)
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

            Divider()

            UpdateStatusView(session: session)
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

    /// What happens next rather than what happened last: with no refresh button
    /// to press, when the next check lands is the only thing worth saying.
    private var statusSummary: String {
        let unreadCount = session.store.unreadCount
        let unreadSummary = unreadCount == 1 ? "1 unread" : "\(unreadCount) unread"

        return "\(unreadSummary) · \(nextCheckDescription)"
    }

    private var nextCheckDescription: String {
        guard !session.poller.isFetching else {
            return "checking now"
        }

        let secondsRemaining = Int(session.poller.nextPollDueAt.timeIntervalSince(now).rounded(.up))

        guard secondsRemaining > 0 else {
            return "checking shortly"
        }

        guard session.poller.lastError == nil else {
            return "paused, next check in \(secondsRemaining)s"
        }

        return "next check in \(secondsRemaining)s"
    }

    private func openSettings() {
        SettingsWindowPresenter.prepareForDisplay()
        openWindow(id: GitHubNotificationsApp.settingsWindowIdentifier)
    }
}
