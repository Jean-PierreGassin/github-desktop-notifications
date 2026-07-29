import AppKit
import SwiftUI

struct NotificationRowView: View {
    /// Every row icon occupies the same box, so a light glyph and a heavy one
    /// still start at the same place.
    private static let iconSide: CGFloat = 18
    private static let unreadDotSide: CGFloat = 7

    let thread: NotificationThread
    let update: ThreadUpdate?
    let status: SubjectStatus?
    let clickBehaviour: ClickBehaviour
    let onOpen: () -> Void
    let onApply: (ClickBehaviour) -> Void

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

            Divider()

            // Everything still applicable stays reachable here, so doing
            // something once never means changing the setting and changing it
            // back. A row already read has nothing left but dismissing.
            ForEach(applicableBehaviours, id: \.self) { behaviour in
                Button(behaviour.actionTitle) { onApply(behaviour) }
            }
        }
    }

    private var applicableBehaviours: [ClickBehaviour] {
        thread.isUnread ? ClickBehaviour.allCases : [.dismissed]
    }

    /// A read row cannot be marked read again, so its button says the one thing
    /// left to do with it rather than repeating the setting.
    private var rowBehaviour: ClickBehaviour {
        thread.isUnread ? clickBehaviour : .dismissed
    }

    /// Title first, and everything on the title's first baseline: the icon, the
    /// text and the dot all measured from one line rather than three.
    private var rowContent: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: thread.reason.symbolName)
                .imageScale(.medium)
                .foregroundStyle(thread.reason.priorityRank == 0 ? .primary : .secondary)
                .frame(width: Self.iconSide, height: Self.iconSide)
                .alignmentGuide(.firstTextBaseline) { dimensions in dimensions[VerticalAlignment.center] + 4 }

            VStack(alignment: .leading, spacing: 1) {
                Text(thread.subject.title)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 4)

            if let status, status.isWorthShowing {
                Image(systemName: status.symbolName)
                    .imageScale(.small)
                    .foregroundStyle(statusTint(for: status))
                    .help(status.displayName)
                    .alignmentGuide(.firstTextBaseline) { dimensions in dimensions[VerticalAlignment.center] + 2 }
                    .transition(.opacity)
            }

            if thread.isUnread {
                Circle()
                    .fill(.tint)
                    .frame(width: Self.unreadDotSide, height: Self.unreadDotSide)
                    .alignmentGuide(.firstTextBaseline) { dimensions in dimensions[VerticalAlignment.center] + 2 }
            }
        }
        .animation(.easeOut(duration: 0.2), value: status)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// One button, carrying whatever a click would do, so the button and the row
    /// can never disagree. The rest of the actions live in the context menu.
    private var actions: some View {
        HStack(spacing: 6) {
            Spacer(minLength: 0)

            Button(rowBehaviour.actionTitle) { onApply(rowBehaviour) }
                .appButton(.standard, size: .small)
                .help("Does this without opening it. \(rowBehaviour.explanation)")
        }
    }

    /// GitHub's own colours, because they are the ones people already read
    /// without being told: purple once it is merged, red once it is closed. A
    /// draft is not an outcome, so it stays as quiet as the caption beside it.
    private func statusTint(for status: SubjectStatus) -> AnyShapeStyle {
        switch status {
        case .merged: AnyShapeStyle(.purple)
        case .closed: AnyShapeStyle(.red)
        case .open, .draft: AnyShapeStyle(.secondary)
        }
    }

    /// Why the thread is in the inbox, and what last happened in it. The reason
    /// alone stops saying anything once a thread has been running a while: every
    /// comment and review on a pull request you were asked to review is still a
    /// review request, and a row reading the same as it did yesterday is a row
    /// worth ignoring.
    ///
    /// Built by ``ThreadUpdate/caption(for:)``, which is what the alert for this
    /// thread is worded from as well. A row and the banner that sent the user to
    /// it disagreeing about what happened is worse than either being terse.
    private var caption: String {
        update?.caption(for: thread.reason) ?? thread.reason.displayName
    }

    /// The row truncates, so the tooltip carries everything in full.
    private var hoverDescription: String {
        let updatedDescription = thread.updatedAt.formatted(date: .abbreviated, time: .shortened)
        let visibility = thread.repository.isPrivate ? " (private)" : ""

        let standing = status.map { "\n\($0.displayName)" } ?? ""

        return """
        \(thread.repository.fullName)\(visibility)
        \(caption)

        \(thread.subject.title)\(standing)

        Updated \(updatedDescription)
        """
    }
}
