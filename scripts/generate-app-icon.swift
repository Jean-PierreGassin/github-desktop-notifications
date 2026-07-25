#!/usr/bin/env swift
// Draws the app icon from the same branch-and-commit geometry as the menu bar
// glyph and writes every size the asset catalog needs.
//
// Usage: xcrun swift scripts/generate-app-icon.swift

import AppKit

let referenceSize: CGFloat = 16
let glyphInset: CGFloat = 0.22
let iconSizes: [Int] = [16, 32, 64, 128, 256, 512, 1024]

let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appending(path: "GitHubNotifications/Resources/Assets.xcassets/AppIcon.appiconset")

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

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0,
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)

    let canvas = CGRect(x: 0, y: 0, width: size, height: size)
    let plate = canvas.insetBy(dx: size * 0.06, dy: size * 0.06)

    let background = NSBezierPath(roundedRect: plate, xRadius: plate.width * 0.2237, yRadius: plate.width * 0.2237)
    let gradient = NSGradient(
        starting: NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.21, alpha: 1),
        ending: NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.09, alpha: 1),
    )!
    gradient.draw(in: background, angle: -90)

    let glyphSide = plate.width * (1 - glyphInset * 2)
    let scale = glyphSide / referenceSize

    let transform = NSAffineTransform()
    transform.translateX(by: plate.minX + plate.width * glyphInset, yBy: plate.minY + plate.height * glyphInset)
    transform.scale(by: scale)
    transform.concat()

    NSColor.white.setStroke()
    NSColor.white.setFill()

    let strokedBranch = branchPath()
    strokedBranch.lineWidth = 1.5
    strokedBranch.lineCapStyle = .round
    strokedBranch.stroke()

    nodesPath().fill()

    NSGraphicsContext.restoreGraphicsState()

    return representation
}

try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for size in iconSizes {
    let representation = drawIcon(size: CGFloat(size))

    guard let data = representation.representation(using: .png, properties: [:]) else {
        continue
    }

    let fileURL = outputDirectory.appending(path: "icon_\(size).png")
    try data.write(to: fileURL)
    print("Wrote \(fileURL.lastPathComponent)")
}
