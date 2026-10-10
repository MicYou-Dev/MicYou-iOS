// swift-tools-version: 6.0
// SPDX-License-Identifier: GPL-3.0-or-later

import PackageDescription

// Pure Foundation so the wire format can be tested on Linux with `swift test`
let package = Package(
    name: "MicYouProtocol",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "MicYouProtocol", targets: ["MicYouProtocol"]),
    ],
    targets: [
        .target(name: "MicYouProtocol"),
        .testTarget(
            name: "MicYouProtocolTests",
            dependencies: ["MicYouProtocol"]
        ),
    ]
)
