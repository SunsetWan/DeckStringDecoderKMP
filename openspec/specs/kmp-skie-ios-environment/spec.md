# kmp-skie-ios-environment Specification

## Purpose
TBD - created by archiving change setup-kmp-skie-ios-environment. Update Purpose after archive.
## Requirements
### Requirement: 仓库内 Gradle 环境
仓库 SHALL 提供用于 KMP 工作的本地 Gradle 入口，包括 Gradle wrapper 文件、root Gradle 配置、Gradle properties，以及包含 `deckstring` module 的 settings。

#### Scenario: Gradle wrapper 不依赖全局 Gradle 即可验证
- **WHEN** `JAVA_HOME` 被设置为 `/Applications/Android Studio.app/Contents/jbr/Contents/Home`，并在仓库根目录运行 `./gradlew --version`
- **THEN** Gradle SHALL 成功报告版本，且不要求全局安装 `gradle` 命令

#### Scenario: Android Studio 打开现有仓库
- **WHEN** `/Applications/Android Studio.app/Contents/MacOS/studio /Users/sunset/HS_APP/DeckStringDecoder` 打开仓库
- **THEN** Android Studio SHALL 能够完成 Gradle project sync，并显示 `deckstring` KMP module

### Requirement: iOS-only KMP module 骨架
`deckstring` module SHALL 是 Kotlin Multiplatform module，且本阶段只配置 iOS Apple targets。

#### Scenario: iOS targets 已配置
- **WHEN** `deckstring` Gradle 配置被 evaluated
- **THEN** 它 SHALL 定义 `iosArm64`、`iosSimulatorArm64` 和 `iosX64` targets

#### Scenario: macOS targets 被排除
- **WHEN** 第一阶段 KMP skeleton 被 applied
- **THEN** 它 SHALL NOT 定义 `macosArm64` 或 `macosX64` targets

#### Scenario: iOS framework metadata 已配置
- **WHEN** 为 iOS targets 配置 Kotlin/Native framework binaries
- **THEN** 每个 framework SHALL 使用 `baseName = "DeckStringDecoder"`、`isStatic = true` 和 bundle id `com.sunsetwan.DeckStringDecoder`

### Requirement: KMP source-set placeholders
`deckstring` module SHALL contain Kotlin common code, bundled Swift code, and Kotlin common tests source-set structure. Kotlin common code MAY contain the migrated deckstring encoder, decoder, varint parser, and sideboard parser implementations. Bundled Swift code SHALL be allowed to contain the production Swift facade that SKIE compiles into the KMP framework, and that facade SHALL preserve the Swift-facing public API expected by existing `DeckStringDecoder` consumers.

#### Scenario: Source-set 目录存在
- **WHEN** KMP skeleton 被创建
- **THEN** `deckstring/src/commonMain/kotlin`、`deckstring/src/commonMain/swift` 和 `deckstring/src/commonTest/kotlin` SHALL 存在

#### Scenario: Source code 可构建
- **WHEN** 运行 `./gradlew :deckstring:tasks`
- **THEN** `deckstring` module SHALL 被识别，且其 Gradle tasks SHALL 成功列出

#### Scenario: Kotlin core migration is allowed
- **WHEN** 检查 `deckstring/src/commonMain/kotlin`
- **THEN** it MAY contain migrated deckstring core model, encoder, decoder, varint parser, and sideboard parser implementations

#### Scenario: Swift bundled facade 承载 public API
- **WHEN** 检查 `deckstring/src/commonMain/swift`
- **THEN** bundled Swift sources SHALL contain a production facade exposing `DeckFormat`、`Card`、`SideboardCard`、`Deck`、`DeckStringError` 和 `DeckStringDecoder`
- **THEN** the facade SHALL delegate decode and encode work to the Kotlin bridge inside the same SKIE-built framework

### Requirement: 最小 SKIE 集成
`deckstring` module SHALL 以最小稳定配置接入 SKIE，用于验证 bundled Swift 和 distributable iOS framework build。SKIE SHALL be used both for Swift Code Bundling and for distributable framework configuration.

#### Scenario: 默认使用已发布 SKIE plugin
- **WHEN** 运行 Gradle 时未设置本地 SKIE opt-in property
- **THEN** build SHALL 使用来自 Maven Central 的 pinned SKIE plugin version

#### Scenario: 本地 SKIE path 是 opt-in
- **WHEN** 未设置本地 SKIE development property
- **THEN** build SHALL NOT 依赖 `/Users/sunset/HS_APP/SKIE`

#### Scenario: SKIE distributable framework 支持已启用
- **WHEN** SKIE 配置被 evaluated
- **THEN** `produceDistributableFramework()` SHALL 已配置，且 SKIE analytics SHALL 被禁用
- **THEN** release/distributable framework build SHALL NOT rely on disabling Swift library evolution as the final distribution strategy

#### Scenario: Swift interface verification 不再被跳过
- **WHEN** 构建 release `DeckStringDecoder.xcframework`
- **THEN** build SHALL NOT require `-no-verify-emitted-module-interface` to hide Swift interface errors
- **THEN** generated `.swiftinterface` files SHALL remain in the produced XCFramework

#### Scenario: 不需要的 SKIE features 保持最小化
- **WHEN** SKIE 配置被 applied
- **THEN** coroutine、Flow、Combine 和 SwiftUI preview interop SHALL NOT 被引入为 required public surface
- **THEN** any enabled sealed、enum or function interop feature SHALL preserve the external Swift facade API

### Requirement: iOS framework build 验证
KMP module SHALL support generated iOS framework build verification for both local development and distributable release validation.

#### Scenario: Device framework 可 link
- **WHEN** 在仓库根目录运行 `./gradlew :deckstring:linkDebugFrameworkIosArm64`
- **THEN** Gradle SHALL 成功 link debug iOS arm64 framework

#### Scenario: XCFramework assembly path 可发现
- **WHEN** 列出 `deckstring` module 的 Gradle tasks
- **THEN** 可用的 XCFramework assembly task name SHALL 可被发现；当 configured plugins 生成 `:deckstring:assembleDeckStringDecoderReleaseXCFramework` 时使用该 task

#### Scenario: Release XCFramework 可未修补生成
- **WHEN** 在仓库根目录运行 `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :deckstring:assembleDeckStringDecoderReleaseXCFramework --console=plain`
- **THEN** Gradle SHALL 生成 release `DeckStringDecoder.xcframework`
- **THEN** the generated XCFramework SHALL include both device and simulator slices without post-build deletion of `.swiftinterface` files

### Requirement: 现有 Swift package 保持 source-based
本 change SHALL 保持当前 Swift package product、source layout、tests 和 public API behavior 不变。

#### Scenario: Package 保持 source target 形式
- **WHEN** apply 本 change 后检查 `Package.swift`
- **THEN** 它 SHALL 继续定义 source `.target(name: "DeckStringDecoder", dependencies: [])`，且 SHALL NOT 为 `DeckStringDecoder` 定义 `.binaryTarget`

#### Scenario: Swift public API source 保持不变
- **WHEN** 本 change 被 applied
- **THEN** `Sources/DeckStringDecoder/DeckStringDecoder.swift` SHALL 保留现有 public API declarations 和 behavior

#### Scenario: Swift package tests 仍通过
- **WHEN** 在仓库根目录运行 `swift test`
- **THEN** 现有 Swift test suite SHALL 通过

