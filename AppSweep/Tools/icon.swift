// Draws the app icon into an .iconset folder: swift Tools/icon.swift <out.iconset>
// A shield (the forced "security" plugins) struck through, on the macOS icon grid. Drawn by hand:
// SF Symbols may not be used in app icons.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }

func gradient(_ top: CGColor, _ bottom: CGColor) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [top, bottom] as CFArray, locations: [0, 1])!
}

func shieldPath() -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: 292, y: 742))
    p.addQuadCurve(to: CGPoint(x: 732, y: 742), control: CGPoint(x: 512, y: 846))
    p.addLine(to: CGPoint(x: 732, y: 520))
    p.addCurve(to: CGPoint(x: 512, y: 206), control1: CGPoint(x: 732, y: 356), control2: CGPoint(x: 626, y: 258))
    p.addCurve(to: CGPoint(x: 292, y: 520), control1: CGPoint(x: 398, y: 258), control2: CGPoint(x: 292, y: 356))
    p.closeSubpath()
    return p
}

func sparkle(_ ctx: CGContext, at c: CGPoint, size s: CGFloat) {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: c.x, y: c.y + s))
    p.addQuadCurve(to: CGPoint(x: c.x + s, y: c.y), control: c)
    p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - s), control: c)
    p.addQuadCurve(to: CGPoint(x: c.x - s, y: c.y), control: c)
    p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + s), control: c)
    ctx.addPath(p)
    ctx.setFillColor(rgb(1, 1, 1, 0.95))
    ctx.fillPath()
}

// 1024 x 1024 canvas, origin bottom-left.
func draw(_ ctx: CGContext) {
    let tile = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0, 0, 0, 0.35))
    ctx.addPath(tile)
    ctx.setFillColor(rgb(0.18, 0.30, 0.80))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tile)
    ctx.clip()
    ctx.drawLinearGradient(gradient(rgb(0.31, 0.50, 0.98), rgb(0.12, 0.19, 0.60)), start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: rgb(0.03, 0.06, 0.25, 0.45))
    ctx.addPath(shieldPath())
    ctx.setFillColor(rgb(1, 1, 1))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(shieldPath())
    ctx.clip()
    ctx.drawLinearGradient(gradient(rgb(1, 1, 1), rgb(0.85, 0.89, 1)), start: CGPoint(x: 512, y: 846), end: CGPoint(x: 512, y: 206), options: [])
    ctx.restoreGState()

    // The strike: a tile-coloured gap so it reads as cutting through the shield, then the orange bar.
    let line = CGMutablePath()
    line.addLines(between: [CGPoint(x: 292, y: 286), CGPoint(x: 736, y: 730)])
    ctx.addPath(line.copy(strokingWithWidth: 112, lineCap: .round, lineJoin: .round, miterLimit: 1))
    ctx.setFillColor(rgb(0.20, 0.33, 0.82))
    ctx.fillPath()
    ctx.saveGState()
    ctx.addPath(line.copy(strokingWithWidth: 68, lineCap: .round, lineJoin: .round, miterLimit: 1))
    ctx.clip()
    ctx.drawLinearGradient(gradient(rgb(1.0, 0.68, 0.14), rgb(1.0, 0.40, 0.18)), start: CGPoint(x: 736, y: 730), end: CGPoint(x: 292, y: 286), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()

    sparkle(ctx, at: CGPoint(x: 790, y: 330), size: 62)
    sparkle(ctx, at: CGPoint(x: 712, y: 236), size: 30)
    ctx.restoreGState()
}

let out = URL(filePath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128), ("128x128@2x", 256),
                   ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: CGFloat(px) / 1024, y: CGFloat(px) / 1024)
    draw(ctx)
    let dest = CGImageDestinationCreateWithURL(out.appending(path: "icon_\(name).png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
}
