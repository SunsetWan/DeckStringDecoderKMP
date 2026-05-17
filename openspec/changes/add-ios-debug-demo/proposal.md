## Why

当前 README 已经区分三种 iOS demo 接入诉求：release XCFramework 消费、本地 KMP 源码联调、以及本地 KMP 源码断点调试。第三种方式需要依赖 KMP source repo 内的 Gradle task、Debug framework、DWARF/LLDB 信息和 Kotlin 源码路径，因此应固定落在 `DeckStringDecoderKMP/ios_debug_demo/`，而不是放入 public binary wrapper repo。

仓库当前不存在 `DeckStringDecoderKMPDemo/` 旧目录，也不存在 `ios_debug_demo/`。本 change 的目标是从零建立新的 `DeckStringDecoderKMPDebugDemo` 调试 demo，并把可执行的 Xcode/Gradle/LLDB 细节写入 OpenSpec 和 README，避免后续再次混用 release demo 与 source debug demo。

## What Changes

- 新增 `ios_debug_demo/DeckStringDecoderKMPDebugDemo`，作为 source repo 内的最小 SwiftUI iOS 调试 app。
- demo deployment target 固定为 iOS 15。
- Debug build 通过 Xcode Run Script 调用 `:deckstring:embedAndSignAppleFrameworkForXcode`，从本地 KMP 源码生成 Debug framework。
- Debug 配置明确设置 `KOTLIN_FRAMEWORK_BUILD_TYPE=Debug`，关闭 `User Script Sandboxing`，并保证 Run Script 位于 `Compile Sources` 前。
- demo UI 提供稳定入口，触发 Swift-facing API 的 decode、encode round trip 和 invalid input error mapping，方便在 Kotlin core 中设置断点。
- README 和 `ios_debug_demo/README.md` 记录实际调试步骤、常见失败原因、LLDB 限制，以及该 demo 不证明 public SwiftPM release 可用。

## Capabilities

### New Capabilities

- `deckstring-ios-debug-demo`：提供基于本地 KMP 源码的 iOS Debug demo，用于从 Xcode 触发 Swift-facing API 并断点进入 Kotlin/Native 代码。

### Modified Capabilities

- 无。该 change 不改变 KMP core、Swift-facing public API、SwiftPM binary packaging 或 public wrapper repo 发布流程。

## Impact

- 影响范围限定在 `ios_debug_demo/`、README 文档和 OpenSpec artifacts。
- 不修改 `deckstring/src/commonMain/kotlin` 的行为实现。
- 不修改 `deckstring/src/commonMain/swift/DeckStringDecoderFacade.swift` 的 public API。
- 不依赖 `DeckStringDecoderKMPPackage`、GitHub Release asset 或 SwiftPM `.binaryTarget`。
- 不包含 BobNote production 接入。
