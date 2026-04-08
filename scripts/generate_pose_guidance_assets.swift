import AppKit
import ImageIO
import UniformTypeIdentifiers

enum PoseAsset {
    case front
    case side

    var filename: String {
        switch self {
        case .front:
            return "front-pose.png"
        case .side:
            return "side-pose-removebg-preview.png"
        }
    }
}

private let canvasSize = CGSize(width: 1200, height: 2000)
private let strokeColor = NSColor.black.withAlphaComponent(0.96)
private let guideColor = NSColor.black.withAlphaComponent(0.82)

private func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw NSError(domain: "PoseAssetGen", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create image destination"])
    }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "PoseAssetGen", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to finalize image destination"])
    }
}

private func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: x, y: y)
}

private func applyStrokeStyle(to path: NSBezierPath, width: CGFloat) {
    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
}

private func drawDashedGuide(from start: CGPoint, to end: CGPoint) {
    let path = NSBezierPath()
    path.move(to: start)
    path.line(to: end)
    applyStrokeStyle(to: path, width: 18)
    path.setLineDash([18, 24], count: 2, phase: 0)
    guideColor.setStroke()
    path.stroke()
}

private func drawFrontPose() -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    let context = CGContext(
        data: nil,
        width: Int(canvasSize.width),
        height: Int(canvasSize.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    )!

    let graphics = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics

    context.clear(CGRect(origin: .zero, size: canvasSize))

    drawDashedGuide(from: point(600, 300), to: point(600, 1660))

    let head = NSBezierPath(ovalIn: CGRect(x: 425, y: 1165, width: 350, height: 430))
    applyStrokeStyle(to: head, width: 24)
    strokeColor.setStroke()
    head.stroke()

    let leftEar = NSBezierPath()
    leftEar.move(to: point(418, 1332))
    leftEar.curve(to: point(382, 1262), controlPoint1: point(392, 1322), controlPoint2: point(378, 1294))
    leftEar.curve(to: point(418, 1196), controlPoint1: point(384, 1226), controlPoint2: point(396, 1202))
    applyStrokeStyle(to: leftEar, width: 20)
    leftEar.stroke()

    let rightEar = NSBezierPath()
    rightEar.move(to: point(782, 1332))
    rightEar.curve(to: point(818, 1262), controlPoint1: point(808, 1322), controlPoint2: point(822, 1294))
    rightEar.curve(to: point(782, 1196), controlPoint1: point(816, 1226), controlPoint2: point(804, 1202))
    applyStrokeStyle(to: rightEar, width: 20)
    rightEar.stroke()

    let neckAndShoulders = NSBezierPath()
    neckAndShoulders.move(to: point(530, 1165))
    neckAndShoulders.curve(to: point(498, 1042), controlPoint1: point(520, 1128), controlPoint2: point(506, 1086))
    neckAndShoulders.curve(to: point(280, 930), controlPoint1: point(448, 988), controlPoint2: point(366, 952))
    neckAndShoulders.curve(to: point(134, 684), controlPoint1: point(214, 904), controlPoint2: point(138, 810))

    neckAndShoulders.move(to: point(670, 1165))
    neckAndShoulders.curve(to: point(702, 1042), controlPoint1: point(680, 1128), controlPoint2: point(694, 1086))
    neckAndShoulders.curve(to: point(920, 930), controlPoint1: point(752, 988), controlPoint2: point(834, 952))
    neckAndShoulders.curve(to: point(1066, 684), controlPoint1: point(986, 904), controlPoint2: point(1062, 810))
    applyStrokeStyle(to: neckAndShoulders, width: 24)
    neckAndShoulders.stroke()

    let traps = NSBezierPath()
    traps.move(to: point(530, 1048))
    traps.curve(to: point(600, 1016), controlPoint1: point(548, 1028), controlPoint2: point(574, 1018))
    traps.curve(to: point(670, 1048), controlPoint1: point(626, 1018), controlPoint2: point(652, 1028))
    applyStrokeStyle(to: traps, width: 16)
    traps.stroke()

    let collar = NSBezierPath()
    collar.move(to: point(468, 992))
    collar.curve(to: point(600, 952), controlPoint1: point(514, 968), controlPoint2: point(556, 954))
    collar.curve(to: point(732, 992), controlPoint1: point(644, 954), controlPoint2: point(686, 968))
    applyStrokeStyle(to: collar, width: 16)
    collar.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return context.makeImage()!
}

private func drawSidePose() -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    let context = CGContext(
        data: nil,
        width: Int(canvasSize.width),
        height: Int(canvasSize.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    )!

    let graphics = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics

    context.clear(CGRect(origin: .zero, size: canvasSize))

    drawDashedGuide(from: point(610, 300), to: point(610, 1660))

    let contour = NSBezierPath()
    contour.move(to: point(474, 958))
    contour.curve(
        to: point(428, 1230),
        controlPoint1: point(446, 1028),
        controlPoint2: point(420, 1124)
    )
    contour.curve(
        to: point(522, 1570),
        controlPoint1: point(430, 1450),
        controlPoint2: point(454, 1544)
    )
    contour.curve(
        to: point(666, 1516),
        controlPoint1: point(574, 1588),
        controlPoint2: point(624, 1572)
    )
    contour.curve(
        to: point(746, 1420),
        controlPoint1: point(704, 1488),
        controlPoint2: point(734, 1456)
    )
    contour.curve(
        to: point(810, 1308),
        controlPoint1: point(766, 1386),
        controlPoint2: point(798, 1348)
    )
    contour.curve(
        to: point(796, 1262),
        controlPoint1: point(816, 1292),
        controlPoint2: point(812, 1276)
    )
    contour.curve(
        to: point(772, 1236),
        controlPoint1: point(790, 1250),
        controlPoint2: point(780, 1242)
    )
    contour.curve(
        to: point(784, 1212),
        controlPoint1: point(776, 1230),
        controlPoint2: point(782, 1220)
    )
    contour.curve(
        to: point(748, 1148),
        controlPoint1: point(786, 1192),
        controlPoint2: point(772, 1168)
    )
    contour.curve(
        to: point(650, 984),
        controlPoint1: point(726, 1086),
        controlPoint2: point(684, 1018)
    )
    contour.curve(
        to: point(738, 832),
        controlPoint1: point(662, 928),
        controlPoint2: point(700, 870)
    )
    contour.curve(
        to: point(900, 782),
        controlPoint1: point(784, 800),
        controlPoint2: point(848, 792)
    )
    contour.curve(
        to: point(950, 654),
        controlPoint1: point(936, 770),
        controlPoint2: point(954, 716)
    )
    applyStrokeStyle(to: contour, width: 24)
    strokeColor.setStroke()
    contour.stroke()

    let ear = NSBezierPath()
    ear.move(to: point(610, 1254))
    ear.curve(to: point(564, 1188), controlPoint1: point(574, 1246), controlPoint2: point(554, 1218))
    ear.curve(to: point(610, 1122), controlPoint1: point(566, 1152), controlPoint2: point(588, 1126))
    applyStrokeStyle(to: ear, width: 18)
    ear.stroke()

    let innerEar = NSBezierPath()
    innerEar.move(to: point(602, 1224))
    innerEar.curve(to: point(586, 1188), controlPoint1: point(590, 1212), controlPoint2: point(584, 1202))
    innerEar.curve(to: point(602, 1156), controlPoint1: point(588, 1170), controlPoint2: point(596, 1160))
    applyStrokeStyle(to: innerEar, width: 10)
    innerEar.stroke()

    let neck = NSBezierPath()
    neck.move(to: point(474, 958))
    neck.curve(to: point(410, 836), controlPoint1: point(450, 904), controlPoint2: point(424, 868))
    neck.curve(to: point(306, 734), controlPoint1: point(382, 784), controlPoint2: point(334, 748))
    neck.curve(to: point(276, 548), controlPoint1: point(288, 704), controlPoint2: point(272, 632))
    applyStrokeStyle(to: neck, width: 24)
    neck.stroke()

    let back = NSBezierPath()
    back.move(to: point(420, 840))
    back.curve(to: point(364, 652), controlPoint1: point(388, 778), controlPoint2: point(370, 712))
    back.curve(to: point(324, 412), controlPoint1: point(360, 570), controlPoint2: point(340, 480))
    applyStrokeStyle(to: back, width: 18)
    back.stroke()

    let clavicle = NSBezierPath()
    clavicle.move(to: point(610, 930))
    clavicle.curve(to: point(692, 892), controlPoint1: point(634, 920), controlPoint2: point(664, 904))
    applyStrokeStyle(to: clavicle, width: 12)
    clavicle.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return context.makeImage()!
}

private func render(_ asset: PoseAsset) throws {
    let baseDirectory = URL(fileURLWithPath: "DeskWellness/Assets.xcassets", isDirectory: true)
    let outputURL: URL
    let image: CGImage

    switch asset {
    case .front:
        outputURL = baseDirectory.appendingPathComponent("front-pose.imageset/\(asset.filename)")
        image = drawFrontPose()
    case .side:
        outputURL = baseDirectory.appendingPathComponent("side-pose.imageset/\(asset.filename)")
        image = drawSidePose()
    }

    try writePNG(image, to: outputURL)
    print("Wrote \(outputURL.path)")
}

try render(.front)
try render(.side)
