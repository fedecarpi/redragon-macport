// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "K589Config",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "K589Config", targets: ["K589Config"])
    ],
    targets: [
        .executableTarget(
            name: "K589Config",
            path: "Sources/K589Config",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
