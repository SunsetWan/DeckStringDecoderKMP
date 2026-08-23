# Change: 加固 BobNote 的 KMP 卡组解析接入

## Why

`DeckStringDecoderKMPPackage` 的最小 SwiftPM consumer 已覆盖 decode、encode 与错误映射，但 BobNote 从旧 Swift source package 原位切换到同名 KMP binary framework 时暴露了更严格的真实集成边界：增量产物仍可能引用原 source package 自动合成的协议实现符号，而当前 Swift facade 手写了等价运算符。与此同时，`commonTest` 只在 iOS simulator target 执行，构建链中的 Gradle distribution、OpenSpec 与 GitHub Actions 也缺少完整固定。

本 change 保持 Swift-facing API 与卡组语义不变，补齐 source-package ABI 迁移兼容、JVM/iOS 双目标 common tests 和可复现 CI 输入，为 BobNote production 接入提供可审计证据。

## What Changes

- Swift facade 保留稳定的显式相等实现，并额外导出原 Swift source package 的四个编译器合成 equality 入口，兼容 BobNote 已有增量对象文件。
- 增加 JVM target，并让同一套 `commonTest` 同时在 JVM 与 iOS simulator 执行。
- 固定 Gradle distribution SHA-256、OpenSpec 版本和 GitHub Actions commit SHA。
- 发布新的 `0.1.0-kmp.4` binary artifact，供 BobNote 精确锁定。

## Impact

- 影响 Swift facade、Gradle target、CI/release workflow、README 与 binary artifact。
- 不改变 `import DeckStringDecoder`、公开 Swift 类型、方法签名、错误 case 或 deckstring 编解码语义。
- JVM target 仅作为 shared core 可移植性与测试门禁，不新增 JVM production consumer。
