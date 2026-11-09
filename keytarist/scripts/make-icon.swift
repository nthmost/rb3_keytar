import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let S: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
func cg(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [
        CGFloat((hex >> 16) & 0xff) / 255,
        CGFloat((hex >> 8) & 0xff) / 255,
        CGFloat(hex & 0xff) / 255, a])!
}
// Palette (NeonDeco)
let ground: UInt32 = 0x0d0b1a, pink: UInt32 = 0xff3d81, teal: UInt32 = 0x2ee6e6
let violet: UInt32 = 0xc77dff, brass: UInt32 = 0xffb454, ink: UInt32 = 0xe4e0f2

let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8,
                    bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// Rounded app tile + clip
let inset: CGFloat = 72
let tile = CGRect(x: inset, y: inset, width: S - 2 * inset, height: S - 2 * inset)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 205, cornerHeight: 205, transform: nil)
ctx.saveGState()
ctx.addPath(tilePath); ctx.clip()

// Background gradient (top wash -> night)
let bg = CGGradient(colorsSpace: cs, colors: [cg(0x2a1d52), cg(ground)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 952), end: CGPoint(x: 512, y: 72), options: [])

let horizon: CGFloat = 372

// Synthwave sun (above horizon, behind keys)
let sunC = CGPoint(x: 512, y: 648), sunR: CGFloat = 196
ctx.saveGState()
ctx.addEllipse(in: CGRect(x: sunC.x - sunR, y: sunC.y - sunR, width: sunR * 2, height: sunR * 2))
ctx.clip()
let sunGrad = CGGradient(colorsSpace: cs,
    colors: [cg(brass), cg(pink), cg(violet)] as CFArray, locations: [0, 0.5, 1])!
ctx.drawLinearGradient(sunGrad, start: CGPoint(x: 512, y: sunC.y - sunR),
                       end: CGPoint(x: 512, y: sunC.y + sunR), options: [])
// Occluding bands on the lower half (classic retro sun)
var by = sunC.y - 18
var gap: CGFloat = 14
for _ in 0..<5 {
    ctx.setFillColor(cg(ground))
    ctx.fill(CGRect(x: sunC.x - sunR, y: by, width: sunR * 2, height: gap))
    by -= gap + 26
    gap += 5
}
ctx.restoreGState()

// Outrun grid floor (below horizon)
ctx.setLineCap(.round)
let vp = CGPoint(x: 512, y: horizon)
// converging verticals
for i in -6...6 {
    let bx = 512 + CGFloat(i) * 150
    ctx.move(to: vp)
    ctx.addLine(to: CGPoint(x: bx, y: 90))
    ctx.setStrokeColor(cg(violet, 0.55)); ctx.setLineWidth(3)
    ctx.strokePath()
}
// horizontals getting denser toward horizon
var hy: CGFloat = 96
var hstep: CGFloat = 16
while hy < horizon - 4 {
    ctx.move(to: CGPoint(x: 120, y: hy))
    ctx.addLine(to: CGPoint(x: 904, y: hy))
    ctx.setStrokeColor(cg(teal, 0.42)); ctx.setLineWidth(2.5)
    ctx.strokePath()
    hy += hstep; hstep *= 1.34
}

// Piano keys (the hero), sitting on the horizon
let nWhite = 8
let wW: CGFloat = 58, wH: CGFloat = 196
let startX = 512 - CGFloat(nWhite) * wW / 2
let keyTop = horizon + wH, keyBot = horizon
let glowWhite = 0   // leftmost white glows teal
func roundedKey(_ r: CGRect, _ rad: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)
}
// white keys
for i in 0..<nWhite {
    let r = CGRect(x: startX + CGFloat(i) * wW + 2, y: keyBot, width: wW - 4, height: wH)
    let p = roundedKey(r, 9)
    if i == glowWhite {
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 44, color: cg(teal, 0.95))
        ctx.addPath(p); ctx.setFillColor(cg(teal)); ctx.fillPath()
        ctx.restoreGState()
    } else {
        ctx.addPath(p); ctx.setFillColor(cg(ink)); ctx.fillPath()
    }
}
_ = keyTop
// black keys after white indices 0,1,3,4,5 ; the one after index 4 glows pink
let blackAfter = [0, 1, 3, 4, 5]
let glowBlack = 4
let bW: CGFloat = 38, bH: CGFloat = 116
for idx in blackAfter {
    let cx = startX + CGFloat(idx + 1) * wW
    let r = CGRect(x: cx - bW / 2, y: keyBot + wH - bH, width: bW, height: bH)
    let p = roundedKey(r, 7)
    if idx == glowBlack {
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 40, color: cg(pink, 0.95))
        ctx.addPath(p); ctx.setFillColor(cg(pink)); ctx.fillPath()
        ctx.restoreGState()
    } else {
        ctx.addPath(p); ctx.setFillColor(cg(0x0b0a16)); ctx.fillPath()
    }
}

ctx.restoreGState()   // undo tile clip

// Brass deco border
ctx.addPath(tilePath)
ctx.setStrokeColor(cg(brass, 0.85)); ctx.setLineWidth(8)
ctx.strokePath()

// Write PNG
let img = ctx.makeImage()!
let url = URL(fileURLWithPath: "/tmp/keytarist_icon.png") as CFURL
let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil)
if CGImageDestinationFinalize(dest) { print("wrote /tmp/keytarist_icon.png") } else { print("FAILED") }
