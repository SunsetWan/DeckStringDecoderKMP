# deckstring-swiftpm-binary-distribution Specification

## Purpose
定义 KMP/SKIE `DeckStringDecoder.xcframework` 通过 SwiftPM binary target 分发所需的 artifact、checksum、manifest、consumer 验证与发布文档要求。
## Requirements
### Requirement: SwiftPM binary artifact packaging
项目 SHALL 将 release `DeckStringDecoder.xcframework` 打包成 SwiftPM binary target 可消费的 zip artifact，并生成可复现 checksum。

#### Scenario: Release XCFramework is zipped for SwiftPM
- **WHEN** 发布打包任务运行完成
- **THEN** `DeckStringDecoder.xcframework.zip` SHALL 存在于记录的发布产物目录
- **THEN** zip 内部顶层 SHALL 包含 `DeckStringDecoder.xcframework`

#### Scenario: SwiftPM checksum is reproducible
- **WHEN** 执行者对 `DeckStringDecoder.xcframework.zip` 运行 `swift package compute-checksum`
- **THEN** 输出值 SHALL 与记录的 checksum 文件一致

#### Scenario: Swift interfaces remain in packaged artifact
- **WHEN** 检查打包前的 release `DeckStringDecoder.xcframework`
- **THEN** device 和 simulator slices SHALL 保留 `.swiftinterface`
- **THEN** 打包流程 SHALL NOT 删除或修补 `.swiftinterface` / `.swiftmodule` 文件

### Requirement: SwiftPM binary package manifest
项目 SHALL 提供隔离的 SwiftPM binary package manifest，使发布后的外部 SwiftPM consumer 能通过 binary target 引用 KMP/SKIE framework。

#### Scenario: Release manifest uses URL and checksum
- **WHEN** 查看 SwiftPM binary 发布 manifest
- **THEN** manifest SHALL 定义名为 `DeckStringDecoder` 的 `.binaryTarget`
- **THEN** binary target SHALL 使用 URL 和 checksum 引用 `DeckStringDecoder.xcframework.zip`

#### Scenario: Source package baseline remains intact
- **WHEN** 根目录 source Swift package 运行 `swift test`
- **THEN** 现有 source package 测试 SHALL 继续通过
- **THEN** 发布包装 SHALL NOT 要求删除或替换根目录 `Package.swift`

#### Scenario: Public Swift API remains stable
- **WHEN** SwiftPM consumer 导入 binary package
- **THEN** consumer SHALL 能使用 `import DeckStringDecoder`、`DeckStringDecoder()`、`Deck`、`Card`、`SideboardCard`、`DeckFormat` 和 `DeckStringError`
- **THEN** consumer 代码 SHALL NOT 直接引用 Kotlin/Native bridge 类型

### Requirement: Minimal SwiftPM consumer verification
项目 SHALL 提供最小 SwiftPM consumer，证明 zip binary target 可以在 iOS Simulator 上真实 build 和 run。

#### Scenario: Consumer builds through SwiftPM package
- **WHEN** 最小 SwiftPM consumer 使用生成的 `DeckStringDecoder.xcframework.zip`
- **THEN** consumer build SHALL 成功解析并链接 `.binaryTarget`

#### Scenario: Consumer runs deckstring checks
- **WHEN** 最小 SwiftPM consumer tests 在 iOS Simulator 上运行
- **THEN** tests SHALL 覆盖 `import DeckStringDecoder`、`DeckStringDecoder()` 初始化、标准 deck decode、encode round trip、sideboard deck、invalid base64、invalid reserved byte、unsupported version、invalid format、invalid hero count、truncated data 和 invalid sideboard marker
- **THEN** 所有检查 SHALL 通过 Swift-facing API 完成

### Requirement: SwiftPM binary release documentation
项目 SHALL 提供可重复执行的发布文档，说明如何从源码生成、校验并验证 SwiftPM binary 发布产物。

#### Scenario: Documentation covers release commands
- **WHEN** 执行者阅读发布文档
- **THEN** 文档 SHALL 包含 release XCFramework 构建命令、zip artifact 生成命令、checksum 获取命令、SwiftPM binary target 引用示例和最小 consumer 验证命令

#### Scenario: Documentation states current scope
- **WHEN** 执行者阅读发布文档
- **THEN** 文档 SHALL 明确当前阶段只验证 SwiftPM binary 可消费
- **THEN** 文档 SHALL NOT 声称 BobNote production 已完成接入

### Requirement: Public XCFramework release asset
项目 SHALL 将 KMP/SKIE release `DeckStringDecoder.xcframework.zip` 发布到 public wrapper repo 的 GitHub Release，使 SwiftPM binary target 能通过公开 HTTPS URL 下载。

#### Scenario: Release asset is hosted in public wrapper repo
- **WHEN** 首个 public binary release 发布完成
- **THEN** `DeckStringDecoder.xcframework.zip` SHALL 可通过 `https://github.com/SunsetWan/DeckStringDecoderKMPPackage/releases/download/0.1.0-kmp.1/DeckStringDecoder.xcframework.zip` 下载
- **THEN** artifact SHALL 存放在 public `DeckStringDecoderKMPPackage` repo 的 GitHub Release，而不是 private `HS_DeckStringDecoder` repo 的 GitHub Release

#### Scenario: Public asset checksum matches local build output
- **WHEN** 执行者对 public release asset 运行 `swift package compute-checksum`
- **THEN** 输出 SHALL 与本地 `deckstring/build/swiftpm-binary/DeckStringDecoder.xcframework.zip.checksum` 记录的 checksum 一致

#### Scenario: Public asset preserves SwiftPM zip layout
- **WHEN** 执行者检查 public release asset 的 zip 内容
- **THEN** zip 顶层 SHALL 包含 `DeckStringDecoder.xcframework`
- **THEN** artifact SHALL 保留 iOS device 和 simulator slices 所需的 Swift module interface 文件
