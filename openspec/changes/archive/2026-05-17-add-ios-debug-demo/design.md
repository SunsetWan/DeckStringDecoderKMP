## Context

`DeckStringDecoderKMP` 是 KMP source of truth，负责 Kotlin common core、SKIE Swift facade、Gradle/KMP/SKIE 配置、KMP tests 和 release artifact 生成。`DeckStringDecoderKMPPackage` 是 public SwiftPM binary wrapper，适合放 release 后的 consumer demo，不适合承载 Kotlin/Native 源码断点调试能力。

本 change 只定义第三种 iOS demo 接入方式：本地 KMP 源码断点调试。它建立在本地源码联调之上，但额外要求 Debug framework、DWARF/LLDB 信息和可重复的 Xcode 设置。

当前仓库状态：

- `DeckStringDecoderKMPDemo/` 已不存在，不需要执行删除步骤。
- `ios_debug_demo/` 尚不存在，需要重新建立。
- `deckstring` module 已提供 `embedAndSignAppleFrameworkForXcode`、`linkDebugFrameworkIosSimulatorArm64`、`assembleDeckStringDecoderDebugXCFramework` 等 Gradle tasks。
- shell 下运行 Gradle 需要显式使用 Android Studio JBR：`JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"`。

## Directory Layout

新增目录采用以下结构：

```text
ios_debug_demo/
├── README.md
└── DeckStringDecoderKMPDebugDemo/
    ├── DeckStringDecoderKMPDebugDemo.xcodeproj/
    └── DeckStringDecoderKMPDebugDemo/
        ├── DeckStringDecoderKMPDebugDemoApp.swift
        ├── ContentView.swift
        └── Assets.xcassets/
```

`ios_debug_demo/` 位于 KMP source repo 根目录下。Xcode project 直接提交到仓库，保证开发者可以用 Xcode 打开并运行；不要求通过 public SwiftPM package resolve binary dependency。

不得复用 `DeckStringDecoderKMPDemo/` 旧路径。若实现时发现该目录又出现，应先确认是否为用户新建内容；如果只是旧 demo 残留，应删除或迁移到 `ios_debug_demo/` 后再提交。

## Xcode Project Configuration

新增 app 命名为 `DeckStringDecoderKMPDebugDemo`：

- deployment target：iOS 15。
- app target：SwiftUI app，使用 Swift-facing API `import DeckStringDecoder`。
- Debug build setting：`KOTLIN_FRAMEWORK_BUILD_TYPE = Debug`。
- `ENABLE_USER_SCRIPT_SANDBOXING = NO`，避免 Xcode script sandbox 阻止 Gradle 访问 repo-local build output。
- Run Script build phase 位于 `Compile Sources` 前。
- Run Script 使用 Xcode/KMP 官方集成 task：

```sh
export JAVA_HOME="${JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"
cd "${SRCROOT}/../.."
./gradlew :deckstring:embedAndSignAppleFrameworkForXcode --console=plain
```

这里 `.xcodeproj` 位于 `ios_debug_demo/DeckStringDecoderKMPDebugDemo/`，因此 `${SRCROOT}/../..` 是 repo root。`embedAndSignAppleFrameworkForXcode` 由 Xcode 注入的 SDK、ARCHS、CONFIGURATION 等环境变量决定实际生成 simulator/device framework；Debug 调试路径必须优先使用 simulator。

## Demo Behavior

demo UI 只承担调试入口，不做正式产品体验：

- 标准 deck decode：调用 `DeckStringDecoder().decode(validDeckString)`，展示 format、hero、card count、sideboard count。
- encode round trip：对 decode 后的 `Deck` 调用 `encode`，展示 round-trip 是否成功。
- invalid input：调用 `decode` 处理非法字符串，展示 `DeckStringError` 映射结果。

Swift 代码只允许使用 Swift-facing API：

- `DeckStringDecoder`
- `Deck`
- `Card`
- `SideboardCard`
- `DeckFormat`
- `DeckStringError`

consumer code 不应直接引用 Kotlin/Native bridge 类型，例如 `KmpDeck`、`DecodeResult` 或 `DeckStringCodecBridge`。断点应设置在 Kotlin 源码里，由 Swift-facing API 触发进入 Kotlin bridge。

## Debug Workflow

推荐调试步骤：

1. 用 Xcode 打开 `ios_debug_demo/DeckStringDecoderKMPDebugDemo/DeckStringDecoderKMPDebugDemo.xcodeproj`。
2. 选择 Debug configuration 和 iOS Simulator destination。
3. 在 `deckstring/src/commonMain/kotlin/com/sunsetwan/deckstring/DeckStringCore.kt` 中设置断点，优先选择 `DeckStringCodecBridge.decode` 或 `DeckStringCodecBridge.encode`。
4. 运行 app，触发 demo UI 中的 decode / encode / invalid input 操作。
5. 观察 LLDB 是否停在 Kotlin/Native 源码位置。

Kotlin/Native 调试依赖 DWARF/LLDB。预期支持源码断点和 step，但表达式求值、变量展示、泛型类型显示等体验不保证等同于 Swift 源码调试。若断点无法命中，需要把实际行为和 workaround 写入 `ios_debug_demo/README.md`。

## Validation Strategy

实现时需要分三层验证：

1. OpenSpec validation：确保 change 本身和 specs 可解析。
2. Gradle Debug framework validation：确保 KMP Debug simulator framework 可以生成。
3. Xcode demo build validation：确保 app target 能通过 Run Script 集成本地 Debug framework。

手动断点验证是该 change 的最终验收项。若环境无法自动证明断点命中，必须在 README 记录当前机器的验证结果、限制和后续复测步骤，不能只写“理论上支持”。

## Non-goals

- 不创建或修改 public release consumer demo。
- 不修改 `DeckStringDecoderKMPPackage`。
- 不发布新的 XCFramework release。
- 不调整 Swift-facing API、KMP core 语义或 test fixtures。
- 不接入 BobNote production 工程。
