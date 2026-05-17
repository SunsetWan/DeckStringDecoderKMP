## Why

当前 KMP core 已经覆盖主要 Swift parity fixtures，但 common tests 还没有逐项覆盖 Swift 原测试中的 Rogue / Pool Party Maiev、specific card parsing、empty string failure 等关键语义。与此同时，`DeckStringCore.kt` 的 encode/decode 热路径仍有可见的内部开销：normal cards 和 sideboard cards 分组各自通过三次 `filter` 完成，`ByteWriter` 使用 `MutableList<Byte>` 逐项装箱，`ByteReader` 成功路径会创建 `ReadResult.Success` 对象。

本 change 先补齐测试 parity，再做不改变行为的内部优化，降低后续 Swift facade 和 SwiftPM binary 发布路径中的 core 风险。

## What Changes

- 新增 KMP common tests，补齐 Swift 原测试中的 Rogue / Pool Party Maiev fixture、specific card parsing fixture、empty string failure parity，并锁定当前 trailing bytes 兼容行为。
- 将 normal cards 和 sideboard cards 的 1x / 2x / n-copy 分组从三次 `filter` 改为单次遍历。
- 将 `ByteWriter` 从 `MutableList<Byte>` 改为私有 growable `ByteArray`。
- 将 `ByteReader` 成功路径改为低分配的 nullable value 读取，失败仍返回现有 `DeckStringFailure`。
- decode normal cards 和 sideboard cards 时按 group count 预分配列表容量，并对不合理 group count 返回 failure，避免崩溃。

## Capabilities

### New Capabilities
- 无。

### Modified Capabilities
- `deckstring-kmp-core`：补充 Kotlin common tests parity 要求，并明确内部 grouping 优化和 trailing bytes 兼容行为不改变 public behavior。

## Impact

- 影响 `deckstring/src/commonMain/kotlin/com/sunsetwan/deckstring/DeckStringCore.kt` 和 `deckstring/src/commonTest/kotlin/com/sunsetwan/deckstring/DeckStringCoreTest.kt`。
- 不修改 Swift public API、KMP public model、deck string wire format、错误映射语义、SKIE/SwiftPM packaging。
- trailing bytes 暂不收紧；如果要改为严格拒绝，需要另开 OpenSpec change。
