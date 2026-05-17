# DeckStringDecoderKMP

`DeckStringDecoderKMP` 是 `DeckStringDecoder` 的 Kotlin Multiplatform source repo，负责 KMP/SKIE 实现、测试、SwiftPM binary artifact 生成，以及发布到 public SwiftPM wrapper repo 的 CI 流程。

## 三仓关系

- `HS_DeckStringDecoder`：原 Swift source package 和迁移期 parity baseline，保留 `Package.swift`、`Sources/`、`Tests/`，不作为 KMP binary 发布入口。
- `DeckStringDecoderKMP`：KMP source of truth，包含 Kotlin common core、SKIE Swift facade、Gradle/KMP/SKIE 配置、KMP tests、SwiftPM binary local consumer verification、release CI。
- `DeckStringDecoderKMPPackage`：public SwiftPM binary wrapper，负责 `.binaryTarget(url:checksum:)`、GitHub Release asset、README/CHANGELOG/release notes、public consumer verification。

## iOS Demo 接入方式选择

本项目的 iOS demo 可能有三种接入诉求：验证已发布的 XCFramework、基于本地 KMP 源码进行联调、以及在 iOS app 中断点调试 Kotlin 代码。三种诉求对应不同的集成方式，不应混用。

### 1. Release XCFramework 消费

用于验证外部 iOS app 是否能像普通 SwiftPM 用户一样消费已发布的 KMP binary。

推荐位置：`DeckStringDecoderKMPPackage/Examples/iOSDemo`

接入方式：

- demo 依赖 `https://github.com/SunsetWan/DeckStringDecoderKMPPackage.git`
- wrapper repo 的 `Package.swift` 通过 `.binaryTarget(url:checksum:)` 指向 GitHub Release 中的 `DeckStringDecoder.xcframework.zip`
- demo 代码只使用 `import DeckStringDecoder` 和 Swift-facing API

该方式适合发布验收和外部使用示例，不适合断点调试 Kotlin 源码。

### 2. 本地 KMP 源码联调

用于让 iOS demo 在本地构建时从 `DeckStringDecoderKMP` 源码生成 framework。

推荐位置：`DeckStringDecoderKMP/ios_debug_demo`

Xcode Run Script 调用：

```sh
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
cd /Users/sunset/HS_APP/DeckStringDecoderKMP
./gradlew :deckstring:embedAndSignAppleFrameworkForXcode
```

该方式适合开发期联调 Kotlin 源码变更，但不证明 public SwiftPM release 已经可用。

### 3. 本地 KMP 源码断点调试

用于在 iOS demo 中触发 Swift-facing API，并断点进入 Kotlin/Native 代码。

固定位置：`DeckStringDecoderKMP/ios_debug_demo/DeckStringDecoderKMPDebugDemo`

打开工程：

```sh
open ios_debug_demo/DeckStringDecoderKMPDebugDemo/DeckStringDecoderKMPDebugDemo.xcodeproj
```

它基于“本地 KMP 源码联调”方式，额外要求：

- Xcode Build Settings 设置 `KOTLIN_FRAMEWORK_BUILD_TYPE=Debug`
- 使用 simulator 优先调试
- Run Script 放在 `Compile Sources` 前
- 关闭 `User Script Sandboxing`
- Kotlin 代码断点优先设置在 `deckstring/src/commonMain/kotlin/...`

详细的断点位置、Run Script 行为、LLDB 限制和本机验证记录见 `ios_debug_demo/README.md`。

可先验证 debug framework 能生成：

```sh
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  ./gradlew :deckstring:linkDebugFrameworkIosSimulatorArm64 --console=plain
```

Kotlin/Native 调试依赖 DWARF/LLDB。它支持断点和 step，但表达式求值体验不等同于 Swift 源码调试。

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

`.github/workflows/release.yml` 通过 `workflow_dispatch` 手动触发，输入 `release_tag`。release tag 固定使用：

```text
<semver>-kmp.<n>
```

版本号规则：

- `semver` 表示 Swift-facing API 版本。
- `kmp.N` 表示 KMP/SKIE binary artifact 发布序号。
- Swift API、platform、SwiftPM product/module 名不变时，只递增 `kmp.N`。
- API 兼容性新增时递增 minor，例如 `0.2.0-kmp.1`。
- API 破坏性变化在 `1.0.0` 前递增 minor；稳定后按 SemVer 递增 major。
- 文档-only 且不改变 artifact URL/checksum 时不发新版本。

当前 public wrapper 最新 release 是 `0.1.0-kmp.2`。本次 `DeckStringCore` parity/optimization 不改变 Swift-facing API、platform、SwiftPM product/module 名称，下一次真实 release tag 推荐为 `0.1.0-kmp.3`。

Release workflow 需要配置 secret：

```text
KMP_PACKAGE_REPO_TOKEN
```

该 token 需要能写入 `SunsetWan/DeckStringDecoderKMPPackage`，并能创建 tag 和 GitHub Release。workflow 会重新运行完整验证，生成 artifact，更新 wrapper repo 的 `Package.swift`、`README.md`、`CHANGELOG.md`、`releases/<tag>.md` 和 public consumer 验证配置，创建 wrapper repo release，上传 `DeckStringDecoder.xcframework.zip`，再从 public URL 下载 artifact 复算 checksum 并运行 public consumer tests。
