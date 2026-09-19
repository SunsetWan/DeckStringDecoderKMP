// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DeckStringDecoderKMPPackage",
    platforms: [.iOS(.v15), .macOS(.v14)],
    products: [
        .library(name: "DeckStringModels", targets: ["DeckStringModels"]),
        .library(name: "DeckStringDecoder", targets: ["DeckStringDecoder"]),
    ],
    targets: [
        .binaryTarget(name: "DeckStringRuntime", path: "Artifacts/DeckStringRuntime.xcframework.zip"),
        .target(name: "DeckStringModels"),
        .target(name: "DeckStringDecoder", dependencies: [
            "DeckStringModels",
            .target(name: "DeckStringRuntime", condition: .when(platforms: [.iOS])),
        ]),
        .testTarget(name: "DeckStringModelsTests", dependencies: ["DeckStringModels"]),
        .testTarget(name: "DeckStringDecoderTests", dependencies: ["DeckStringDecoder"]),
    ],
    swiftLanguageModes: [.v5]
)
