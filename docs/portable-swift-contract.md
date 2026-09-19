# 可移植 Swift 模型契约

状态：2026-09-19 本地实现并验证，尚未提交或发布。

Swift 模型和 facade 的唯一维护源位于 `swiftpm-binary/Sources`。`DeckStringModels`
保留原有值类型、排序、Codable 和错误语义，支持 macOS 14 测试宿主和 iOS 15。
`DeckStringDecoder` 作为 SwiftPM 源码 facade，继续映射 Kotlin bridge，并以类型别名
公开同一份模型。Swift 语言模式保持 5；manifest 使用 Swift tools 6.2。

Kotlin 二进制改名为 `DeckStringRuntime`，仅支持 iOS device/simulator。它不再应用
SKIE 打包 Swift facade；Swift facade 由消费者的 Swift 编译器编译。移动 public 类型
会改变名义类型身份，消费者必须重新编译，不保证与旧二进制 ABI 兼容。

## 本地构建与验证

```sh
./gradlew :deckstring:prepareDeckStringDecoderSwiftPMBinaryRelease
swift test --package-path swiftpm-binary
./gradlew :deckstring:iosSimulatorArm64Test
./gradlew :deckstring:verifyDeckStringDecoderSwiftPMConsumer
```

最后一个命令需要 `xcsift` 版本 `1.3.2-sunset.2`，运行 macOS 模型测试、iOS
模型/facade 测试和独立 Swift consumer 测试。可通过
`IOS_SIMULATOR_DESTINATION` 和 `SWIFT_VERIFICATION_RESULTS` 指定设备和唯一证据目录。

已观察到模型 UT 5 项、iOS 契约 UT 8 项、独立 consumer 2 项、Kotlin UT 21 项通过，
均未发现失败或跳过。BobNote 用本地新依赖及原有其他依赖版本运行 129 项 UT 通过，
Release simulator build 通过。源码调试 demo 已接入同一份 Swift 源文件和 Kotlin
Debug runtime，独立 DerivedData Debug build 通过；本次未重跑断点或 UI 交互。

## 发布准备

`scripts/update-wrapper-release.sh` 从 canonical source 生成 wrapper 的 Sources、Tests
和远程 runtime manifest；不在 wrapper 独立修改模型。此脚本本身只准备本地文件。
拟议版本 `0.1.0-kmp.6` 的本地预览已生成，尚无对应远程 release。

当前 runtime checksum：

```text
a0ece886f9bf135302103bef30c5568fba0f42a18809a76dfdbece7013b847e7
```

发布必须在用户确认后进行，并重新读回公共下载、checksum 与远程 consumer。CI/release
脚本已同步 archive 名称和 source 分发，但未在 GitHub Actions 运行。安装 xcsift 的
步骤按 [GitHub 标准 macOS runner 文档](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
中的 `macos-latest` ARM64 环境配置。

本次保留了 `README.md` 中原有未提交修改。
