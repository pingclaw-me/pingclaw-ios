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
                // Syne — Bonjour Monde, OFL-licensed.
                // Variable font (weight axis 400–800) used for the PingClaw wordmark.
                .copy("Resources/Fonts"),
                // Apple-required privacy manifest (iOS 17+).
                .copy("Resources/PrivacyInfo.xcprivacy"),
                // Branding images for splash and main screens.
                .copy("Resources/Hero.png"),
                .copy("Resources/Wordmark.png"),
            ]
        ),
    ]
)
