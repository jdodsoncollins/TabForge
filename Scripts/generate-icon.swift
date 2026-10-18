import AppKit
import Foundation

let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(calibratedWhite: 0.075, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
let glyphs = "{ }" as NSString
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 430, weight: .medium),
    .foregroundColor: NSColor(calibratedRed: 0.79, green: 0.94, blue: 0.48, alpha: 1)
]
let measured = glyphs.size(withAttributes: attributes)
glyphs.draw(at: NSPoint(x: (1024 - measured.width) / 2, y: (1024 - measured.height) / 2 + 24), withAttributes: attributes)
NSColor(calibratedRed: 0.79, green: 0.94, blue: 0.48, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 447, y: 215, width: 130, height: 28), xRadius: 4, yRadius: 4).fill()
NSGraphicsContext.restoreGraphicsState()
let output = URL(fileURLWithPath: "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
try bitmap.representation(using: .png, properties: [:])!.write(to: output)
