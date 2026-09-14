// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LocalFlow",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "LocalFlow", targets: ["LocalFlow"])],
    targets: [.executableTarget(name: "LocalFlow")]
)
