import AppKit
import SwiftUI

struct NotificationRowView: View {
    let thread: NotificationThread
    let onOpen: () -> Void
    let onMarkRead: () -> Void
    let onDismiss: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: onOpen) {
                rowContent
            }
            .buttonStyle(.plain)

            if isHovering {
                actions
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            isHovering ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
            in: RoundedRectangle(cornerRadius: 5),
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .help(hoverDescription)
        .contextMenu {
            Button("Open in browser", action: onOpen)

            Button("Copy link") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(ThreadURL.derive(for: thread).absoluteString, forType: .string)
            }

            Button("Mark as read", action: onMarkRead)

            Button("Dismiss", action: onDismiss)
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: thread.reason.symbolName)
                .font(.callout)
                .foregroundStyle(thread.reason.priorityRank == 0 ? .primary : .secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(thread.reason.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(thread.subject.title)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 4)

            if thread.isUnread {
                Circle()
                    .fill(.tint)
                    .frame(width: 7, height: 7)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// Opening is the row itself, so these are the two things you cannot do by
    /// clicking through.
    private var actions: some View {
        HStack(spacing: 6) {
            Button("Mark read", action: onMarkRead)
                .appButton(.standard, size: .small)
                .help("Clear it from here without opening it")

            Button("Dismiss", action: onDismiss)
                .appButton(.standard, size: .small)
                .help("Mark it done on GitHub so it leaves your inbox everywhere")

            Spacer(minLength: 0)
        }
        .padding(.leading, 24)
    }

    /// The row truncates, so the tooltip carries everything in full.
    private var hoverDescription: String {
        let updatedDescription = thread.updatedAt.formatted(date: .abbreviated, time: .shortened)
        let visibility = thread.repository.isPrivate ? " (private)" : ""

        return """
        \(thread.repository.fullName)\(visibility)
        \(thread.reason.displayName)

        \(thread.subject.title)

        Updated \(updatedDescription)
        """
    }
}
