import SwiftUI

struct RepositoryGroupView: View {
    let group: RepositoryGroup
    let onOpenThread: (NotificationThread) -> Void
    let onMarkThreadDone: (NotificationThread) -> Void
    let onOpenInbox: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            header

            ForEach(group.visibleThreads) { thread in
                NotificationRowView(
                    thread: thread,
                    onOpen: { onOpenThread(thread) },
                    onMarkDone: { onMarkThreadDone(thread) },
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
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(group.repository.fullName)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(group.repository.fullName)

            Spacer(minLength: 4)

            Text("\(group.threadCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 6)
    }

    private var overflowLink: some View {
        Button(action: onOpenInbox) {
            Text("\(group.hiddenThreadCount) more in this repo")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .help("Open your GitHub inbox to see the rest")
    }
}
