// swift-tools-version: 6.0
// SPDX-License-Identifier: GPL-3.0-or-later

import PackageDescription

// App logic without Apple frameworks, so it can be tested on Linux with `swift test`
let package = Package(
    name: "MicYouCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v15),
    ],
    products: [
        .library(name: "MicYouCore", targets: ["MicYouCore"]),
    ],
    dependencies: [
        .package(path: "../MicYouProtocol"),
    ],
    targets: [
        .target(
            name: "MicYouCore",
            dependencies: [.product(name: "MicYouProtocol", package: "MicYouProtocol")]
        ),
        .testTarget(
            name: "MicYouCoreTests",
            dependencies: ["MicYouCore"]
        ),
    ]
)
