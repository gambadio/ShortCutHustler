// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "ShortCutHustler",
  platforms: [.macOS(.v13)], // Or your target macOS version
  products: [
    .executable(name: "ShortCutHustler", targets: ["App"])
  ],
  targets: [
    .executableTarget(
      name: "App",
      path: "Sources/App",
      resources: [
        .copy("../Info.plist") // Ensure Info.plist is at Sources/Info.plist relative to Package.swift or adjust path
      ],
      linkerSettings: [
        .linkedFramework("AppKit"),
        .linkedFramework("SwiftUI"),
        .linkedFramework("ApplicationServices"),
        .linkedFramework("Carbon") // For kVK constants and UCKeyTranslate if not implicitly linked
      ]
    )
  ]
)