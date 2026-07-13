// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LocalFlow",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "LocalFlow", targets: ["LocalFlow"]),
               .executable(name: "LocalFlowHarness", targets: ["LocalFlowHarness"])],
    targets: [
        .target(name: "DictationCore"),
        .executableTarget(name: "LocalFlow", dependencies: ["DictationCore"]),
        .executableTarget(name: "LocalFlowHarness", dependencies: ["DictationCore"], path: "Tests/MacHarness", exclude: ["README.md"]),
        .testTarget(name: "DictationCoreTests", dependencies: ["DictationCore"])
    ],
    swiftLanguageModes: [.v5]
)
