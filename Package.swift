// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "InstantSpaces",
    platforms: [.macOS(.v26)],
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
            dependencies: ["InstantSpacesCore"],
            path: "Sources/InstantSpaces",
            swiftSettings: [.swiftLanguageMode(.v5)]
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
