#!/usr/bin/env swift

import AppKit

// --- Configuration ---
let outputDir = "Resources"
let iconsetName = "AppIcon.iconset"
let icnsName = "AppIcon.icns"

let sizes: [(name: String, size: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

// --- Drawing ---
// Draws the cloudDrop icon: cloud outline + upload arrow with blue-to-cyan gradient on white.

func cloudPath(s: CGFloat, cx: CGFloat, cy: CGFloat) -> CGPath {
    let cloud = CGMutablePath()

    let baseL = cx - s * 0.30
    let baseR = cx + s * 0.30
    let baseY = cy - s * 0.12
    let cornerR = s * 0.05

    cloud.move(to: CGPoint(x: baseL + cornerR, y: baseY))
    cloud.addLine(to: CGPoint(x: baseR - cornerR, y: baseY))

    cloud.addCurve(to: CGPoint(x: baseR + s * 0.02, y: baseY + s * 0.10),
                   control1: CGPoint(x: baseR, y: baseY),
                   control2: CGPoint(x: baseR + s * 0.02, y: baseY + s * 0.03))

    cloud.addCurve(to: CGPoint(x: cx + s * 0.20, y: cy + s * 0.14),
                   control1: CGPoint(x: baseR + s * 0.02, y: cy + s * 0.04),
                   control2: CGPoint(x: cx + s * 0.28, y: cy + s * 0.10))

    cloud.addCurve(to: CGPoint(x: cx, y: cy + s * 0.28),
                   control1: CGPoint(x: cx + s * 0.16, y: cy + s * 0.24),
                   control2: CGPoint(x: cx + s * 0.10, y: cy + s * 0.28))

    cloud.addCurve(to: CGPoint(x: cx - s * 0.22, y: cy + s * 0.10),
                   control1: CGPoint(x: cx - s * 0.10, y: cy + s * 0.28),
                   control2: CGPoint(x: cx - s * 0.16, y: cy + s * 0.18))

    cloud.addCurve(to: CGPoint(x: baseL, y: baseY + cornerR),
                   control1: CGPoint(x: cx - s * 0.30, y: cy - s * 0.01),
                   control2: CGPoint(x: baseL, y: cy - s * 0.01))

    cloud.addQuadCurve(to: CGPoint(x: baseL + cornerR, y: baseY),
                       control: CGPoint(x: baseL, y: baseY))

    cloud.closeSubpath()
    return cloud
}

func arrowPath(s: CGFloat, cx: CGFloat, cy: CGFloat) -> CGPath {
    let arrowCY = cy + s * 0.02
    let arrowH = s * 0.20
    let headW  = s * 0.16
    let headH  = s * 0.09
    let shaftW = s * 0.058
    let shaftR = s * 0.012

    let arrowBottom = arrowCY - arrowH * 0.45
    let arrowTop = arrowCY + arrowH * 0.55

    let arrow = CGMutablePath()

    arrow.move(to: CGPoint(x: cx, y: arrowTop))
    arrow.addLine(to: CGPoint(x: cx + headW / 2, y: arrowTop - headH))
    arrow.addLine(to: CGPoint(x: cx + shaftW / 2, y: arrowTop - headH))
    arrow.addLine(to: CGPoint(x: cx + shaftW / 2, y: arrowBottom + shaftR))
    arrow.addQuadCurve(to: CGPoint(x: cx + shaftW / 2 - shaftR, y: arrowBottom),
                       control: CGPoint(x: cx + shaftW / 2, y: arrowBottom))
    arrow.addLine(to: CGPoint(x: cx - shaftW / 2 + shaftR, y: arrowBottom))
    arrow.addQuadCurve(to: CGPoint(x: cx - shaftW / 2, y: arrowBottom + shaftR),
                       control: CGPoint(x: cx - shaftW / 2, y: arrowBottom))
    arrow.addLine(to: CGPoint(x: cx - shaftW / 2, y: arrowTop - headH))
    arrow.addLine(to: CGPoint(x: cx - headW / 2, y: arrowTop - headH))

    arrow.closeSubpath()
    return arrow
}

func drawGradient(in ctx: CGContext, clippedTo path: CGPath, size s: CGFloat) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        CGColor(red: 0.00, green: 0.45, blue: 0.95, alpha: 1.0),  // blue
        CGColor(red: 0.00, green: 0.75, blue: 0.95, alpha: 1.0),  // cyan
    ] as CFArray
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) else { return }

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: 0, y: 0),
                           end: CGPoint(x: s, y: s),
                           options: [])
    ctx.restoreGState()
}

func drawIcon(into ctx: CGContext, pixelSize: Int) {
    let s = CGFloat(pixelSize)
    let rect = CGRect(x: 0, y: 0, width: s, height: s)

    // White background
    ctx.setFillColor(CGColor.white)
    ctx.fill(rect)

    let cx = s * 0.50
    let cy = s * 0.46
    let strokeWidth = s * 0.058

    // Cloud: convert stroke to filled shape, then apply gradient
    let cloud = cloudPath(s: s, cx: cx, cy: cy)
    let strokedCloud = cloud.copy(strokingWithWidth: strokeWidth,
                                   lineCap: .round,
                                   lineJoin: .round,
                                   miterLimit: 10)
    drawGradient(in: ctx, clippedTo: strokedCloud, size: s)

    // Arrow: filled shape with gradient
    let arrow = arrowPath(s: s, cx: cx, cy: cy)
    drawGradient(in: ctx, clippedTo: arrow, size: s)
}

// --- PNG rendering ---

func renderPNG(pixelSize: Int) -> Data {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil, width: pixelSize, height: pixelSize,
        bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Failed to create CGContext for size \(pixelSize)")
    }

    drawIcon(into: ctx, pixelSize: pixelSize)

    guard let cgImage = ctx.makeImage() else { fatalError("Failed to create CGImage") }
    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    bitmap.size = NSSize(width: pixelSize, height: pixelSize)
    guard let pngData = bitmap.representation(using: .png, properties: [:]) else { fatalError("PNG failed") }
    return pngData
}

// --- Main ---

let fm = FileManager.default
let iconsetPath = "\(outputDir)/\(iconsetName)"
try? fm.removeItem(atPath: iconsetPath)
try! fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

for entry in sizes {
    let filePath = "\(iconsetPath)/\(entry.name).png"
    try! renderPNG(pixelSize: entry.size).write(to: URL(fileURLWithPath: filePath))
    print("  \(entry.name).png (\(entry.size)x\(entry.size))")
}

let icnsPath = "\(outputDir)/\(icnsName)"
try? fm.removeItem(atPath: icnsPath)

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetPath, "-o", icnsPath]
try! process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else { fatalError("iconutil failed with status \(process.terminationStatus)") }

try? fm.removeItem(atPath: iconsetPath)
print("Generated \(icnsPath)")
