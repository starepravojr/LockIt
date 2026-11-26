import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Draws the LockIt icon: a padlock whose keyhole is a contactless-card signal.
// Not part of the app. To redraw the icon after editing this file:
//   swift Tools/make-icon.swift LockIt/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
// No alpha channel: iOS app icons must be opaque.
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// Work in top-left-origin coordinates.
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: 1, y: -1)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
    CGColor(colorSpace: space, components: [r, g, b, 1])!
}
let terracottaTop = color(0.831, 0.427, 0.310)
let terracottaBottom = color(0.659, 0.263, 0.173)
let cream = color(0.992, 0.969, 0.949)
let glyph = color(0.698, 0.298, 0.200)

// Background: a soft vertical gradient of the app's accent colour.
let gradient = CGGradient(colorsSpace: space, colors: [terracottaTop, terracottaBottom] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size), options: [])

let midX: CGFloat = 512

// Shackle.
let shackleRadius: CGFloat = 118
let shackleStroke: CGFloat = 68
let shackleCenterY: CGFloat = 360
let bodyTop: CGFloat = 440
ctx.setStrokeColor(cream)
ctx.setLineWidth(shackleStroke)
ctx.setLineCap(.butt)
let shackle = CGMutablePath()
shackle.move(to: CGPoint(x: midX - shackleRadius, y: bodyTop + 40))
shackle.addLine(to: CGPoint(x: midX - shackleRadius, y: shackleCenterY))
shackle.addArc(center: CGPoint(x: midX, y: shackleCenterY), radius: shackleRadius,
               startAngle: .pi, endAngle: 0, clockwise: false)
shackle.addLine(to: CGPoint(x: midX + shackleRadius, y: bodyTop + 40))
ctx.addPath(shackle)
ctx.strokePath()

// Body.
let body = CGRect(x: midX - 232, y: bodyTop, width: 464, height: 372)
ctx.setFillColor(cream)
ctx.addPath(CGPath(roundedRect: body, cornerWidth: 92, cornerHeight: 92, transform: nil))
ctx.fillPath()

// Keyhole: a dot sending out three contactless waves.
let waveOriginX = midX - 80
let waveY = body.midY
ctx.setFillColor(glyph)
ctx.fillEllipse(in: CGRect(x: waveOriginX - 26, y: waveY - 26, width: 52, height: 52))
ctx.setStrokeColor(glyph)
ctx.setLineWidth(32)
ctx.setLineCap(.round)
let spread: CGFloat = .pi * 0.26
for radius in [66, 118, 170] as [CGFloat] {
    ctx.addArc(center: CGPoint(x: waveOriginX, y: waveY), radius: radius,
               startAngle: -spread, endAngle: spread, clockwise: false)
    ctx.strokePath()
}

let image = ctx.makeImage()!
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(url.path)") }
print("wrote", url.path)
