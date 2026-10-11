// swift-tools-version: 6.0
// SPDX-License-Identifier: GPL-3.0-or-later

import PackageDescription

// The linker records the deployment target as the SDK version unless told otherwise, on Linux
// and on macOS alike under xtool, and iOS then runs the app in compatibility mode without
// Liquid Glass. Defaults to the installed Darwin SDK (xtool sdk status), CI passes the SDK of
// the Xcode it selected through MICYOU_IOS_SDK_VERSION
let sdkVersion = Context.environment["MICYOU_IOS_SDK_VERSION"] ?? "27.1"
let linkSDKVersion: [LinkerSetting] = [
    .unsafeFlags(["-Xlinker", "-platform_version", "-Xlinker", "ios", "-Xlinker", "18.0", "-Xlinker", sdkVersion]),
]

// xtool links extensions with -e _NSExtensionMain, which leaves the SwiftUI @main widget
// bundle unreferenced so it is dead stripped. Keep main alive, NSExtensionMain calls it
let widgetEntryPoint: [LinkerSetting] = [
    .unsafeFlags(["-Xlinker", "-u", "-Xlinker", "_main"]),
]

// Release builds leave out local symbols and debug info, which take more than half of the
// binary. Crash reports then show addresses for app frames, debug builds keep their symbols
let stripSymbols: [LinkerSetting] = [
    .unsafeFlags(["-Xlinker", "-x", "-Xlinker", "-S"], .when(configuration: .release)),
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
        .package(path: "Packages/MicYouCore"),
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
                .product(name: "MicYouCore", package: "MicYouCore"),
            ],
            linkerSettings: linkSDKVersion + stripSymbols
        ),
        .target(
            name: "MicYouWidget",
            dependencies: ["MicYouShared"],
            linkerSettings: linkSDKVersion + widgetEntryPoint + stripSymbols
        ),
    ]
)
