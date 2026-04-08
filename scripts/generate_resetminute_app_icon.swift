import AppKit
import ImageIO
import UniformTypeIdentifiers

enum IconVariant: CaseIterable {
    case standard
    case dark
    case tinted

    var filename: String {
        switch self {
        case .standard:
            return "icon.png"
        case .dark:
            return "icon2.png"
        case .tinted:
            return "iocn3.png"
        }
    }
}

struct Palette {
    let backgroundTop: NSColor
    let backgroundBottom: NSColor
    let ambientGlow: NSColor
    let ring: NSColor
    let accentRing: NSColor
    let hand: NSColor
    let dot: NSColor
    let shadow: NSColor
}

private let canvasSize = CGSize(width: 1024, height: 1024)
private let iconRect = CGRect(origin: .zero, size: canvasSize)
private let center = CGPoint(x: 512, y: 520)
private let ringRadius: CGFloat = 250
private let ringWidth: CGFloat = 104

private extension CGFloat {
    var radians: CGFloat { self * .pi / 180 }
}

private func palette(for variant: IconVariant) -> Palette {
    switch variant {
    case .standard:
        return Palette(
            backgroundTop: NSColor(calibratedRed: 0.10, green: 0.53, blue: 0.96, alpha: 1.0),
            backgroundBottom: NSColor(calibratedRed: 0.04, green: 0.12, blue: 0.28, alpha: 1.0),
            ambientGlow: NSColor(calibratedRed: 0.40, green: 0.91, blue: 0.92, alpha: 0.28),
            ring: NSColor(calibratedRed: 0.95, green: 0.98, blue: 1.0, alpha: 0.96),
            accentRing: NSColor(calibratedRed: 0.43, green: 0.96, blue: 0.82, alpha: 1.0),
            hand: NSColor(calibratedRed: 1.0, green: 0.96, blue: 0.90, alpha: 1.0),
            dot: NSColor(calibratedRed: 1.0, green: 0.56, blue: 0.38, alpha: 1.0),
            shadow: NSColor(calibratedWhite: 0.0, alpha: 0.18)
        )
    case .dark:
        return Palette(
            backgroundTop: .clear,
            backgroundBottom: .clear,
            ambientGlow: NSColor(calibratedRed: 0.57, green: 0.95, blue: 0.92, alpha: 0.20),
            ring: NSColor(calibratedWhite: 1.0, alpha: 0.98),
            accentRing: NSColor(calibratedRed: 0.62, green: 1.0, blue: 0.88, alpha: 1.0),
            hand: NSColor(calibratedWhite: 1.0, alpha: 0.98),
            dot: NSColor(calibratedRed: 1.0, green: 0.76, blue: 0.52, alpha: 1.0),
            shadow: NSColor(calibratedWhite: 0.0, alpha: 0.0)
        )
    case .tinted:
        return Palette(
            backgroundTop: .clear,
            backgroundBottom: .clear,
            ambientGlow: NSColor(calibratedWhite: 1.0, alpha: 0.0),
            ring: NSColor(calibratedWhite: 1.0, alpha: 0.92),
            accentRing: NSColor(calibratedWhite: 0.88, alpha: 0.92),
            hand: NSColor(calibratedWhite: 0.98, alpha: 0.92),
            dot: NSColor(calibratedWhite: 0.78, alpha: 0.92),
            shadow: NSColor(calibratedWhite: 0.0, alpha: 0.0)
        )
    }
}

private func roundedRectPath(_ rect: CGRect) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: 228, yRadius: 228)
}

private func point(onCircleWithRadius radius: CGFloat, angleDegrees: CGFloat) -> CGPoint {
    CGPoint(
        x: center.x + cos(angleDegrees.radians) * radius,
        y: center.y + sin(angleDegrees.radians) * radius
    )
}

private func drawBackground(for variant: IconVariant, palette: Palette) {
    guard variant == .standard else { return }

    let gradient = NSGradient(colors: [palette.backgroundTop, palette.backgroundBottom])!
    gradient.draw(in: NSBezierPath(rect: iconRect), angle: -55)

    let glowRect = CGRect(x: center.x - 260, y: center.y - 210, width: 520, height: 520)
    let glow = NSBezierPath(ovalIn: glowRect)
    palette.ambientGlow.setFill()
    glow.fill()
}

private func applyShadow(_ palette: Palette) {
    let shadow = NSShadow()
    shadow.shadowColor = palette.shadow
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -8)
    shadow.set()
}

private func drawResetRing(variant: IconVariant, palette: Palette) {
    let ringPath = NSBezierPath()
    ringPath.lineCapStyle = .round
    ringPath.lineJoinStyle = .round
    ringPath.lineWidth = ringWidth
    ringPath.appendArc(withCenter: center, radius: ringRadius, startAngle: 214, endAngle: 26, clockwise: false)

    let accentPath = NSBezierPath()
    accentPath.lineCapStyle = .round
    accentPath.lineJoinStyle = .round
    accentPath.lineWidth = ringWidth
    accentPath.appendArc(withCenter: center, radius: ringRadius, startAngle: 304, endAngle: 26, clockwise: false)

    if variant == .standard {
        NSGraphicsContext.saveGraphicsState()
        applyShadow(palette)
        palette.ring.setStroke()
        ringPath.stroke()
        palette.accentRing.setStroke()
        accentPath.stroke()
        NSGraphicsContext.restoreGraphicsState()
    } else {
        palette.ring.setStroke()
        ringPath.stroke()
        palette.accentRing.setStroke()
        accentPath.stroke()
    }

    let tip = point(onCircleWithRadius: ringRadius, angleDegrees: 26)
    let tangentAngle = CGFloat(26 + 90).radians
    let tangent = CGPoint(x: cos(tangentAngle), y: sin(tangentAngle))
    let normalAngle = CGFloat(26).radians
    let normal = CGPoint(x: cos(normalAngle), y: sin(normalAngle))
    let baseCenter = CGPoint(x: tip.x - tangent.x * 16, y: tip.y - tangent.y * 16)
    let arrowTip = CGPoint(x: tip.x + tangent.x * 58, y: tip.y + tangent.y * 58)
    let left = CGPoint(x: baseCenter.x + normal.x * 60, y: baseCenter.y + normal.y * 60)
    let right = CGPoint(x: baseCenter.x - normal.x * 60, y: baseCenter.y - normal.y * 60)

    let arrow = NSBezierPath()
    arrow.move(to: arrowTip)
    arrow.line(to: left)
    arrow.line(to: right)
    arrow.close()
    palette.accentRing.setFill()
    arrow.fill()
}

private func drawMinuteHand(variant: IconVariant, palette: Palette) {
    if variant == .standard {
        applyShadow(palette)
    }

    let handRect = CGRect(x: center.x - 38, y: center.y - 12, width: 76, height: 212)
    let handPath = NSBezierPath(roundedRect: handRect, xRadius: 38, yRadius: 38)
    palette.hand.setFill()
    handPath.fill()

    let hubRect = CGRect(x: center.x - 58, y: center.y - 76, width: 116, height: 116)
    let hubPath = NSBezierPath(ovalIn: hubRect)
    palette.dot.setFill()
    hubPath.fill()

    let highlightRect = CGRect(x: center.x - 28, y: center.y - 40, width: 44, height: 44)
    let highlight = NSBezierPath(ovalIn: highlightRect)
    NSColor(calibratedWhite: 1.0, alpha: variant == .tinted ? 0.18 : 0.28).setFill()
    highlight.fill()
}

private func writeCGImage(_ image: CGImage, to outputURL: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw NSError(domain: "IconGen", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unable to create image destination"])
    }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "IconGen", code: 5, userInfo: [NSLocalizedDescriptionKey: "Unable to finalize image destination"])
    }
}

private func renderIcon(variant: IconVariant, to outputURL: URL) throws {
    if variant == .standard {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let cgContext = CGContext(
            data: nil,
            width: Int(canvasSize.width),
            height: Int(canvasSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw NSError(domain: "IconGen", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to create RGB graphics context"])
        }

        let context = NSGraphicsContext(cgContext: cgContext, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context

        cgContext.setAllowsAntialiasing(true)
        cgContext.setShouldAntialias(true)
        cgContext.interpolationQuality = .high

        let palette = palette(for: variant)
        drawBackground(for: variant, palette: palette)

        NSGraphicsContext.saveGraphicsState()
        drawResetRing(variant: variant, palette: palette)
        NSGraphicsContext.restoreGraphicsState()

        NSGraphicsContext.saveGraphicsState()
        drawMinuteHand(variant: variant, palette: palette)
        NSGraphicsContext.restoreGraphicsState()

        NSGraphicsContext.restoreGraphicsState()

        guard let image = cgContext.makeImage() else {
            throw NSError(domain: "IconGen", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to create CGImage"])
        }

        try writeCGImage(image, to: outputURL)
        return
    }

    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasSize.width),
        pixelsHigh: Int(canvasSize.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "IconGen", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create bitmap context"])
    }

    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "IconGen", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to create graphics context"])
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let cgContext = context.cgContext
    cgContext.setAllowsAntialiasing(true)
    cgContext.setShouldAntialias(true)
    cgContext.interpolationQuality = .high
    cgContext.clear(iconRect)

    let palette = palette(for: variant)
    drawBackground(for: variant, palette: palette)

    NSGraphicsContext.saveGraphicsState()
    drawResetRing(variant: variant, palette: palette)
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    drawMinuteHand(variant: variant, palette: palette)
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()

    guard let image = bitmap.cgImage else {
        throw NSError(domain: "IconGen", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to create CGImage from bitmap"])
    }

    try writeCGImage(image, to: outputURL)
}

let outputDirectory: URL
if CommandLine.arguments.count > 1 {
    outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
} else {
    outputDirectory = URL(fileURLWithPath: "DeskWellness/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
}

for variant in IconVariant.allCases {
    let outputURL = outputDirectory.appendingPathComponent(variant.filename)
    try renderIcon(variant: variant, to: outputURL)
    print("Wrote \(outputURL.path)")
}
