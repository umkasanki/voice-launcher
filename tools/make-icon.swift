import AppKit

// Renders the Voice Launcher app icon — an orange squircle with a plump white
// microphone — to a 1024×1024 PNG. Mirrors tools/AppIcon.svg.
//   swiftc make-icon.swift -o make-icon && ./make-icon out.png

let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                           isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
let cg = ctx.cgContext

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func hex(_ v: String, _ a: Double = 1) -> CGColor {
    let n = Int(v, radix: 16)!
    return rgb(Double(n >> 16 & 255) / 255, Double(n >> 8 & 255) / 255, Double(n & 255) / 255, a)
}
// Arguments: out.png tileTop tileBottom glyphTint shadowTint (hex, no #).
let args = CommandLine.arguments
let tileTop = hex(args.count > 2 ? args[2] : "FDBA74")
let tileBottom = hex(args.count > 3 ? args[3] : "EA580C")
let glyphTint = hex(args.count > 4 ? args[4] : "FFEDD5")
let shadowTint = hex(args.count > 5 ? args[5] : "7C2D12", 0.35)

// Map an SVG-style 200×200 y-down space onto an 832 body inset 96px in the canvas.
let inset: CGFloat = 96
let body: CGFloat = CGFloat(size) - inset * 2
cg.translateBy(x: inset, y: CGFloat(size) - inset)
cg.scaleBy(x: body / 200, y: -body / 200)

// --- Squircle tile: vertical gradient + top sheen ---
let tile = CGPath(roundedRect: CGRect(x: 0, y: 0, width: 200, height: 200),
                  cornerWidth: 46, cornerHeight: 46, transform: nil)
cg.saveGState()
cg.addPath(tile); cg.clip()
let grad = CGGradient(colorsSpace: space, colors: [tileTop, tileBottom] as CFArray, locations: [0, 1])!
cg.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 200), options: [])
let sheen = CGGradient(colorsSpace: space,
                       colors: [rgb(1, 1, 1, 0.35), rgb(1, 1, 1, 0)] as CFArray,
                       locations: [0, 1])!
cg.drawLinearGradient(sheen, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 100), options: [])
cg.restoreGState()

// --- Glyph: a plump studio microphone with grille slots ---
// Colours come from the command line so variants can be compared.
let capsule = CGPath(roundedRect: CGRect(x: 76, y: 34, width: 48, height: 80),
                     cornerWidth: 24, cornerHeight: 24, transform: nil)
let strokes = CGMutablePath()
strokes.addArc(center: CGPoint(x: 100, y: 92), radius: 38, startAngle: .pi, endAngle: 0, clockwise: true)
strokes.move(to: CGPoint(x: 100, y: 130)); strokes.addLine(to: CGPoint(x: 100, y: 152))
strokes.move(to: CGPoint(x: 80, y: 155)); strokes.addLine(to: CGPoint(x: 120, y: 155))
let stand = strokes.copy(strokingWithWidth: 12, lineCap: .round, lineJoin: .round, miterLimit: 10)
let glyph = CGMutablePath()
glyph.addPath(capsule)
glyph.addPath(stand)

// Grille: three short rounded slots cut into the capsule, showing the tile.
let slots = CGMutablePath()
for y in [58.0, 72.0, 86.0] {
    slots.addPath(CGPath(roundedRect: CGRect(x: 89, y: y - 3.5, width: 22, height: 7),
                         cornerWidth: 3.5, cornerHeight: 3.5, transform: nil))
}

cg.saveGState()
cg.translateBy(x: 100, y: 98)   // optical centre, a little larger
cg.scaleBy(x: 1.18, y: 1.18)
cg.translateBy(x: -100, y: -95)

// Base fill casts a soft shadow.
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: 5), blur: 7, color: shadowTint)
cg.addPath(glyph)
cg.setFillColor(rgb(1, 1, 1))
cg.fillPath(using: .winding)
cg.restoreGState()

// Gradient fill (white top → pale tint bottom) clipped to the glyph.
cg.saveGState()
cg.addPath(glyph)
cg.clip(using: .winding)
let glyphGrad = CGGradient(colorsSpace: space, colors: [rgb(1, 1, 1), glyphTint] as CFArray, locations: [0, 1])!
cg.drawLinearGradient(glyphGrad, start: CGPoint(x: 100, y: 34), end: CGPoint(x: 100, y: 160),
                      options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
cg.restoreGState()

// The slots take the tile colour at their height.
cg.saveGState()
cg.addPath(slots); cg.clip()
cg.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 200), options: [])
cg.restoreGState()

cg.restoreGState()

// --- Save PNG ---
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
