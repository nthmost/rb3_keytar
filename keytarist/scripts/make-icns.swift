// Build Resources/AppIcon.icns from icon-1024.png using ImageIO only (CLT-safe;
// `sips -s format icns` is unreliable and `iconutil` needs full Xcode).
// Usage: swift scripts/make-icns.swift <src-1024.png> <out.icns>
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
let srcPath = args.count > 1 ? args[1] : "icon-1024.png"
let outPath = args.count > 2 ? args[2] : "Resources/AppIcon.icns"

guard let srcImg = CGImageSourceCreateWithURL(URL(fileURLWithPath: srcPath) as CFURL, nil),
      let base = CGImageSourceCreateImageAtIndex(srcImg, 0, nil) else {
    FileHandle.standardError.write(Data("cannot read \(srcPath)\n".utf8)); exit(1)
}

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
func scaled(_ px: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                        bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(base, in: CGRect(x: 0, y: 0, width: px, height: px))
    return ctx.makeImage()!
}

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let url = URL(fileURLWithPath: outPath) as CFURL
guard let dest = CGImageDestinationCreateWithURL(url, "com.apple.icns" as CFString, sizes.count, nil) else {
    FileHandle.standardError.write(Data("cannot create destination\n".utf8)); exit(1)
}
for px in sizes { CGImageDestinationAddImage(dest, scaled(px), nil) }
if CGImageDestinationFinalize(dest) { print("wrote \(outPath)") }
else { FileHandle.standardError.write(Data("finalize failed\n".utf8)); exit(1) }
