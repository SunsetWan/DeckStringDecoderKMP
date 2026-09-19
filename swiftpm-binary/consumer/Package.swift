// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DeckStringDecoderBinaryConsumer",
    platforms: [.iOS(.v16)],
    products: [.library(name: "DeckStringDecoderBinaryConsumer", targets: ["DeckStringDecoderBinaryConsumer"])],
    dependencies: [.package(path: "..")],
    targets: [
        .target(
            name: "DeckStringDecoderBinaryConsumer",
            dependencies: [.product(name: "DeckStringDecoder", package: "swiftpm-binary")]
        ),
        .testTarget(name: "DeckStringDecoderBinaryConsumerTests", dependencies: ["DeckStringDecoderBinaryConsumer"]),
    ]
)
