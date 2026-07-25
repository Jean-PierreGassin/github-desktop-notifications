import SwiftUI

struct RepositoryGroupView: View {
    let group: RepositoryGroup
    let onOpenThread: (NotificationThread) -> Void
    let onMarkThreadRead: (NotificationThread) -> Void
    let onDismissThread: (NotificationThread) -> Void
    let onOpenInbox: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            header

            ForEach(group.visibleThreads) { thread in
                NotificationRowView(
                    thread: thread,
                    onOpen: { onOpenThread(thread) },
                    onMarkRead: { onMarkThreadRead(thread) },
                    onDismiss: { onDismissThread(thread) },
                )
            }

            if group.hiddenThreadCount > 0 {
                overflowLink
            }
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            if group.repository.isPrivate {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(group.repository.fullName)
                .font(.callout)
                .fontWeight(.semibold)
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
