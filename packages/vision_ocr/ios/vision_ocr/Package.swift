// swift-tools-version: 5.9

import PackageDescription

// Apple Vision OCR for Dokulo (DK-0397). iOS 16 is the app's minimum (docs/versions.md).
let package = Package(
    name: "vision_ocr",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .library(name: "vision-ocr", targets: ["vision_ocr"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "vision_ocr",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
