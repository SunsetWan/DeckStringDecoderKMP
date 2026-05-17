# DeckStringDecoderKMPDebugDemo

`DeckStringDecoderKMPDebugDemo` 是本仓库内的本地 Kotlin/Native 断点调试 demo。它只用于从 iOS app 触发 `DeckStringDecoder` 的 Swift-facing API，并通过本地 KMP source repo 生成 Debug framework；它不证明 public SwiftPM release 或 `DeckStringDecoderKMPPackage` 可用。

## 打开方式

```sh
open ios_debug_demo/DeckStringDecoderKMPDebugDemo/DeckStringDecoderKMPDebugDemo.xcodeproj
```

在 Xcode 中选择：

- scheme：`DeckStringDecoderKMPDebugDemo`
- configuration：`Debug`
- destination：iOS Simulator

demo 的最低部署版本固定为 iOS 15。

## Xcode 集成

app target 的 Debug 配置设置：

- `KOTLIN_FRAMEWORK_BUILD_TYPE = Debug`
- `ENABLE_USER_SCRIPT_SANDBOXING = NO`
- `IPHONEOS_DEPLOYMENT_TARGET = 15.0`

`Embed DeckStringDecoder Debug Framework` Run Script 位于 `Compile Sources` 前：

```sh
export JAVA_HOME="${JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"
cd "${SRCROOT}/../.."
./gradlew :deckstring:embedAndSignAppleFrameworkForXcode --console=plain
```

这里 `.xcodeproj` 位于 `ios_debug_demo/DeckStringDecoderKMPDebugDemo/`，所以 `${SRCROOT}/../..` 会回到仓库根目录。Gradle task 根据 Xcode 注入的 `SDK_NAME`、`ARCHS`、`CONFIGURATION` 等环境变量生成并嵌入本地 framework。

## 调试入口

`ContentView.swift` 提供三个按钮：

- `Decode`：调用 `DeckStringDecoder().decode(_:)`，展示 format、hero、card count 和 sideboard count。
- `Round Trip`：decode 后调用 `DeckStringDecoder().encode(_:)`，再 decode 回来比较 `Deck`。
- `Invalid Input`：通过 Swift-facing API 捕获并展示 `DeckStringError`。

demo Swift code 只 `import DeckStringDecoder` 并使用 Swift-facing API，不直接引用 `KmpDeck`、`DecodeResult`、`EncodeResult` 或 `DeckStringCodecBridge`。

## 断点位置

优先在 Kotlin source 中设置断点：

```text
deckstring/src/commonMain/kotlin/com/sunsetwan/deckstring/DeckStringCore.kt
```

推荐位置：

- `DeckStringCodecBridge.decode`
- `DeckStringCodecBridge.encode`

从 Xcode 运行 app 后，点击 `Decode` 或 `Invalid Input` 应触发 decode 路径；点击 `Round Trip` 应触发 decode 和 encode 路径。

## LLDB 限制

Kotlin/Native 调试依赖 DWARF/LLDB。该 demo 的主要目标是让源码断点命中并支持 step；表达式求值、变量展示和泛型类型显示不保证与 Swift 源码调试体验一致。

若断点没有命中，优先检查：

- 当前 destination 是否为 iOS Simulator。
- Xcode build 是否使用 `Debug` configuration。
- Run Script 是否已经生成 Debug framework。
- `JAVA_HOME` 是否能指向 Android Studio JBR。
- Xcode 是否打开的是本仓库内的 `ios_debug_demo/DeckStringDecoderKMPDebugDemo/DeckStringDecoderKMPDebugDemo.xcodeproj`。

## 验证记录

日期：2026-05-18

| 项目 | 结果 | 记录 |
| --- | --- | --- |
| OpenSpec change validation | 通过 | `openspec validate add-ios-debug-demo --strict` 输出 `Change 'add-ios-debug-demo' is valid` |
| OpenSpec specs validation | 通过 | 归档前 `openspec validate --specs --strict` 输出 5 个 spec 全部通过；归档后复跑输出 6 个 spec 全部通过 |
| Gradle Debug framework build | 通过 | `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :deckstring:linkDebugFrameworkIosSimulatorArm64 --console=plain` 输出 `BUILD SUCCESSFUL` |
| Xcode Debug build | 通过 | `xcodebuild -project ios_debug_demo/DeckStringDecoderKMPDebugDemo/DeckStringDecoderKMPDebugDemo.xcodeproj -scheme DeckStringDecoderKMPDebugDemo -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17" CODE_SIGNING_ALLOWED=NO build` 输出 `** BUILD SUCCEEDED **`，Run Script 已调用 `:deckstring:embedAndSignAppleFrameworkForXcode` |
| Kotlin/Native breakpoint | 通过 | XcodeBuildMCP/LLDB attach 到 `com.sunset.learn.2026.DeckStringDecoderKMPDebugDemo`，在 `DeckStringCore.kt:98` 和 `DeckStringCore.kt:148` 设置断点；点击 `Decode` 命中 `DeckStringCodecBridge#decode`，点击 `Round Trip` 命中 `decode`、`encode` 和回读 `decode`，点击 `Invalid Input` 命中 `decode` |
| Demo UI workflow | 通过 | iPhone 17 simulator 上点击三个按钮后，UI 分别显示 `Format: standard, heroes: 7, cards: 30, sideboard: 0`、`Encoded and decoded deck matches fixture.` 和 `Unsupported deck format: 5` |
