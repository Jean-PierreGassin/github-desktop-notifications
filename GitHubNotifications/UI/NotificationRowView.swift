import AppKit
import SwiftUI

struct NotificationRowView: View {
    let thread: NotificationThread
    let onOpen: () -> Void
    let onMarkDone: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: thread.reason.symbolName)
                    .font(.caption)
                    .foregroundStyle(thread.reason.priorityRank == 0 ? .primary : .secondary)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 1) {
                    Text(thread.reason.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(thread.subject.title)
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 4)

                if thread.isUnread {
                    Circle()
                        .fill(.tint)
                        .frame(width: 6, height: 6)
                        .padding(.top, 5)
                }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isHovering ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                in: RoundedRectangle(cornerRadius: 5),
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(thread.subject.title)
        .contextMenu {
            Button("Open in browser", action: onOpen)

            Button("Copy link") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(ThreadURL.derive(for: thread).absoluteString, forType: .string)
            }

            Button("Mark as done", action: onMarkDone)
        }
    }
}
