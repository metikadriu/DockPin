import AppKit

guard CommandLine.arguments.count >= 2 else {
    fputs("usage: make_icon.swift <output.png>\n", stderr)
    exit(1)
}
let outputPath = CommandLine.arguments[1]

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// MARK: Background squircle with gradient

let cornerRadius: CGFloat = 225
let bgPath = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
                          xRadius: cornerRadius, yRadius: cornerRadius)

NSGraphicsContext.saveGraphicsState()
bgPath.addClip()

let bgGradient = NSGradient(colors: [
    NSColor(red: 0.18, green: 0.34, blue: 0.92, alpha: 1.0),
    NSColor(red: 0.52, green: 0.18, blue: 0.78, alpha: 1.0)
])!
bgGradient.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -55)

let highlight = NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.22),
    NSColor.white.withAlphaComponent(0)
])!
highlight.draw(fromCenter: NSPoint(x: size * 0.28, y: size * 0.82), radius: 0,
               toCenter: NSPoint(x: size * 0.28, y: size * 0.82),
               radius: size * 0.65, options: [])

NSGraphicsContext.restoreGraphicsState()

// MARK: Monitor

let monitorWidth: CGFloat = 680
let monitorHeight: CGFloat = 480
let monitorX = (size - monitorWidth) / 2
let monitorY: CGFloat = 240
let monitorRect = NSRect(x: monitorX, y: monitorY, width: monitorWidth, height: monitorHeight)

NSGraphicsContext.saveGraphicsState()
let monitorShadow = NSShadow()
monitorShadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
monitorShadow.shadowOffset = NSSize(width: 0, height: -14)
monitorShadow.shadowBlurRadius = 32
monitorShadow.set()
NSColor.white.setFill()
NSBezierPath(roundedRect: monitorRect, xRadius: 38, yRadius: 38).fill()
NSGraphicsContext.restoreGraphicsState()

// Screen inset
let screenRect = monitorRect.insetBy(dx: 26, dy: 26)
let screenPath = NSBezierPath(roundedRect: screenRect, xRadius: 20, yRadius: 20)
let screenGradient = NSGradient(colors: [
    NSColor(red: 0.96, green: 0.97, blue: 1.0, alpha: 1),
    NSColor(red: 0.90, green: 0.92, blue: 0.98, alpha: 1)
])!
screenGradient.draw(in: screenPath, angle: -90)

// Dock at bottom
let dockHeight: CGFloat = 78
let dockRect = NSRect(x: screenRect.minX + 55,
                       y: screenRect.minY + 28,
                       width: screenRect.width - 110,
                       height: dockHeight)
let dockPath = NSBezierPath(roundedRect: dockRect, xRadius: 22, yRadius: 22)

NSGraphicsContext.saveGraphicsState()
let dockShadow = NSShadow()
dockShadow.shadowColor = NSColor.black.withAlphaComponent(0.12)
dockShadow.shadowOffset = NSSize(width: 0, height: -3)
dockShadow.shadowBlurRadius = 8
dockShadow.set()
NSColor.white.setFill()
dockPath.fill()
NSGraphicsContext.restoreGraphicsState()

NSColor(white: 0.80, alpha: 1).setStroke()
dockPath.lineWidth = 2
dockPath.stroke()

// Dock app dots
let dotCount = 5
let dotSize: CGFloat = 42
let dotSpacing = dockRect.width / CGFloat(dotCount + 1)
let dotColors: [NSColor] = [
    NSColor(red: 0.28, green: 0.62, blue: 1.00, alpha: 1),
    NSColor(red: 0.38, green: 0.85, blue: 0.50, alpha: 1),
    NSColor(red: 1.00, green: 0.68, blue: 0.20, alpha: 1),
    NSColor(red: 0.96, green: 0.32, blue: 0.42, alpha: 1),
    NSColor(red: 0.62, green: 0.48, blue: 0.96, alpha: 1)
]
for i in 0..<dotCount {
    let cx = dockRect.minX + dotSpacing * CGFloat(i + 1)
    let cy = dockRect.midY
    let dotRect = NSRect(x: cx - dotSize/2, y: cy - dotSize/2,
                         width: dotSize, height: dotSize)
    dotColors[i].setFill()
    NSBezierPath(ovalIn: dotRect).fill()
}

// MARK: Pushpin overlaid on the upper-right of the monitor

let pinHeadCenter = NSPoint(x: monitorRect.maxX - 60, y: monitorRect.maxY - 50)
let pinHeadRadius: CGFloat = 118

// Needle going diagonally down-left into the monitor's screen area
let needleTipLength: CGFloat = 200
let needleAngle: CGFloat = .pi * 1.25  // points down-left
let needleTip = NSPoint(
    x: pinHeadCenter.x + cos(needleAngle) * needleTipLength,
    y: pinHeadCenter.y + sin(needleAngle) * needleTipLength
)
let needleBaseHalfWidth: CGFloat = 38
let perpAngle = needleAngle + .pi / 2
let base1 = NSPoint(
    x: pinHeadCenter.x + cos(perpAngle) * needleBaseHalfWidth,
    y: pinHeadCenter.y + sin(perpAngle) * needleBaseHalfWidth
)
let base2 = NSPoint(
    x: pinHeadCenter.x - cos(perpAngle) * needleBaseHalfWidth,
    y: pinHeadCenter.y - sin(perpAngle) * needleBaseHalfWidth
)

NSGraphicsContext.saveGraphicsState()
let pinShadow = NSShadow()
pinShadow.shadowColor = NSColor.black.withAlphaComponent(0.40)
pinShadow.shadowOffset = NSSize(width: -4, height: -10)
pinShadow.shadowBlurRadius = 22
pinShadow.set()

let needlePath = NSBezierPath()
needlePath.move(to: base1)
needlePath.line(to: needleTip)
needlePath.line(to: base2)
needlePath.close()
let needleGradient = NSGradient(colors: [
    NSColor(white: 0.92, alpha: 1),
    NSColor(white: 0.60, alpha: 1)
])!
needleGradient.draw(in: needlePath, angle: 35)

// Pin head (red orb)
let pinHeadRect = NSRect(
    x: pinHeadCenter.x - pinHeadRadius,
    y: pinHeadCenter.y - pinHeadRadius,
    width: pinHeadRadius * 2,
    height: pinHeadRadius * 2
)
let pinHeadPath = NSBezierPath(ovalIn: pinHeadRect)
let pinGradient = NSGradient(colors: [
    NSColor(red: 1.00, green: 0.52, blue: 0.48, alpha: 1),
    NSColor(red: 0.82, green: 0.14, blue: 0.22, alpha: 1)
])!
pinGradient.draw(in: pinHeadPath, angle: -90)

NSGraphicsContext.restoreGraphicsState()

// Specular highlight on the pin head
let hl = NSRect(
    x: pinHeadCenter.x - pinHeadRadius * 0.55,
    y: pinHeadCenter.y + pinHeadRadius * 0.10,
    width: pinHeadRadius * 0.70,
    height: pinHeadRadius * 0.45
)
NSColor.white.withAlphaComponent(0.50).setFill()
NSBezierPath(ovalIn: hl).fill()

// Tiny secondary highlight
let hl2 = NSRect(
    x: pinHeadCenter.x - pinHeadRadius * 0.18,
    y: pinHeadCenter.y - pinHeadRadius * 0.55,
    width: pinHeadRadius * 0.22,
    height: pinHeadRadius * 0.14
)
NSColor.white.withAlphaComponent(0.25).setFill()
NSBezierPath(ovalIn: hl2).fill()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}
do {
    try png.write(to: URL(fileURLWithPath: outputPath))
    print("Wrote \(outputPath)")
} catch {
    fputs("Write failed: \(error)\n", stderr)
    exit(1)
}
