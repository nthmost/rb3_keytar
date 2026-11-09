// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NeonDeco",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "NeonDeco", targets: ["NeonDeco"])
    ],
    targets: [
        .target(name: "NeonDeco", path: "Sources/NeonDeco")
    ]
)
