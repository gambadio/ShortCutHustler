// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ShortCutHustler",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ShortCutHustler", targets: ["App"])
    ],
    targets: [
        .executableTarget(
            name: "App",
            path: "Sources",
            // 🚫  Do not treat Info.plist as a resource; just keep it out of the build for now
            exclude: ["Info.plist"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon")           // for kVK_* constants
            ]
        )
    ]
)