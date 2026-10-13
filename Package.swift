// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
// 6.0 (Xcode 16) is the minimum because the toolbar uses SwiftUI geometry APIs from the iOS 18 SDK,
// back-deployed to iOS 16. The sources still build in the Swift 5 language mode.

import PackageDescription

let package = Package(
    name: "TextEditor",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "TextEditor",
            targets: ["TextEditor"]),
    ],
    targets: [
        .target(
            name: "TextEditor"),
        .testTarget(
            name: "TextEditorTests",
            dependencies: ["TextEditor"]),
    ],
    swiftLanguageModes: [.v5]
)
