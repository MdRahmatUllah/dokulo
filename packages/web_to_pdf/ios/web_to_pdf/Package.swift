// swift-tools-version: 5.9

import PackageDescription

// Web page to PDF for Dokulo (DK-0399). iOS 16 is the app's minimum (docs/versions.md).
let package = Package(
    name: "web_to_pdf",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .library(name: "web-to-pdf", targets: ["web_to_pdf"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "web_to_pdf",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
