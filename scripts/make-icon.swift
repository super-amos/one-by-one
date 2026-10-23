// Draws the app icon, one white card with a green check in front of two
// faint outlines of the rest of the deck, and writes the PNGs of an .iconset
// folder. `make icon` runs this and turns the folder into Resources/AppIcon.icns.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func roundedRect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: x, y: y, width: width, height: height), cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// Draws on a 1024-point grid with y pointing down, the same coordinates as
/// the design canvas, scaled to `pixels` square.
func icon(pixels: Int) -> CGImage {
    let ctx = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let scale = CGFloat(pixels) / 1024
    // Thin lines vanish at Finder-list and menu sizes, so small icons get heavier ones.
    let isSmall = pixels <= 64
    ctx.translateBy(x: 0, y: CGFloat(pixels))
    ctx.scaleBy(x: scale, y: -scale)
    // Shadows are measured in pixels and ignore the flip, so they're scaled
    // by hand, and a negative y points them down.
    func shadow(down: CGFloat, blur: CGFloat, _ shadowColor: CGColor) {
        ctx.setShadow(offset: CGSize(width: 0, height: -down * scale), blur: blur * scale, color: shadowColor)
    }

    let body = roundedRect(100, 100, 824, 824, radius: 185)
    ctx.saveGState()
    shadow(down: 10, blur: 24, color(0x000000, 0.22))
    ctx.addPath(body)
    ctx.setFillColor(color(0xE8E4D9))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(body)
    ctx.clip()
    let paper = CGGradient(colorsSpace: sRGB, colors: [color(0xFCFBF8), color(0xE8E4D9)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(paper, start: CGPoint(x: 0, y: 100), end: CGPoint(x: 0, y: 924), options: [])
    ctx.restoreGState()

    // The rest of the deck, out of focus.
    let outlines: [(degrees: CGFloat, hex: UInt32)] = [(-10, 0xD2CDC0), (8, 0xDCD8CD)]
    for outline in outlines {
        ctx.saveGState()
        ctx.translateBy(x: 512, y: 512)
        ctx.rotate(by: outline.degrees * .pi / 180)
        ctx.translateBy(x: -512, y: -512)
        ctx.addPath(roundedRect(292, 232, 440, 560, radius: 58))
        ctx.setStrokeColor(color(outline.hex))
        ctx.setLineWidth(isSmall ? 20 : 10)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // The one card that matters.
    ctx.saveGState()
    shadow(down: 20, blur: 48, color(0x2B2A26, 0.20))
    ctx.addPath(roundedRect(292, 242, 440, 560, radius: 58))
    ctx.setFillColor(color(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.addPath(roundedRect(344, 296, 96, 24, radius: 12))
    ctx.setFillColor(color(0xE4E0D6))
    ctx.fillPath()

    ctx.setFillColor(color(0x17834F))
    ctx.fillEllipse(in: CGRect(x: 400, y: 428, width: 224, height: 224))
    ctx.setStrokeColor(color(0xFFFFFF))
    ctx.setLineWidth(isSmall ? 48 : 30)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: 458, y: 542))
    ctx.addLine(to: CGPoint(x: 497, y: 581))
    ctx.addLine(to: CGPoint(x: 570, y: 505))
    ctx.strokePath()

    return ctx.makeImage()!
}

// The file names iconutil expects, and how many pixels each one is.
let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for size in sizes {
    let url = out.appendingPathComponent("\(size.name).png")
    let file = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(file, icon(pixels: size.pixels), nil)
    guard CGImageDestinationFinalize(file) else { fatalError("Couldn't write \(url.path)") }
}
print(out.path)
