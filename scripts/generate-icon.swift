// Exact-photo icon conversion. ImageIO applies orientation; new PNG contexts
// retain pixels only, without copying the source photograph's metadata.
import AppKit
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else { fatalError("usage: generate-icon INPUT_IMAGE OUTPUT_DIRECTORY") }
let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let photo = CGImageSourceCreateThumbnailAtIndex(source, 0, [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: 4096
      ] as CFDictionary) else { fatalError("Cannot decode the supplied image") }
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let iconset = output.appendingPathComponent("LocalFlow.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(_ size: Int, to url: URL) throws {
    guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                                  bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("Cannot create pixels") }
    let edge = CGFloat(size)
    let inset = edge * 0.055
    let area = CGRect(x: inset, y: inset, width: edge - 2 * inset, height: edge - 2 * inset)
    context.addPath(CGPath(roundedRect: area, cornerWidth: edge * 0.20, cornerHeight: edge * 0.20, transform: nil))
    context.clip()
    let scale = max(area.width / CGFloat(photo.width), area.height / CGFloat(photo.height))
    let width = CGFloat(photo.width) * scale
    let height = CGFloat(photo.height) * scale
    context.interpolationQuality = .high
    context.draw(photo, in: CGRect(x: (edge - width) / 2, y: (edge - height) / 2, width: width, height: height))
    guard let bitmap = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Cannot encode icon")
    }
    CGImageDestinationAddImage(destination, bitmap, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Cannot save icon") }
    // ImageIO may add fresh EXIF dimensions. Keep only pixels and sRGB; no
    // ancillary metadata, including any future default encoder metadata, ships.
    let encoded = try Data(contentsOf: url)
    var clean = encoded.prefix(8)
    var offset = 8
    while offset + 12 <= encoded.count {
        let length = encoded[offset..<(offset + 4)].reduce(0) { ($0 << 8) | Int($1) }
        let end = offset + 12 + length
        guard end <= encoded.count else { fatalError("Invalid encoded PNG") }
        let type = String(decoding: encoded[(offset + 4)..<(offset + 8)], as: UTF8.self)
        if ["IHDR", "IDAT", "IEND", "sRGB"].contains(type) { clean.append(encoded[offset..<end]) }
        offset = end
    }
    try clean.write(to: url)
}

for size in [16, 32, 128, 256, 512] {
    try render(size, to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2, to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
try render(1024, to: output.appendingPathComponent("LocalFlow.png"))
