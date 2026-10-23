// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "OneByOne",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "OneByOneCore"),
        .executableTarget(name: "OneByOne", dependencies: ["OneByOneCore"]),
        .testTarget(name: "OneByOneCoreTests", dependencies: ["OneByOneCore"]),
    ]
)
