// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProgressCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "ProgressCore", targets: ["ProgressCore"]),
    ],
    targets: [
        .target(name: "ProgressCore"),
        .testTarget(name: "ProgressCoreTests", dependencies: ["ProgressCore"]),
    ]
)
