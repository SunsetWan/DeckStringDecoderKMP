// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DeckStringDecoder",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "DeckStringDecoder",
            targets: ["DeckStringDecoder"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "DeckStringDecoder",
            url: "https://github.com/SunsetWan/DeckStringDecoderKMPPackage/releases/download/0.1.0-kmp.1/DeckStringDecoder.xcframework.zip",
            checksum: "f4e918c615c3da0667f2e5c747ce798521c313fd03eee099a47a39972cd9de17"
        ),
    ]
)
