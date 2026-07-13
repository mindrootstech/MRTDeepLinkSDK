// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MRTDeepLinkSDK",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "MRTDeepLinkSDK",
            type: .dynamic,
            targets: ["MRTDeepLinkSDK"]
        )
    ],
    targets: [
        .target(
            name: "MRTDeepLinkSDK",
            path: "MRTDeepLinkSDK",
            sources: ["Classes", "SwiftUI"]
        )
    ]
)
