## ADDED Requirements

### Requirement: iOS debug demo lives in the KMP source repo
项目 SHALL 在 KMP source repo 内提供用于本地 Kotlin/Native 断点调试的 iOS demo，固定路径为 `ios_debug_demo/`。

#### Scenario: Debug demo path is canonical
- **WHEN** 开发者查找本地 KMP 源码断点调试 demo
- **THEN** demo SHALL 位于 `DeckStringDecoderKMP/ios_debug_demo/`
- **THEN** demo app SHALL 命名为 `DeckStringDecoderKMPDebugDemo`
- **THEN** demo deployment target SHALL 为 iOS 15

#### Scenario: Old demo path is not reused
- **WHEN** 本 change 实现完成
- **THEN** 仓库根目录 SHALL NOT 使用 `DeckStringDecoderKMPDemo/` 作为当前 debug demo 路径
- **THEN** 新的 debug demo SHALL 从 `ios_debug_demo/` 重新建立

#### Scenario: Debug demo is not a release consumer demo
- **WHEN** 检查 `ios_debug_demo/` 的依赖来源
- **THEN** demo SHALL NOT 依赖 `DeckStringDecoderKMPPackage`
- **THEN** demo SHALL NOT 通过 GitHub Release zip 或 public SwiftPM `.binaryTarget` 消费 `DeckStringDecoder`
- **THEN** demo SHALL 从本地 KMP source repo 构建 Debug framework

### Requirement: Xcode debug build embeds local KMP framework
`ios_debug_demo` SHALL 通过 Xcode Run Script 调用 Gradle 的本地 KMP framework 集成 task，使 Xcode Debug build 能生成并嵌入本地 Debug framework。

#### Scenario: Debug framework build type is explicit
- **WHEN** `DeckStringDecoderKMPDebugDemo` 使用 Debug configuration 构建
- **THEN** Xcode build settings SHALL 设置 `KOTLIN_FRAMEWORK_BUILD_TYPE=Debug`

#### Scenario: Gradle embed task is wired before Swift compilation
- **WHEN** `DeckStringDecoderKMPDebugDemo` build phases 被检查
- **THEN** Run Script build phase SHALL 位于 `Compile Sources` 前
- **THEN** Run Script SHALL 调用 `./gradlew :deckstring:embedAndSignAppleFrameworkForXcode --console=plain`
- **THEN** Run Script SHALL 从 `ios_debug_demo/` 回到 repo root 后运行 Gradle

#### Scenario: Java and script sandbox requirements are documented
- **WHEN** Run Script 运行 Gradle
- **THEN** 它 SHALL 支持使用 `/Applications/Android Studio.app/Contents/jbr/Contents/Home` 作为默认 `JAVA_HOME`
- **THEN** demo target SHALL 关闭 `User Script Sandboxing`

### Requirement: Demo triggers Swift-facing API for Kotlin breakpoints
demo SHALL 提供稳定的 Swift-facing API 调试入口，用于从 Xcode app flow 触发 Kotlin common core 的 decode 和 encode 路径。

#### Scenario: Decode workflow is available
- **WHEN** 开发者运行 demo 并触发标准 deck decode
- **THEN** Swift code SHALL 调用 `DeckStringDecoder().decode(_:)`
- **THEN** demo SHALL 展示 decode 后的 format、hero、card count 或 sideboard count

#### Scenario: Encode round trip workflow is available
- **WHEN** 开发者运行 demo 并触发 encode round-trip
- **THEN** Swift code SHALL 对 decode 后的 `Deck` 调用 `DeckStringDecoder().encode(_:)`
- **THEN** demo SHALL 展示 round-trip 是否成功

#### Scenario: Error mapping workflow is available
- **WHEN** 开发者运行 demo 并触发 invalid input
- **THEN** Swift code SHALL 通过 Swift-facing API 接收并展示 `DeckStringError`

#### Scenario: Kotlin bridge types stay internal to the framework
- **WHEN** 检查 demo Swift sources
- **THEN** demo SHALL import `DeckStringDecoder`
- **THEN** demo SHALL NOT 直接引用 `KmpDeck`、`DecodeResult`、`EncodeResult` 或 `DeckStringCodecBridge`

### Requirement: Kotlin/Native debug workflow is documented and verified
项目 SHALL 记录本地 Xcode 调试 Kotlin/Native 的实际步骤、限制和验证结果。

#### Scenario: Debug documentation exists
- **WHEN** 开发者阅读 `ios_debug_demo/README.md`
- **THEN** 文档 SHALL 说明如何打开 Xcode project、选择 simulator、设置 Kotlin 源码断点并触发 demo workflow
- **THEN** 文档 SHALL 推荐优先在 `deckstring/src/commonMain/kotlin/com/sunsetwan/deckstring/DeckStringCore.kt` 的 `DeckStringCodecBridge.decode` 或 `DeckStringCodecBridge.encode` 设置断点

#### Scenario: LLDB limitations are stated
- **WHEN** 开发者阅读 `ios_debug_demo/README.md`
- **THEN** 文档 SHALL 说明 Kotlin/Native 调试依赖 DWARF/LLDB
- **THEN** 文档 SHALL 说明断点和 step 是主要目标，表达式求值体验不保证等同于 Swift 源码调试

#### Scenario: Build and breakpoint validation is recorded
- **WHEN** 本 change 完成
- **THEN** `ios_debug_demo/README.md` SHALL 记录 Gradle Debug framework build 结果
- **THEN** `ios_debug_demo/README.md` SHALL 记录 Xcode Debug build 结果
- **THEN** `ios_debug_demo/README.md` SHALL 记录 Kotlin/Native 断点验证结果或当前环境限制
