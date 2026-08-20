// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CliqIt",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "CliqIt",
            type: .dynamic,
            targets: ["CliqIt"]
        )
    ],
    targets: [
        .target(
            name: "CliqIt",
            path: "CliqIt",
            sources: ["Classes", "SwiftUI"]
        )
    ]
)
