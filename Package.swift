// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

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
    ]
)
