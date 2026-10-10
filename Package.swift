// swift-tools-version: 6.0
// SPDX-License-Identifier: GPL-3.0-or-later

import PackageDescription

// lld records the deployment target as the SDK version unless told otherwise, and iOS
// then runs the app in compatibility mode without Liquid Glass. Keep in sync with the
// installed Darwin SDK (xtool sdk status)
let sdkVersion = "27.1"
let linkSDKVersion: [LinkerSetting] = [
    .unsafeFlags(["-Xlinker", "-platform_version", "-Xlinker", "ios", "-Xlinker", "18.0", "-Xlinker", sdkVersion]),
]

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
            ],
            linkerSettings: linkSDKVersion
        ),
        .target(
            name: "MicYouWidget",
            dependencies: ["MicYouShared"],
            linkerSettings: linkSDKVersion
        ),
    ]
)
