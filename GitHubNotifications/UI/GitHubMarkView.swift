import SwiftUI

/// The menu bar glyph: an original branch-and-commit mark drawn in code, so the
/// app ships no third-party trademark and stays crisp at any menu bar height.
///
/// Built from `Shape`s rather than a `Canvas` because the status item renders
/// its label outside a normal view hierarchy, where a canvas has no intrinsic
/// size and collapses to nothing.
struct GitHubMarkView: View {
    private static let strokeWidth: CGFloat = 1.5

    let hasUnread: Bool

    var size: CGFloat = 18

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            BranchShape()
                .stroke(.primary, style: StrokeStyle(lineWidth: scaled(Self.strokeWidth), lineCap: .round))

            CommitNodesShape()
                .fill(.primary)

            if hasUnread {
                Circle()
                    .fill(.red)
                    .frame(width: scaled(6), height: scaled(6))
            }
        }
        .frame(width: size, height: size)
    }

    private func scaled(_ value: CGFloat) -> CGFloat {
        value * size / MarkGeometry.referenceSize
    }
}

/// Shared geometry so the mark and the app icon stay identical.
enum MarkGeometry {
    static let referenceSize: CGFloat = 16
    static let nodeRadius: CGFloat = 1.7
    static let trunkTop = CGPoint(x: 5.2, y: 3.4)
    static let trunkBottom = CGPoint(x: 5.2, y: 12.6)
    static let branchEnd = CGPoint(x: 10.8, y: 4.4)
}

struct BranchShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / MarkGeometry.referenceSize

        var path = Path()
        path.move(to: CGPoint(x: 5.2, y: 4.6))
        path.addLine(to: CGPoint(x: 5.2, y: 11.4))

        path.move(to: CGPoint(x: 5.2, y: 8.6))
        path.addCurve(
            to: CGPoint(x: 10.8, y: 5.6),
            control1: CGPoint(x: 9.2, y: 8.6),
            control2: CGPoint(x: 10.8, y: 7.9),
        )

        return path.applying(CGAffineTransform(scaleX: scale, y: scale))
    }
}

struct CommitNodesShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / MarkGeometry.referenceSize
        let radius = MarkGeometry.nodeRadius

        var path = Path()

        for centre in [MarkGeometry.trunkTop, MarkGeometry.trunkBottom, MarkGeometry.branchEnd] {
            path.addEllipse(in: CGRect(
                x: centre.x - radius,
                y: centre.y - radius,
                width: radius * 2,
                height: radius * 2,
            ))
        }

        return path.applying(CGAffineTransform(scaleX: scale, y: scale))
    }
}

#Preview {
    HStack(spacing: 12) {
        GitHubMarkView(hasUnread: false)
        GitHubMarkView(hasUnread: true)
        GitHubMarkView(hasUnread: true, size: 64)
    }
    .padding()
}
