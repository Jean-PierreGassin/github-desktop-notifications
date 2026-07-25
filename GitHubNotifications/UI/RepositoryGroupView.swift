import SwiftUI

struct RepositoryGroupView: View {
    private static let avatarSide: CGFloat = 16

    let group: RepositoryGroup
    let clickBehaviour: ClickBehaviour
    let avatars: AvatarCache
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
                    clickBehaviour: clickBehaviour,
                    onOpen: { onOpenThread(thread) },
                    onApply: { behaviour in onApplyToThread(behaviour, thread) },
                )
            }

            if group.hiddenThreadCount > 0 {
                overflowLink
            }
        }
    }

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
