// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DeckStringDecoderBinaryConsumer",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "DeckStringDecoderBinaryConsumer",
            targets: ["DeckStringDecoderBinaryConsumer"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "DeckStringDecoder",
            path: "Artifacts/DeckStringDecoder.xcframework.zip"
        ),
        .target(
            name: "DeckStringDecoderBinaryConsumer",
            dependencies: ["DeckStringDecoder"]
        ),
        .testTarget(
            name: "DeckStringDecoderBinaryConsumerTests",
            dependencies: [
                "DeckStringDecoder",
                "DeckStringDecoderBinaryConsumer",
            ]
        ),
    ]
)
