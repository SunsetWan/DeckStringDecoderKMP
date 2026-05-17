# DeckStringCore 测试对齐与内部优化计划

## Summary

- 新建 OpenSpec change：`optimize-deckstring-core-internals`。
- 先补齐 KMP tests 与 Swift 原测试的关键 parity 缺口，再优化 `DeckStringCore.kt` 内部实现。
- 不改变 Swift public API、KMP public model、deck string wire format、错误映射语义、SKIE/SwiftPM packaging。

## OpenSpec Artifacts

创建目录：

```sh
mkdir -p openspec/changes
openspec new change optimize-deckstring-core-internals --description "优化 DeckStringCore.kt 内部编码/解码实现，保持 Swift parity"
```

写入 `openspec/changes/optimize-deckstring-core-internals/proposal.md`：

- 当前 KMP core 行为已通过主要 parity，但测试并未逐项覆盖 Swift 原测试。
- 本 change 先补 Swift/KMP test parity，再降低 Kotlin encode/decode 热路径分配。
- 非目标：不修改 Swift facade、不修改 public wrapper、不收紧 trailing bytes 行为、不把 Kotlin model 改成 `Long/UInt`。

写入 `openspec/changes/optimize-deckstring-core-internals/design.md`：

- 测试先行，先锁定 Swift 原实现中 KMP 缺失的 fixtures。
- encode 分组从三次 `filter` 改成单次遍历。
- `ByteWriter` 从 `MutableList<Byte>` 改成私有 growable `ByteArray`。
- `ByteReader` 减少成功路径 `ReadResult.Success` 分配，但失败仍返回现有 `DeckStringFailure`。
- decode cards/sideboards 读取时按 group count 预分配容量。

写入 `openspec/changes/optimize-deckstring-core-internals/tasks.md`：

```md
- [ ] 1.1 创建 OpenSpec change 并补 proposal/design/tasks/spec delta
- [ ] 1.2 补 KMP Rogue / Pool Party Maiev fixture parity test
- [ ] 1.3 补 KMP specific card parsing parity test：Zilliax 102983、Wakener 111678
- [ ] 1.4 补 KMP empty string decode failure parity test
- [ ] 1.5 补 KMP trailing bytes 当前兼容行为锁定测试
- [ ] 2.1 将 normal cards trisort 改为单次遍历
- [ ] 2.2 将 sideboard cards trisort 改为单次遍历
- [ ] 2.3 用 growable ByteArray 重写 ByteWriter
- [ ] 2.4 重构 ByteReader 成功路径，减少对象分配
- [ ] 2.5 为 decode cards/sideboards 增加容量预分配
- [ ] 3.1 运行 OpenSpec strict validation
- [ ] 3.2 运行 KMP iOS simulator tests 与 allTests
- [ ] 3.3 运行 Swift 原包 swift test
- [ ] 3.4 勾选 tasks 并归档 change
```

## Spec Delta

- 修改能力：`deckstring-kmp-core`。
- 新增/修改 spec delta 文件：`openspec/changes/optimize-deckstring-core-internals/specs/deckstring-kmp-core/spec.md`。
- 在 `Kotlin common golden tests` 下增加场景：
  - KMP tests SHALL include Swift Rogue / Pool Party Maiev fixture.
  - KMP tests SHALL include Swift specific card parsing assertions for old Death Knight fixture.
  - KMP tests SHALL include empty-string decode failure parity.
- 在 `Kotlin common encode behavior` 下增加场景：
  - canonical encode output SHALL remain unchanged after internal grouping optimization.
- 在 `Kotlin common decode behavior` 下增加场景：
  - existing compatibility for trailing bytes SHALL remain unchanged for this change.

## Implementation Changes

`DeckStringCoreTest.kt`：

- 新增 Rogue fixture 常量，断言 format、hero `122992`、total count `30`、single `12`、double `9`、large DBF IDs 存在。
- 在旧 Death Knight fixture 上补 `102983 count=1` 与 `111678 count=2`。
- 补 `decodeFailure("") == UnexpectedEndOfData`，对齐 Swift “空字符串抛 DeckStringError.self” 的实际语义。
- 补 trailing bytes 当前行为测试，防止优化时误改 decode 兼容性。

`DeckStringCore.kt`：

- 保持 `DeckStringCodecBridge.decode/encode` 签名不变。
- 用单次遍历分组替代 `List.filter` 三次遍历。
- 用 `ByteArray` + `size` + `ensureCapacity` 实现 writer，`toByteArray()` 只在最终 Base64 encode 前复制一次。
- reader 内部读取改成低分配形式，但外部仍返回 `DecodeResult.Failure(DeckStringFailure...)`。
- cards/sideboards 根据 group counts 创建 `ArrayList(totalCount)`，total count 溢出时返回 `InvalidValue` 或 `MalformedVarint`，不崩溃。

## Validation

OpenSpec：

```sh
openspec validate optimize-deckstring-core-internals --strict
```

KMP：

```sh
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :deckstring:iosSimulatorArm64Test --console=plain --rerun-tasks
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :deckstring:allTests --console=plain
```

Swift baseline：

```sh
cd /Users/sunset/HS_APP/DeckStringDecoder
swift test
```

Archive：

```sh
cd /Users/sunset/HS_APP/DeckStringDecoderKMP
openspec archive optimize-deckstring-core-internals --yes
openspec validate --all --strict
```

## Assumptions

- 这次 change 范围限定在 KMP core 与 KMP tests。
- Swift 原实现仍作为行为 baseline，不在本 change 中修改。
- KMP 可以比 Swift 多覆盖恶意输入和边界输入，但不能少覆盖 Swift 的关键 fixtures。
- trailing bytes 暂不收紧；若要改为严格拒绝，需要另开 OpenSpec change。
