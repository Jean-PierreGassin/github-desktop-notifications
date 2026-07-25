import SwiftUI

/// The menu bar glyph: an original branch-and-commit mark drawn in code, so the
/// app ships no third-party trademark and stays crisp at any menu bar height.
struct GitHubMarkView: View {
    private static let referenceSize: CGFloat = 16
    private static let nodeRadius: CGFloat = 1.7
    private static let strokeWidth: CGFloat = 1.5

    let hasUnread: Bool

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / Self.referenceSize
            context.scaleBy(x: scale, y: scale)

            context.stroke(branchPath(), with: .style(.primary), lineWidth: Self.strokeWidth)
            context.fill(nodesPath(), with: .style(.primary))

            if hasUnread {
                context.fill(badgePath(), with: .color(.red))
            }
        }
    }

    private func branchPath() -> Path {
        var path = Path()

        path.move(to: CGPoint(x: 5.2, y: 4.6))
        path.addLine(to: CGPoint(x: 5.2, y: 11.4))

        path.move(to: CGPoint(x: 5.2, y: 8.6))
        path.addCurve(
            to: CGPoint(x: 10.8, y: 5.6),
            control1: CGPoint(x: 9.2, y: 8.6),
            control2: CGPoint(x: 10.8, y: 7.9),
        )

        return path
    }

    private func nodesPath() -> Path {
        var path = Path()

        for centre in [CGPoint(x: 5.2, y: 3.4), CGPoint(x: 5.2, y: 12.6), CGPoint(x: 10.8, y: 4.4)] {
            path.addEllipse(in: circleBounds(around: centre, radius: Self.nodeRadius))
        }

        return path
    }

    private func badgePath() -> Path {
        Path(ellipseIn: circleBounds(around: CGPoint(x: 12.6, y: 12.6), radius: 3))
    }

    private func circleBounds(around centre: CGPoint, radius: CGFloat) -> CGRect {
        CGRect(
            x: centre.x - radius,
            y: centre.y - radius,
            width: radius * 2,
            height: radius * 2,
        )
    }
}

#Preview {
    HStack(spacing: 12) {
        GitHubMarkView(hasUnread: false).frame(width: 18, height: 18)
        GitHubMarkView(hasUnread: true).frame(width: 18, height: 18)
    }
    .padding()
}
