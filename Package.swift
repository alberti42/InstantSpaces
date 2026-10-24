// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "InstantSpaces",
    platforms: [.macOS(.v26)],
    dependencies: [
        // Software updates. The Makefile embeds Sparkle.framework in the app.
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
    ],
    targets: [
        // Private SkyLight calls: symbol lookup and bridged window-management operations.
        .target(
            name: "SkyLightBridge",
            path: "Sources/SkyLightBridge"
        ),
        // Space model, navigation and the switch itself.
        .target(
            name: "InstantSpacesCore",
            dependencies: ["SkyLightBridge"],
            path: "Sources/InstantSpacesCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // The menu-bar app.
        .executableTarget(
            name: "InstantSpaces",
            dependencies: ["InstantSpacesCore", .product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/InstantSpaces",
            swiftSettings: [.swiftLanguageMode(.v5)],
            // SwiftPM sets no run path for Sparkle.framework. It lies next to the
            // executable in .build/debug, and in Contents/Frameworks of the app.
            linkerSettings: [.unsafeFlags([
                "-Xlinker", "-rpath", "-Xlinker", "@executable_path",
                "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks",
            ])]
        ),
        // Login item embedded in InstantSpaces.app/Contents/Library/LoginItems.
        .executableTarget(
            name: "LoginHelper",
            path: "Sources/LoginHelper",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "InstantSpacesCoreTests",
            dependencies: ["InstantSpacesCore"],
            path: "Tests/InstantSpacesCoreTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
