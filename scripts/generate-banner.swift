#!/usr/bin/env swift
// Draws the README banner from the same branch-and-commit geometry as the app
// icon, so the wordmark and the icon stay in step.
//
// Usage: xcrun swift scripts/generate-banner.swift

import AppKit

let referenceSize: CGFloat = 16
let scale: CGFloat = 2

let plateHeight: CGFloat = 300
let padding: CGFloat = 78
let glyphSide: CGFloat = 148
let gap: CGFloat = 54

let title = "GitHub Notifications"
let tagline = "Desktop notifications for your GitHub inbox"

let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appending(path: "assets")

let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 74, weight: .semibold),
    .foregroundColor: NSColor.white,
    .kern: -1.4,
]

let taglineAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 30, weight: .regular),
    .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.55),
    .kern: 0.1,
]

func branchPath() -> NSBezierPath {
    let path = NSBezierPath()

    path.move(to: CGPoint(x: 5.2, y: 16 - 4.6))
    path.line(to: CGPoint(x: 5.2, y: 16 - 11.4))

    path.move(to: CGPoint(x: 5.2, y: 16 - 8.6))
    path.curve(
        to: CGPoint(x: 10.8, y: 16 - 5.6),
        controlPoint1: CGPoint(x: 9.2, y: 16 - 8.6),
        controlPoint2: CGPoint(x: 10.8, y: 16 - 7.9),
    )

    return path
}

func nodesPath() -> NSBezierPath {
    let path = NSBezierPath()
    let radius: CGFloat = 1.7

    for centre in [CGPoint(x: 5.2, y: 16 - 3.4), CGPoint(x: 5.2, y: 16 - 12.6), CGPoint(x: 10.8, y: 16 - 4.4)] {
        let bounds = CGRect(
            x: centre.x - radius,
            y: centre.y - radius,
            width: radius * 2,
            height: radius * 2,
        )
        path.appendOval(in: bounds)
    }

    return path
}

/// The unread dot the menu bar icon carries. It is drawn twice: once in the
/// plate colour to notch a gap out of the branch mark behind it, then in red.
func badgePath(radius: CGFloat) -> NSBezierPath {
    let centre = CGPoint(x: 12.3, y: 16 - 2.15)

    return NSBezierPath(ovalIn: CGRect(
        x: centre.x - radius,
        y: centre.y - radius,
        width: radius * 2,
        height: radius * 2,
    ))
}

func drawBanner(size: CGSize) -> NSBitmapImageRep {
    let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width * scale),
        pixelsHigh: Int(size.height * scale),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0,
    )!
    representation.size = size

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)

    let plate = CGRect(origin: .zero, size: size)
    let background = NSBezierPath(roundedRect: plate, xRadius: 42, yRadius: 42)
    let gradient = NSGradient(
        starting: NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.21, alpha: 1),
        ending: NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.09, alpha: 1),
    )!
    gradient.draw(in: background, angle: -90)

    NSGraphicsContext.saveGraphicsState()

    let glyphScale = glyphSide / referenceSize
    let transform = NSAffineTransform()
    transform.translateX(by: padding, yBy: (plate.height - glyphSide) / 2)
    transform.scale(by: glyphScale)
    transform.concat()

    NSColor.white.setStroke()
    NSColor.white.setFill()

    let strokedBranch = branchPath()
    strokedBranch.lineWidth = 1.5
    strokedBranch.lineCapStyle = .round
    strokedBranch.stroke()

    nodesPath().fill()

    // The plate gradient barely moves across the badge, so a flat sample of it
    // is indistinguishable from a true cutout.
    NSColor(calibratedRed: 0.125, green: 0.145, blue: 0.172, alpha: 1).setFill()
    badgePath(radius: 2.3).fill()

    NSColor.systemRed.setFill()
    badgePath(radius: 1.5).fill()

    NSGraphicsContext.restoreGraphicsState()

    let titleText = NSAttributedString(string: title, attributes: titleAttributes)
    let taglineText = NSAttributedString(string: tagline, attributes: taglineAttributes)

    let textLeft = padding + glyphSide + gap
    let blockHeight = titleText.size().height + 14 + taglineText.size().height
    // Lifted slightly: optical centre sits above the metric centre once the
    // title's ascenders are taken into account.
    let blockBottom = (plate.height - blockHeight) / 2 + 8

    taglineText.draw(at: CGPoint(x: textLeft, y: blockBottom))
    titleText.draw(at: CGPoint(x: textLeft, y: blockBottom + taglineText.size().height + 14))

    NSGraphicsContext.restoreGraphicsState()

    return representation
}

let titleWidth = NSAttributedString(string: title, attributes: titleAttributes).size().width
let taglineWidth = NSAttributedString(string: tagline, attributes: taglineAttributes).size().width
let bannerSize = CGSize(
    width: (padding + glyphSide + gap + max(titleWidth, taglineWidth) + padding).rounded(),
    height: plateHeight,
)

try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let representation = drawBanner(size: bannerSize)

guard let data = representation.representation(using: .png, properties: [:]) else {
    exit(1)
}

let fileURL = outputDirectory.appending(path: "banner.png")
try data.write(to: fileURL)
print("Wrote \(fileURL.lastPathComponent) at \(Int(bannerSize.width * scale))x\(Int(bannerSize.height * scale))")
