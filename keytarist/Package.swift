// swift-tools-version:5.9
import PackageDescription

// The SPM product is always named "App"; the bundling script renames the
// executable to the app's display name when it assembles the .app.
let package = Package(
    name: "Keytarist",
    platforms: [.macOS(.v13)],
    dependencies: [
        // "Synthwave art deco circuits" design system — vendored snapshot from
        // nthmost-systems/macapp/packages/NeonDeco (update manually if it evolves).
        .package(path: "NeonDeco")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [.product(name: "NeonDeco", package: "NeonDeco")],
            path: "Sources/App",
            linkerSettings: [
                // IOHIDManager lives in IOKit; must be linked explicitly for SPM.
                .linkedFramework("IOKit")
            ]
        )
    ]
)
