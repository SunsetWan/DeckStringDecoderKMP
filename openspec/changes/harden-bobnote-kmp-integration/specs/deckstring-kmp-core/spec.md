## ADDED Requirements

### Requirement: Kotlin common core runs under two compilation models
KMP core SHALL 在 JVM 与 Kotlin/Native iOS simulator target 上运行同一套 common test suite。

#### Scenario: JVM common tests pass
- **WHEN** CI 运行 `:deckstring:jvmTest`
- **THEN** 公共 deck model、decode、encode、malformed input 与 golden fixture tests SHALL 在不依赖 Apple-only API 的情况下通过

#### Scenario: Kotlin Native common tests pass
- **WHEN** CI 运行 `:deckstring:iosSimulatorArm64Test`
- **THEN** 同一套公共行为 SHALL 在 Kotlin/Native 下通过

## MODIFIED Requirements

### Requirement: SKIE Swift facade parity
SKIE-bundled Swift facade SHALL 在把 deckstring 解析与编码委托给 Kotlin common core 的同时，保持现有 source package 的 Swift-facing 源码与协议行为。

#### Scenario: Source package model conformances remain compatible
- **WHEN** Swift consumer code uses `Equatable`、`Hashable` or `Codable` on `Card`、`SideboardCard`、`Deck` and `DeckStringError`
- **THEN** source behavior SHALL remain compatible with `HS_DeckStringDecoder` 1.0.1
- **THEN** replacing the same-named source module with the KMP binary SHALL NOT require consumer source changes

#### Scenario: Incremental source-to-binary replacement remains link compatible
- **WHEN** BobNote 的既有 object file 仍引用 `HS_DeckStringDecoder` 1.0.1 自动合成的 `Card`、`SideboardCard`、`Deck` 或 `DeckStringError` equality symbol
- **THEN** KMP binary 的 device 与 simulator slices SHALL 导出对应的四个兼容入口
- **THEN** 同名 source module 原位替换为 binary module SHALL NOT 要求清理 DerivedData 才能链接

#### Scenario: Source-package value layout remains runtime compatible
- **WHEN** 旧 consumer object file 构造或读取 `DeckFormat`、`Card`、`SideboardCard`、`Deck`、`DeckStringError` 或 `DeckStringDecoder`
- **THEN** binary framework SHALL 通过 `@frozen` 使用与 source package caller 兼容的固定布局与调用约定
- **THEN** source→binary 原位替换 SHALL 不只链接成功，还能正确构造、访问与比较这些值

#### Scenario: Decode parity through Swift facade
- **WHEN** Swift calls `DeckStringDecoder().decode` through the SKIE-built framework with standard、wild、sideboard and whitespace-padded fixtures from the Swift test suite
- **THEN** the returned `Deck` SHALL match the source Swift implementation for format、heroes、cards、sideboard cards and canonical sorting

#### Scenario: Encode parity through Swift facade
- **WHEN** Swift calls `DeckStringDecoder().encode` through the SKIE-built framework with decks covering normal cards、sideboard cards、round trip and canonical sorting
- **THEN** the returned deck string SHALL match the source Swift implementation for the same semantic deck

#### Scenario: Error mapping parity through Swift facade
- **WHEN** Swift calls `DeckStringDecoder().decode` or `DeckStringDecoder().encode` through the SKIE-built framework with invalid base64、invalid reserved byte、unsupported version、invalid format、invalid hero count、truncated data and invalid sideboard marker cases
- **THEN** the thrown `DeckStringError` SHALL match the source Swift API error case expected by existing Swift tests
