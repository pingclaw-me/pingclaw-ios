// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PingClaw",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "PingClaw",
            targets: ["PingClaw"]
        ),
    ],
    targets: [
        .target(
            name: "PingClaw",
            resources: [
                // Fonts — Fraunces (display), Inter Tight (body), JetBrains Mono (values).
                // All variable weight, OFL-licensed.
                .copy("Resources/Fonts"),
                // Apple-required privacy manifest (iOS 17+).
                .copy("Resources/PrivacyInfo.xcprivacy"),
            ]
        ),
    ]
)
