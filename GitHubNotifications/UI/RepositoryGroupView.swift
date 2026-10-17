import SwiftUI

struct RepositoryGroupView: View {
    private static let avatarSide: CGFloat = 16

    /// Long enough to read as the row leaving rather than blinking out, short
    /// enough that dismissing several in a row never feels queued.
    static let removalDuration: TimeInterval = 0.22

    private static let rowSpacing: CGFloat = 2

    /// A sliver of the next row shows below the last whole one, so a repository
    /// that scrolls looks like it does.
    private static let nextRowPeek: CGFloat = 14

    let group: RepositoryGroup
    let latestUpdates: [String: ThreadUpdate]
    let clickBehaviour: ClickBehaviour
    let rowsBeforeScrolling: Int
    let avatars: AvatarCache
    let subjectStatuses: SubjectStatusCache
    let activities: ThreadActivityCache
    let showsDivider: Bool
    let onOpenThread: (NotificationThread) -> Void
    let onApplyToThread: (ClickBehaviour, NotificationThread) -> Void
    let onOpenInbox: () -> Void

    @State private var rowHeights: [String: CGFloat] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: Self.rowSpacing) {
            if showsDivider {
                Divider()
                    .padding(.bottom, 4)
            }

            header

            rows

            if group.hiddenThreadCount > 0 {
                overflowLink
            }
        }
        .animation(.easeInOut(duration: Self.removalDuration), value: group.visibleThreads.map(\.id))
    }

    /// A repository with more rows than the limit scrolls on its own, so older
    /// notifications are a scroll away rather than hidden until the newer ones
    /// are dismissed.
    ///
    /// A scroll view needs a definite height inside a menu bar window or it
    /// collapses, so the rows are measured first, in a plain stack, and the
    /// scroll view is sized to the first few of them.
    @ViewBuilder
    private var rows: some View {
        if let viewportHeight {
            ScrollView {
                rowStack
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: viewportHeight)
            .overlay(alignment: .bottom) { OverflowFade(height: 16) }
        } else {
            rowStack
        }
    }

    private var rowStack: some View {
        VStack(alignment: .leading, spacing: Self.rowSpacing) {
            ForEach(group.visibleThreads) { thread in
                NotificationRowView(
                    thread: thread,
                    update: latestUpdates[thread.id],
                    status: subjectStatuses.status(for: thread),
                    activity: activities.activity(for: thread),
                    clickBehaviour: clickBehaviour,
                    onOpen: { onOpenThread(thread) },
                    onApply: { behaviour in onApplyToThread(behaviour, thread) },
                )
                // The smallest height seen is the row at rest. A hovered row grows
                // to show its button, and sizing the scroll box from that would
                // make the whole panel jump on every hover.
                .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.height } action: { height in
                    rowHeights[thread.id] = min(height, rowHeights[thread.id] ?? height)
                }
                .transition(Self.rowTransition)
            }
        }
    }

    /// The height of the rows that fit before scrolling, or nothing while the
    /// repository fits whole or its rows have not been measured yet.
    private var viewportHeight: CGFloat? {
        let leadingRows = group.visibleThreads.prefix(max(rowsBeforeScrolling, 1))

        guard group.visibleThreads.count > leadingRows.count else {
            return nil
        }

        let leadingHeights = leadingRows.compactMap { rowHeights[$0.id] }

        guard leadingHeights.count == leadingRows.count else {
            return nil
        }

        return leadingHeights.reduce(0, +) + Self.rowSpacing * CGFloat(leadingHeights.count) + Self.nextRowPeek
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
