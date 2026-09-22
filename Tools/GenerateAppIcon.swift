// Run by hand:  swift Tools/GenerateAppIcon.swift
//
// Not a build phase: ENABLE_USER_SCRIPT_SANDBOXING is YES, so a script writing into the
// source tree during a build would fail. Regenerate and commit the PNG when the mark changes.
//
// Draws with Core Graphics paths at 1024x1024, sRGB, no alpha channel (an alpha channel is
// the most common App Store icon rejection). Colours match Color+MoodJournal.swift.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024.0
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let assetPath = root
    .appendingPathComponent("mood-journal/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(
        red: Double((hex >> 16) & 0xff) / 255,
        green: Double((hex >> 8) & 0xff) / 255,
        blue: Double(hex & 0xff) / 255,
        alpha: 1
    )
}

let paper = rgb(0xf5f2ec)
let ink = rgb(0x3a3530)
let good = rgb(0x5b9e76)
let bad = rgb(0xc45d4e)

// noneSkipLast: opaque, so the exported PNG carries no alpha channel.
guard let context = CGContext(
    data: nil,
    width: Int(size),
    height: Int(size),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fatalError("could not create the bitmap context")
}

context.setFillColor(paper)
context.fill(CGRect(x: 0, y: 0, width: size, height: size))

// A mood line: one rise and one fall, thick enough to survive being scaled to 40 points.
let midY = size * 0.5
let amplitude = size * 0.17
let path = CGMutablePath()
let left = size * 0.16
let right = size * 0.84
path.move(to: CGPoint(x: left, y: midY - amplitude * 0.75))
path.addCurve(
    to: CGPoint(x: size * 0.5, y: midY + amplitude),
    control1: CGPoint(x: size * 0.28, y: midY - amplitude * 0.9),
    control2: CGPoint(x: size * 0.36, y: midY + amplitude)
)
path.addCurve(
    to: CGPoint(x: right, y: midY - amplitude * 0.85),
    control1: CGPoint(x: size * 0.62, y: midY + amplitude),
    control2: CGPoint(x: size * 0.73, y: midY - amplitude * 0.85)
)

context.setStrokeColor(ink)
context.setLineWidth(size * 0.075)
context.setLineCap(.round)
context.setLineJoin(.round)
context.addPath(path)
context.strokePath()

// Two check-ins on the line, one either side of neutral.
func dot(_ point: CGPoint, _ color: CGColor, radius: Double) {
    context.setFillColor(paper)
    context.fillEllipse(in: CGRect(
        x: point.x - radius * 1.32, y: point.y - radius * 1.32,
        width: radius * 2.64, height: radius * 2.64
    ))
    context.setFillColor(color)
    context.fillEllipse(in: CGRect(
        x: point.x - radius, y: point.y - radius,
        width: radius * 2, height: radius * 2
    ))
}

dot(CGPoint(x: size * 0.5, y: midY + amplitude), good, radius: size * 0.075)
dot(CGPoint(x: left, y: midY - amplitude * 0.75), bad, radius: size * 0.058)
dot(CGPoint(x: right, y: midY - amplitude * 0.85), bad, radius: size * 0.058)

guard
    let image = context.makeImage(),
    let destination = CGImageDestinationCreateWithURL(
        assetPath as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    )
else {
    fatalError("could not encode the icon")
}

CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    fatalError("could not write \(assetPath.path)")
}

print("wrote \(assetPath.path)")
