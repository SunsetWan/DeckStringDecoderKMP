# DeckStringDecoderKMP

`DeckStringDecoderKMP` 是 `DeckStringDecoder` 的 Kotlin Multiplatform source repo，负责 KMP/SKIE 实现、测试、SwiftPM binary artifact 生成，以及发布到 public SwiftPM wrapper repo 的 CI 流程。

## 三仓关系

- `HS_DeckStringDecoder`：原 Swift source package 和迁移期 parity baseline，保留 `Package.swift`、`Sources/`、`Tests/`，不作为 KMP binary 发布入口。
- `DeckStringDecoderKMP`：KMP source of truth，包含 Kotlin common core、SKIE Swift facade、Gradle/KMP/SKIE 配置、KMP tests、SwiftPM binary local consumer verification、release CI。
- `DeckStringDecoderKMPPackage`：public SwiftPM binary wrapper，负责 `.binaryTarget(url:checksum:)`、GitHub Release asset、README/CHANGELOG/release notes、public consumer verification。

## 常用命令

本机如果 shell 找不到 Java，可使用 Android Studio JBR：

```sh
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
```

验证 OpenSpec specs：

```sh
openspec validate --specs --strict
```

运行 KMP iOS simulator tests：

```sh
./gradlew :deckstring:iosSimulatorArm64Test --console=plain
```

生成 SwiftPM binary release artifact 和 checksum：

```sh
./gradlew :deckstring:prepareDeckStringDecoderSwiftPMBinaryRelease --console=plain
```

验证 artifact 结构与 checksum：

```sh
scripts/verify-swiftpm-artifact.sh \
  deckstring/build/swiftpm-binary/DeckStringDecoder.xcframework.zip \
  deckstring/build/swiftpm-binary/DeckStringDecoder.xcframework.zip.checksum
```

运行 local SwiftPM binary consumer tests：

```sh
./gradlew :deckstring:verifyDeckStringDecoderSwiftPMConsumer --console=plain
```

如本机或 CI 没有 `iPhone 17` simulator，可指定：

```sh
IOS_SIMULATOR_DESTINATION="platform=iOS Simulator,name=iPhone 16 Pro" \
  ./gradlew :deckstring:verifyDeckStringDecoderSwiftPMConsumer --console=plain
```

## CI

`.github/workflows/ci.yml` 在 `push`、`pull_request`、`workflow_dispatch` 上运行：

- `openspec validate --specs --strict`
- `:deckstring:iosSimulatorArm64Test`
- `:deckstring:prepareDeckStringDecoderSwiftPMBinaryRelease`
- `scripts/verify-swiftpm-artifact.sh`
- `:deckstring:verifyDeckStringDecoderSwiftPMConsumer`
- 上传 `DeckStringDecoder.xcframework.zip` 和 `.checksum`

## Release

`.github/workflows/release.yml` 通过 `workflow_dispatch` 手动触发，输入 `release_tag`，例如 `0.1.0-kmp.2`。

Release workflow 需要配置 secret：

```text
KMP_PACKAGE_REPO_TOKEN
```

该 token 需要能写入 `SunsetWan/DeckStringDecoderKMPPackage`，并能创建 tag 和 GitHub Release。workflow 会重新运行完整验证，生成 artifact，更新 wrapper repo 的 `Package.swift`、`README.md`、`CHANGELOG.md`、`releases/<tag>.md` 和 public consumer 验证配置，创建 wrapper repo release，上传 `DeckStringDecoder.xcframework.zip`，再从 public URL 下载 artifact 复算 checksum 并运行 public consumer tests。
