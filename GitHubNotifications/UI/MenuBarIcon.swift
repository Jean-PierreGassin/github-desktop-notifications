import AppKit

/// Renders the menu bar glyph as an `NSImage`.
///
/// The status item draws its label outside a normal SwiftUI hierarchy, where
/// vector views can measure to nothing and disappear, so the icon is rasterised
/// here instead.
///
/// Without a badge the image is a template, which macOS tints correctly for
/// light, dark and reduced-transparency menu bars. With a badge it cannot be,
/// because a template is a monochrome mask and would swallow the red dot, so the
/// glyph colour is resolved from the current appearance instead.
enum MenuBarIcon {
    private static let side: CGFloat = 18
    private static let strokeWidth: CGFloat = 1.5
    private static let badgeDiameter: CGFloat = 6

    static func make(hasUnread: Bool, isDarkMenuBar: Bool, isPulsing: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            let glyphColour: NSColor = hasUnread ? (isDarkMenuBar ? .white : .black) : .black

            draw(glyphColour: glyphColour, hasUnread: hasUnread, isPulsing: isPulsing)

            return true
        }

        image.isTemplate = !hasUnread

        return image
    }

    private static func draw(glyphColour: NSColor, hasUnread: Bool, isPulsing: Bool) {
        let scale = side / MarkGeometry.referenceSize

        glyphColour.setStroke()
        glyphColour.setFill()

        let branch = branchPath()
        branch.transform(using: AffineTransform(scale: scale))
        branch.lineWidth = strokeWidth * scale
        branch.lineCapStyle = .round
        branch.stroke()

        let nodes = nodesPath()
        nodes.transform(using: AffineTransform(scale: scale))
        nodes.fill()

        guard hasUnread else {
            return
        }

        let diameter = isPulsing ? badgeDiameter + 2 : badgeDiameter

        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: NSRect(
            x: side - diameter,
            y: 0,
            width: diameter,
            height: diameter,
        )).fill()
    }

    /// Geometry is expressed top-down, matching the SwiftUI mark, so every
    /// y value is flipped into the bottom-up drawing space.
    private static func flipped(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: MarkGeometry.referenceSize - point.y)
    }

    private static func branchPath() -> NSBezierPath {
        let path = NSBezierPath()

        path.move(to: flipped(CGPoint(x: 5.2, y: 4.6)))
        path.line(to: flipped(CGPoint(x: 5.2, y: 11.4)))

        path.move(to: flipped(CGPoint(x: 5.2, y: 8.6)))
        path.curve(
            to: flipped(CGPoint(x: 10.8, y: 5.6)),
            controlPoint1: flipped(CGPoint(x: 9.2, y: 8.6)),
            controlPoint2: flipped(CGPoint(x: 10.8, y: 7.9)),
        )

        return path
    }

    private static func nodesPath() -> NSBezierPath {
        let path = NSBezierPath()
        let radius = MarkGeometry.nodeRadius

        for centre in [MarkGeometry.trunkTop, MarkGeometry.trunkBottom, MarkGeometry.branchEnd] {
            let origin = flipped(centre)

            path.appendOval(in: NSRect(
                x: origin.x - radius,
                y: origin.y - radius,
                width: radius * 2,
                height: radius * 2,
            ))
        }

        return path
    }
}
