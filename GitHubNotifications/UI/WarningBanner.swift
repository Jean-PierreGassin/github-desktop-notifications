import SwiftUI

/// A single, consistent way to raise a problem the user can act on: one line of
/// plain text and one button, never a hidden link.
struct WarningBanner: View {
    let message: String
    let actionTitle: String
    let action: () -> Void

    var symbolName = "exclamationmark.triangle.fill"

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbolName)
                .foregroundStyle(.orange)

            Text(message)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button(actionTitle, action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.orange.opacity(0.35), lineWidth: 1),
        )
    }
}

/// The same shape as ``WarningBanner`` for calmer, informational content.
struct InfoBubble<Content: View>: View {
    let symbolName: String

    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbolName)
                .foregroundStyle(.secondary)

            content
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }
}
