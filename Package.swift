// swift-tools-version: 6.0
// SPDX-License-Identifier: GPL-3.0-or-later

import PackageDescription

let package = Package(
    name: "MicYou",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        // xtool expects exactly one library product for the app, plus one per extension
        .library(name: "MicYou", targets: ["MicYou"]),
        .library(name: "MicYouWidget", targets: ["MicYouWidget"]),
    ],
    dependencies: [
        .package(path: "Packages/MicYouProtocol"),
    ],
    targets: [
        .target(
            name: "MicYouShared"
        ),
        .target(
            name: "MicYou",
            dependencies: [
                "MicYouShared",
                .product(name: "MicYouProtocol", package: "MicYouProtocol"),
            ]
        ),
        .target(
            name: "MicYouWidget",
            dependencies: ["MicYouShared"]
        ),
    ]
)
