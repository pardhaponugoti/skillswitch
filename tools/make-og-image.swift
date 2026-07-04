#!/usr/bin/env swift
// Renders the site's Open Graph card (1200×630) in the app's breaker-panel
// style. Usage: swift tools/make-og-image.swift docs/og/card.png
import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "card.png"
let width: CGFloat = 1200, height: CGFloat = 630

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
}
let wallTop = color(0.15, 0.16, 0.18)
let wallBottom = color(0.08, 0.08, 0.10)
let tapeBlack = color(0.07, 0.07, 0.09)
let safety = color(0.97, 0.78, 0.12)
let safetyLight = color(1.00, 0.86, 0.32)
let safetyDark = color(0.82, 0.63, 0.05)

func roundedFont(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    if let descriptor = base.fontDescriptor.withDesign(.rounded),
       let rounded = NSFont(descriptor: descriptor, size: size) {
        return rounded
    }
    return base
}

func draw(_ text: String, at point: NSPoint, font: NSFont, color: NSColor, kern: CGFloat = 0) {
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .kern: kern]
    NSAttributedString(string: text, attributes: attributes).draw(at: point)
}

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(width), pixelsHigh: Int(height),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
), let ctx = NSGraphicsContext(bitmapImageRep: rep) else { exit(1) }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx

// Wall
NSGradient(colors: [wallTop, wallBottom])!.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -90)

// Hazard stripe along the bottom
let band = NSRect(x: 0, y: 0, width: width, height: 26)
safety.setFill(); band.fill()
tapeBlack.setFill()
var x: CGFloat = -40
while x < width + 40 {
    let stripe = NSBezierPath()
    stripe.move(to: NSPoint(x: x, y: 0))
    stripe.line(to: NSPoint(x: x + 26, y: 0))
    stripe.line(to: NSPoint(x: x + 26 + 14, y: 26))
    stripe.line(to: NSPoint(x: x + 14, y: 26))
    stripe.close(); stripe.fill()
    x += 52
}

// Breaker on the left: black housing, amber paddle ON with bolt
let housing = NSRect(x: 110, y: 170, width: 250, height: 360)
let housingPath = NSBezierPath(roundedRect: housing, xRadius: 48, yRadius: 48)
tapeBlack.setFill(); housingPath.fill()
color(1, 1, 1, 0.14).setStroke(); housingPath.lineWidth = 4; housingPath.stroke()
let oRing = NSBezierPath(ovalIn: NSRect(x: housing.midX - 20, y: 215, width: 40, height: 40))
oRing.lineWidth = 8; color(1, 1, 1, 0.28).setStroke(); oRing.stroke()

let paddle = NSRect(x: housing.minX + 22, y: 335, width: housing.width - 44, height: 170)
let paddlePath = NSBezierPath(roundedRect: paddle, xRadius: 32, yRadius: 32)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = color(0, 0, 0, 0.5); shadow.shadowOffset = NSSize(width: 0, height: -7); shadow.shadowBlurRadius = 12
shadow.set(); safety.setFill(); paddlePath.fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(colors: [safetyLight, safety, safetyDark])!.draw(in: paddlePath, angle: -90)
color(0, 0, 0, 0.45).setStroke(); paddlePath.lineWidth = 4; paddlePath.stroke()

let bolt = NSBezierPath()
let bx = paddle.midX, by = paddle.midY
func pt(_ dx: CGFloat, _ dy: CGFloat) -> NSPoint { NSPoint(x: bx + dx * 0.55, y: by + dy * 0.55) }
bolt.move(to: pt(14, 75)); bolt.line(to: pt(-52, -12)); bolt.line(to: pt(-8, -12))
bolt.line(to: pt(-20, -75)); bolt.line(to: pt(52, 14)); bolt.line(to: pt(6, 14)); bolt.close()
tapeBlack.withAlphaComponent(0.82).setFill(); bolt.fill()

// Wordmark on a tape label
let tape = NSRect(x: 440, y: 380, width: 660, height: 110)
let tapePath = NSBezierPath(roundedRect: tape, xRadius: 14, yRadius: 14)
tapeBlack.setFill(); tapePath.fill()
draw("SKILLSWITCH", at: NSPoint(x: tape.minX + 38, y: tape.minY + 22),
     font: roundedFont(64, .black), color: .white, kern: 10)

// Tagline + mechanism line
draw("A BREAKER PANEL FOR YOUR CLAUDE", at: NSPoint(x: 444, y: 310),
     font: roundedFont(30, .heavy), color: safety, kern: 3)
draw("Arm a skill. It fires in your next chat.", at: NSPoint(x: 444, y: 240),
     font: roundedFont(28, .semibold), color: color(1, 1, 1, 0.75))
draw("Then the breaker trips off.", at: NSPoint(x: 444, y: 196),
     font: roundedFont(28, .semibold), color: color(1, 1, 1, 0.75))

// Footer line
draw("SKILLSWITCH.CC  ·  FREE  ·  OPEN SOURCE  ·  MACOS", at: NSPoint(x: 444, y: 92),
     font: roundedFont(20, .heavy), color: color(1, 1, 1, 0.4), kern: 2)

ctx.flushGraphics()
NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: URL(fileURLWithPath: output))
print("wrote \(output)")
