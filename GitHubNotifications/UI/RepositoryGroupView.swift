import SwiftUI

struct RepositoryGroupView: View {
    private static let avatarSide: CGFloat = 16

    /// Long enough to read as the row leaving rather than blinking out, short
    /// enough that dismissing several in a row never feels queued.
    static let removalDuration: TimeInterval = 0.22

    let group: RepositoryGroup
    let latestUpdates: [String: ThreadUpdate]
    let clickBehaviour: ClickBehaviour
    let avatars: AvatarCache
    let subjectStatuses: SubjectStatusCache
    let showsDivider: Bool
    let onOpenThread: (NotificationThread) -> Void
    let onApplyToThread: (ClickBehaviour, NotificationThread) -> Void
    let onOpenInbox: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if showsDivider {
                Divider()
                    .padding(.bottom, 4)
            }

            header

            ForEach(group.visibleThreads) { thread in
                NotificationRowView(
                    thread: thread,
                    update: latestUpdates[thread.id],
                    status: subjectStatuses.status(for: thread),
                    clickBehaviour: clickBehaviour,
                    onOpen: { onOpenThread(thread) },
                    onApply: { behaviour in onApplyToThread(behaviour, thread) },
                )
                .transition(Self.rowTransition)
            }

            if group.hiddenThreadCount > 0 {
                overflowLink
            }
        }
        .animation(.easeInOut(duration: Self.removalDuration), value: group.visibleThreads.map(\.id))
    }

    /// Dismissing a row is the one thing in the panel that removes something the
    /// user is looking at, so it leaves the way it would on paper: it fades and
    /// slides off, and the rows below close the gap rather than jumping into it.
    ///
    /// Arriving is deliberately plainer. A row appearing during a poll is not an
    /// action the user just took, and sliding it in would draw the eye to
    /// something nobody asked to see move.
    private static let rowTransition: AnyTransition = .asymmetric(
        insertion: .opacity,
        removal: .opacity.combined(with: .move(edge: .leading)),
    )

    private var header: some View {
        HStack(spacing: 6) {
            avatar

            if group.repository.isPrivate {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(group.repository.fullName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(group.repository.fullName)

            Spacer(minLength: 4)

            Text("\(group.threadCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 6)
    }

    /// An avatar that has not arrived leaves its space rather than shifting the
    /// name when it does, and a fetch that never succeeds costs nothing.
    @ViewBuilder
    private var avatar: some View {
        if let image = avatars.image(for: group.repository.owner) {
            Image(nsImage: image)
                .resizable()
                .frame(width: Self.avatarSide, height: Self.avatarSide)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary)
                .frame(width: Self.avatarSide, height: Self.avatarSide)
        }
    }

    private var overflowLink: some View {
        Button(action: onOpenInbox) {
            Text("\(group.hiddenThreadCount) more in this repository")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .help("Open your inbox on github.com to see the rest")
    }
}
