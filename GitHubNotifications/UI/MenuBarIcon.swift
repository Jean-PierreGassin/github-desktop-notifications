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
@MainActor
enum MenuBarIcon {
    /// The canvas is wider than the glyph so the pulse halo has somewhere to go.
    /// Clipping a halo turns a swell into a smear.
    private static let canvasSide: CGFloat = 20
    private static let glyphSide: CGFloat = 18
    private static let strokeWidth: CGFloat = 1.5

    private static let badgeRadius: CGFloat = 3
    private static let badgeCentre = CGPoint(x: 15.5, y: 4.5)
    private static let peakBadgeRadius: CGFloat = 4
    private static let peakHaloRadius: CGFloat = 4.5
    private static let haloOpacity: CGFloat = 0.35

    /// One pulse, pre-rendered. Drawing Bezier paths inside a 60 Hz callback is
    /// what made the old two-state badge stutter, so every frame is made once
    /// and kept.
    static let pulseFrameCount = 30

    private static var cachedFrames: [Bool: [NSImage]] = [:]
    private static var cachedBadgeDescription: String?

    static func make(hasUnread: Bool, isDarkMenuBar: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: canvasSide, height: canvasSide), flipped: false) { _ in
            draw(glyphColour: glyphColour(hasUnread: hasUnread, isDarkMenuBar: isDarkMenuBar), hasUnread: hasUnread)

            return true
        }

        image.isTemplate = !hasUnread

        return image
    }

    /// The frames of one swell, from resting through the peak and back. Frame
    /// zero is the resting badge, which is what shows between pulses.
    static func pulseFrames(isDarkMenuBar: Bool) -> [NSImage] {
        discardCacheIfBadgeColourChanged()

        if let frames = cachedFrames[isDarkMenuBar] {
            return frames
        }

        let frames = (0 ..< pulseFrameCount).map { index in
            makePulseFrame(at: swell(atFrame: index), isDarkMenuBar: isDarkMenuBar)
        }

        cachedFrames[isDarkMenuBar] = frames

        return frames
    }

    /// A raised cosine, so the badge leaves and returns to rest at zero speed
    /// rather than snapping at either end.
    private static func swell(atFrame index: Int) -> CGFloat {
        let progress = CGFloat(index) / CGFloat(pulseFrameCount)

        return (1 - cos(2 * .pi * progress)) / 2
    }

    private static func makePulseFrame(at swell: CGFloat, isDarkMenuBar: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: canvasSide, height: canvasSide), flipped: false) { _ in
            draw(
                glyphColour: glyphColour(hasUnread: true, isDarkMenuBar: isDarkMenuBar),
                hasUnread: true,
                swell: swell,
            )

            return true
        }

        image.isTemplate = false

        return image
    }

    private static func glyphColour(hasUnread: Bool, isDarkMenuBar: Bool) -> NSColor {
        hasUnread && isDarkMenuBar ? .white : .black
    }

    private static func draw(glyphColour: NSColor, hasUnread: Bool, swell: CGFloat = 0) {
        let scale = glyphSide / MarkGeometry.referenceSize

        glyphColour.setStroke()
        glyphColour.setFill()

        let transform = AffineTransform(translationByX: 0, byY: canvasSide - glyphSide)

        let branch = branchPath()
        branch.transform(using: AffineTransform(scale: scale))
        branch.transform(using: transform)
        branch.lineWidth = strokeWidth * scale
        branch.lineCapStyle = .round
        branch.stroke()

        let nodes = nodesPath()
        nodes.transform(using: AffineTransform(scale: scale))
        nodes.transform(using: transform)
        nodes.fill()

        guard hasUnread else {
            return
        }

        drawBadge(swell: swell)
    }

    /// Red, deliberately, and not the accent colour the row dots use. In a menu
    /// bar full of monochrome glyphs the badge has one job, which is to be seen
    /// against whatever is beside it, and an accent colour that happens to match
    /// the bar does not do that.
    private static func drawBadge(swell: CGFloat) {
        let badgeColour = NSColor.systemRed

        if swell > 0 {
            let haloRadius = badgeRadius + (peakHaloRadius - badgeRadius) * swell

            badgeColour.withAlphaComponent(haloOpacity * (1 - swell)).setFill()
            circle(radius: haloRadius).fill()
        }

        badgeColour.setFill()
        circle(radius: badgeRadius + (peakBadgeRadius - badgeRadius) * swell).fill()
    }

    private static func circle(radius: CGFloat) -> NSBezierPath {
        NSBezierPath(ovalIn: NSRect(
            x: badgeCentre.x - radius,
            y: badgeCentre.y - radius,
            width: radius * 2,
            height: radius * 2,
        ))
    }

    /// The frames bake in the badge colour, which follows the system red and so
    /// shifts with accessibility settings like Increase Contrast. Appearance is
    /// already part of the cache key.
    private static func discardCacheIfBadgeColourChanged() {
        let badgeDescription = NSColor.systemRed.usingColorSpace(.sRGB)?.description ?? ""

        guard badgeDescription != cachedBadgeDescription else {
            return
        }

        cachedBadgeDescription = badgeDescription
        cachedFrames = [:]
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
