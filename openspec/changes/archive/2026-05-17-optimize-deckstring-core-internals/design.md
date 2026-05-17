## Context

`deckstring-kmp-core` 已经迁移到 Kotlin common，并通过主要 Swift fixtures、malformed input 和 SwiftPM binary consumer 验证。当前计划的重点不是扩大 API，也不是改变发布包装，而是在 core 内部优化前先把 Swift 原测试中仍未覆盖的关键 fixture parity 补齐。

现有 `DeckStringCore.kt` 的行为边界需要保持稳定：

- `DeckStringCodecBridge.decode/encode` 签名不变。
- `KmpDeck`、`KmpCard`、`KmpSideboardCard`、`DeckStringFailure` 等 public model 不变。
- wire format、Base64、varint、sideboard marker 和错误映射不变。
- 当前 trailing bytes 兼容行为不在本 change 中收紧。

## Goals / Non-Goals

**Goals:**

- 先用 tests 锁定 Swift/KMP parity 缺口：Rogue / Pool Party Maiev fixture、Zilliax 102983、Wakener 111678、empty string failure。
- 锁定 trailing bytes 当前兼容行为，防止内部 reader 重构时意外收紧。
- 将 encode 分组改为单次遍历，保持 canonical output 不变。
- 用 growable `ByteArray` 替代 `ByteWriter` 的 `MutableList<Byte>`。
- 重构 `ByteReader` 成功路径，避免为每个成功 byte/varint 创建 `ReadResult.Success`。
- decode cards/sideboards 时按 group count 预分配容量，并对不合理 count 返回 `DeckStringFailure`。

**Non-Goals:**

- 不修改 Swift facade、不修改 public wrapper repo、不调整 SwiftPM binary artifact。
- 不改变 trailing bytes 行为。
- 不把 Kotlin public model 改成 `Long`、`UInt` 或其他 ABI 形态。
- 不新增 third-party parser、serialization 或 collections 依赖。

## Decisions

1. 测试先行。

   先补 KMP tests 中缺失的 Swift 原测试语义，再改内部实现。Rogue fixture 断言 format、hero `122992`、total count `30`、single `12`、double `9` 和大 DBF ID 存在；Death Knight specific card parsing 断言 `102983 count=1` 和 `111678 count=2`；empty string 断言 `UnexpectedEndOfData`。

2. trailing bytes 本 change 只锁定，不收紧。

   当前 decoder 在读取 sideboard marker 后不会要求 payload 完全耗尽。这个兼容行为可能被真实历史 deck string 依赖；本 change 只新增测试防止优化时误改。严格拒绝 trailing bytes 需要独立 change 和迁移说明。

3. encode grouping 保留现有顺序语义。

   `KmpDeck` 构造时已经 canonical sort。单次遍历只把已排序 cards 分配到 single/double/multi 三个列表，保持每组内部顺序和最终 encoded output 不变。

4. `ByteWriter` 只在最终输出时复制。

   writer 内部维护 `ByteArray` 和 `size`，写入时按需扩容。`toByteArray()` 在 Base64 encode 前返回精确大小副本，避免 `MutableList<Byte>` 的逐项装箱和最终列表转换成本。

5. `ByteReader` 用 nullable value 表示成功路径。

   `readByte()` 和 `readVarint()` 成功时直接返回 `Int`，失败时记录 `DeckStringFailure` 并返回 `null`。外层 decode 仍然把失败包装成 `DecodeResult.Failure`，public failure surface 不变。

6. decode group 按 count 预分配，但先做最小剩余字节检查。

   group count 来自输入，不能直接用于大容量分配。读取每组前根据每个 entry 至少需要的 varint 数量检查剩余字节；明显不可能满足时返回 `UnexpectedEndOfData`。通过检查后再用 group count 初始化 `ArrayList`，最后按总 entry count 创建结果列表。

## Risks / Trade-offs

- [Risk] 过早根据 group count 分配可能让恶意输入触发大内存分配。→ Mitigation: 分配前用剩余字节下界检查 count 是否可满足。
- [Risk] reader 重构可能改变 malformed input 的具体 failure。→ Mitigation: 保留现有 invalid sideboard marker、truncated data、malicious varint tests，并补 empty string / trailing bytes tests。
- [Risk] grouping 优化可能改变 canonical output。→ Mitigation: 新增 exact Swift fixture encode output 断言，并继续保留 canonical equivalence test。

## Migration Plan

1. 创建 `optimize-deckstring-core-internals` OpenSpec artifacts。
2. 补 KMP parity tests 和 trailing bytes lock test。
3. 重构 encode grouping、`ByteWriter`、`ByteReader` 和 decode group capacity handling。
4. 运行 OpenSpec strict validation、KMP iOS simulator tests、KMP allTests 和 Swift baseline `swift test`。
5. 勾选 tasks，archive change，并运行 `openspec validate --all --strict`。

## Open Questions

- 无。trailing bytes 的严格化不属于本 change。
