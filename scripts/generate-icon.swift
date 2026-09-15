// Original vector waveform artwork. No external assets, fonts, or photo inputs.
import AppKit
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 2 else { fatalError("usage: generate-icon OUTPUT_DIRECTORY") }
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
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
    let colors = [CGColor(red: 1, green: 0.39, blue: 0.25, alpha: 1),
                  CGColor(red: 0.91, green: 0.18, blue: 0.29, alpha: 1)] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0,1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: edge), end: CGPoint(x: edge, y: 0), options: [])
    context.setFillColor(CGColor(red: 1, green: 0.98, blue: 0.92, alpha: 1))
    for (index, fraction) in [0.16, 0.31, 0.49, 0.35, 0.20].enumerated() {
        let height = edge * fraction
        let bar = CGRect(x: edge * (0.245 + Double(index) * 0.112), y: (edge - height) / 2,
                         width: edge * 0.07, height: height)
        context.addPath(CGPath(roundedRect: bar, cornerWidth: edge * 0.035, cornerHeight: edge * 0.035, transform: nil))
        context.fillPath()
    }
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
