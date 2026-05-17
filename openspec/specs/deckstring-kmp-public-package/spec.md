# deckstring-kmp-public-package Specification

## Purpose
TBD - created by archiving change publish-deckstring-kmp-package. Update Purpose after archive.
## Requirements
### Requirement: Public SwiftPM binary wrapper repository
项目 SHALL 提供 public `DeckStringDecoderKMPPackage` repo，作为 KMP/SKIE `DeckStringDecoder` 的 SwiftPM binary package 入口。

#### Scenario: Wrapper repo is public and versioned
- **WHEN** 首个 wrapper package 版本发布完成
- **THEN** `git@github.com:SunsetWan/DeckStringDecoderKMPPackage.git` SHALL 存在且为 public repo
- **THEN** repo SHALL 包含 tag `0.1.0-kmp.1`

#### Scenario: Wrapper manifest points to public release asset
- **WHEN** 执行者查看 wrapper repo `Package.swift`
- **THEN** manifest SHALL 定义名为 `DeckStringDecoder` 的 library product
- **THEN** manifest SHALL 定义名为 `DeckStringDecoder` 的 `.binaryTarget`
- **THEN** binary target SHALL 使用 public GitHub Release URL 和 `swift package compute-checksum` 输出
- **THEN** manifest SHALL 限定当前 binary package 的平台范围为 iOS

#### Scenario: Wrapper repo documents release usage
- **WHEN** 执行者阅读 wrapper repo 文档
- **THEN** README SHALL 说明 SwiftPM 安装方式、平台范围、tag/checksum 更新规则、和 private/source repo 的关系
- **THEN** changelog 或 release notes SHALL 记录 wrapper 版本、artifact URL 和 checksum

### Requirement: Public consumer verification
项目 SHALL 提供最小 consumer 验证，证明 public wrapper package 可被 SwiftPM 拉取、解析、链接和运行。

#### Scenario: Public consumer resolves package
- **WHEN** 最小 consumer 通过 public repo URL 和 tag `0.1.0-kmp.1` 依赖 wrapper package
- **THEN** `swift package describe` 或 Xcode build SHALL 能解析 package manifest
- **THEN** build SHALL 从 public release URL 下载 binary artifact

#### Scenario: Public consumer runs Swift-facing API tests
- **WHEN** 最小 consumer tests 在 iOS Simulator 上运行
- **THEN** tests SHALL 覆盖 `import DeckStringDecoder`、`DeckStringDecoder()`、标准 deck decode、encode round trip、sideboard deck 和指定错误映射
- **THEN** consumer 代码 SHALL NOT 直接引用 `KmpDeck`、`KmpCard`、`KotlinInt` 或其他 Kotlin/Native bridge 类型

