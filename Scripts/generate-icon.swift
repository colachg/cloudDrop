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

func drawIcon(into ctx: CGContext, pixelSize: Int) {
    let s = CGFloat(pixelSize)
    let rect = CGRect(x: 0, y: 0, width: s, height: s)

    // Rounded-rect clipping (macOS icon shape — ~18.5% corner radius)
    let cornerRadius = s * 0.185
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()

    // Background: deep indigo gradient (bottom-left → top-right)
    let bgColors = [
        CGColor(red: 0.06, green: 0.05, blue: 0.20, alpha: 1.0),
        CGColor(red: 0.14, green: 0.12, blue: 0.38, alpha: 1.0),
        CGColor(red: 0.20, green: 0.18, blue: 0.50, alpha: 1.0),
    ] as CFArray
    if let g = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 0.55, 1.0]) {
        ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: s, y: s), options: [])
    }

    // Subtle radial glow behind cloud
    let glowColors = [
        CGColor(red: 0.30, green: 0.25, blue: 0.65, alpha: 0.3),
        CGColor(red: 0.15, green: 0.12, blue: 0.40, alpha: 0.0),
    ] as CFArray
    if let g = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
        let center = CGPoint(x: s * 0.50, y: s * 0.55)
        ctx.drawRadialGradient(g, startCenter: center, startRadius: 0,
                               endCenter: center, endRadius: s * 0.45, options: [])
    }

    let cloudCX = s * 0.50
    let cloudCY = s * 0.52

    // Cloud shadow
    ctx.saveGState()
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.12))
    drawCloudShape(ctx: ctx, s: s, cx: cloudCX, cy: cloudCY - s * 0.018)
    ctx.restoreGState()

    // Cloud (white)
    ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
    drawCloudShape(ctx: ctx, s: s, cx: cloudCX, cy: cloudCY)

    // Upload arrow (orange)
    drawUploadArrow(ctx: ctx, s: s, cx: cloudCX, cy: cloudCY)
}

func drawCloudShape(ctx: CGContext, s: CGFloat, cx: CGFloat, cy: CGFloat) {
    // Cloud built from overlapping ellipses — body + three bumps on top

    // Wide flat body
    let bw = s * 0.54, bh = s * 0.17
    ctx.fillEllipse(in: CGRect(x: cx - bw / 2, y: cy - bh * 0.65, width: bw, height: bh))

    // Center bump (tallest)
    let cr = s * 0.135
    ctx.fillEllipse(in: CGRect(x: cx - cr, y: cy + s * 0.01, width: cr * 2, height: cr * 2))

    // Left bump
    let lr = s * 0.095
    ctx.fillEllipse(in: CGRect(x: cx - s * 0.20 - lr * 0.3, y: cy - s * 0.01, width: lr * 2, height: lr * 2))

    // Right bump
    let rr = s * 0.105
    ctx.fillEllipse(in: CGRect(x: cx + s * 0.08, y: cy - s * 0.005, width: rr * 2, height: rr * 2))
}

func drawUploadArrow(ctx: CGContext, s: CGFloat, cx: CGFloat, cy: CGFloat) {
    // Cloudflare-orange upward arrow inside the cloud
    ctx.setFillColor(CGColor(red: 0.976, green: 0.451, blue: 0.086, alpha: 1.0))

    // Arrow head (triangle pointing up)
    let tipY = cy + s * 0.12
    let headBaseY = tipY - s * 0.10
    let headHalfW = s * 0.10

    let head = CGMutablePath()
    head.move(to: CGPoint(x: cx, y: tipY))
    head.addLine(to: CGPoint(x: cx - headHalfW, y: headBaseY))
    head.addLine(to: CGPoint(x: cx + headHalfW, y: headBaseY))
    head.closeSubpath()
    ctx.addPath(head)
    ctx.fillPath()

    // Arrow shaft (rounded rect)
    let shaftW = s * 0.055
    let shaftTop = headBaseY + s * 0.015
    let shaftBottom = cy - s * 0.08
    let shaftRect = CGRect(x: cx - shaftW / 2, y: shaftBottom, width: shaftW, height: shaftTop - shaftBottom)
    ctx.addPath(CGPath(roundedRect: shaftRect, cornerWidth: shaftW * 0.35, cornerHeight: shaftW * 0.35, transform: nil))
    ctx.fillPath()
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
