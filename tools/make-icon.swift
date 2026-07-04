#!/usr/bin/env swift
// Draws the SkillSwitch app icon: a steel breaker-panel squircle with one big
// armed rocker switch. Colors mirror Sources/SkillSwitch/Views/Theme.swift.
// Usage: swift tools/make-icon.swift <output.png>
import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
let canvas: CGFloat = 1024

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
}

// Theme palette
let steelTop = color(0.80, 0.81, 0.83)
let steelMid = color(0.70, 0.71, 0.74)
let steelBottom = color(0.58, 0.60, 0.63)
let steelEdge = color(0.36, 0.38, 0.41)
let interiorTop = color(0.13, 0.14, 0.16)
let interiorBottom = color(0.09, 0.10, 0.12)
let tapeBlack = color(0.07, 0.07, 0.09)
let safety = color(0.97, 0.78, 0.12)
let safetyLight = color(1.00, 0.86, 0.32)
let safetyDark = color(0.82, 0.63, 0.05)

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
), let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
    fputs("could not create bitmap\n", stderr)
    exit(1)
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx

// --- Faceplate: the macOS squircle, powder-coated steel -----------------
let plateRect = NSRect(x: 100, y: 100, width: 824, height: 824)
let plate = NSBezierPath(roundedRect: plateRect, xRadius: 186, yRadius: 186)

let shadow = NSShadow()
shadow.shadowColor = color(0, 0, 0, 0.35)
shadow.shadowOffset = NSSize(width: 0, height: -14)
shadow.shadowBlurRadius = 34
NSGraphicsContext.saveGraphicsState()
shadow.set()
steelMid.setFill()
plate.fill()
NSGraphicsContext.restoreGraphicsState()

NSGradient(colors: [steelTop, steelMid, steelBottom])!.draw(in: plate, angle: -90)
steelEdge.setStroke()
plate.lineWidth = 6
plate.stroke()

// --- Dead front: dark inner panel ----------------------------------------
let panelRect = plateRect.insetBy(dx: 76, dy: 76)
let panel = NSBezierPath(roundedRect: panelRect, xRadius: 122, yRadius: 122)
NSGradient(colors: [interiorTop, interiorBottom])!.draw(in: panel, angle: -90)
color(0, 0, 0, 0.6).setStroke()
panel.lineWidth = 5
panel.stroke()

// --- Hazard stripe band across the lower panel ---------------------------
let bandRect = NSRect(x: 262, y: 226, width: 500, height: 52)
let band = NSBezierPath(roundedRect: bandRect, xRadius: 26, yRadius: 26)
NSGraphicsContext.saveGraphicsState()
band.addClip()
safety.setFill()
bandRect.fill()
tapeBlack.setFill()
var x = bandRect.minX - 40
while x < bandRect.maxX + 40 {
    let stripe = NSBezierPath()
    stripe.move(to: NSPoint(x: x, y: bandRect.minY))
    stripe.line(to: NSPoint(x: x + 26, y: bandRect.minY))
    stripe.line(to: NSPoint(x: x + 26 + 20, y: bandRect.maxY))
    stripe.line(to: NSPoint(x: x + 20, y: bandRect.maxY))
    stripe.close()
    stripe.fill()
    x += 52
}
NSGraphicsContext.restoreGraphicsState()

// --- The breaker: black housing, big amber paddle flipped ON --------------
let housingRect = NSRect(x: 362, y: 330, width: 300, height: 430)
let housing = NSBezierPath(roundedRect: housingRect, xRadius: 58, yRadius: 58)
tapeBlack.setFill()
housing.fill()
color(1, 1, 1, 0.14).setStroke()
housing.lineWidth = 4
housing.stroke()

// OFF position marker (the empty bottom half)
let oRing = NSBezierPath(ovalIn: NSRect(x: 512 - 24, y: 386, width: 48, height: 48))
oRing.lineWidth = 9
color(1, 1, 1, 0.28).setStroke()
oRing.stroke()

// Amber paddle, up = armed
let paddleRect = NSRect(x: 388, y: 528, width: 248, height: 206)
let paddle = NSBezierPath(roundedRect: paddleRect, xRadius: 38, yRadius: 38)
NSGraphicsContext.saveGraphicsState()
let paddleShadow = NSShadow()
paddleShadow.shadowColor = color(0, 0, 0, 0.5)
paddleShadow.shadowOffset = NSSize(width: 0, height: -8)
paddleShadow.shadowBlurRadius = 14
paddleShadow.set()
safety.setFill()
paddle.fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(colors: [safetyLight, safety, safetyDark])!.draw(in: paddle, angle: -90)
color(0, 0, 0, 0.45).setStroke()
paddle.lineWidth = 5
paddle.stroke()

// glossy top edge of the paddle
let gloss = NSBezierPath(
    roundedRect: NSRect(x: paddleRect.minX + 22, y: paddleRect.maxY - 44, width: paddleRect.width - 44, height: 24),
    xRadius: 12, yRadius: 12
)
color(1, 1, 1, 0.32).setFill()
gloss.fill()

// bolt cut into the paddle
let bolt = NSBezierPath()
let bx: CGFloat = 512, by: CGFloat = 618, s: CGFloat = 0.62
func pt(_ dx: CGFloat, _ dy: CGFloat) -> NSPoint { NSPoint(x: bx + dx * s, y: by + dy * s) }
bolt.move(to: pt(14, 75))
bolt.line(to: pt(-52, -12))
bolt.line(to: pt(-8, -12))
bolt.line(to: pt(-20, -75))
bolt.line(to: pt(52, 14))
bolt.line(to: pt(6, 14))
bolt.close()
tapeBlack.withAlphaComponent(0.82).setFill()
bolt.fill()

// --- Corner screws ---------------------------------------------------------
for (sx, sy, angle) in [(206.0, 818.0, 20.0), (818.0, 818.0, 65.0), (206.0, 206.0, 80.0), (818.0, 206.0, 40.0)] {
    let r: CGFloat = 27
    let screwRect = NSRect(x: sx - r, y: sy - r, width: r * 2, height: r * 2)
    let screw = NSBezierPath(ovalIn: screwRect)
    NSGradient(colors: [steelTop, steelBottom])!.draw(in: screw, angle: -90)
    color(0, 0, 0, 0.4).setStroke()
    screw.lineWidth = 2.5
    screw.stroke()
    let cross = NSBezierPath()
    let rad = angle * .pi / 180
    for offset in [0.0, .pi / 2] {
        cross.move(to: NSPoint(x: sx + cos(rad + offset) * (r - 8), y: sy + sin(rad + offset) * (r - 8)))
        cross.line(to: NSPoint(x: sx - cos(rad + offset) * (r - 8), y: sy - sin(rad + offset) * (r - 8)))
    }
    cross.lineWidth = 5
    color(0, 0, 0, 0.5).setStroke()
    cross.stroke()
}

ctx.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("could not encode png\n", stderr)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: output))
print("wrote \(output)")
