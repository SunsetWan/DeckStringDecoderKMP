# DeckStringDecoder → BobNoteSharedKMP handoff

## 当前状态与 owner

- 状态：`accepted`，以 [receiver-acceptance.md](./receiver-acceptance.md) 的 machine-readable block 为准。
- BobNote 产品所用 Kotlin implementation、Core bridge 与 Swift facade 的唯一 owner 已切换为 `BobNoteSharedKMP`。
- 本仓库继续保留完整源码历史、tags、release、SwiftPM wrapper evidence、demo 与 CI；保留历史不等于继续为 BobNote 并行发版。

## 冻结交付物

- [确定性 donor manifest](./deckstring-donor-manifest.json)
- [Donor behavior baseline](./donor-baseline.md)
- [Swift numeric-boundary supplemental probe](./SwiftNumericBoundaryProbeTests.swift)
- [Receiver acceptance state](./receiver-acceptance.md)
- [OpenSpec proposal](../../openspec/changes/transfer-deckstring-ownership-to-bobnote-shared/proposal.md)
- [OpenSpec design](../../openspec/changes/transfer-deckstring-ownership-to-bobnote-shared/design.md)

Manifest 固定 donor commit `af490607cc79c5f28152537a375dd07adf9f099d`，hash 基于 Git blob bytes，而非当前工作区内容。receiver 复制普通 source files 并保留 provenance，不嵌入 donor Git metadata。

## Receiver 允许的适配

BobNoteSharedKMP change `consolidate-deckstring-and-expose-cocoapods` 只允许：

1. 将 Kotlin/KGP 从 2.3.20 统一到 2.4.10，并接入 Shared 现有 Gradle build；
2. 将普通 source/test 文件重定位为 receiver 的独立 `:deckstring` module；
3. 移除 SKIE 构建依赖，把 Swift facade 放入 `BobNoteShared` overlay Pod；
4. 增加只暴露 facade 所需类型/操作的 `BobNoteSharedCore` bridge；
5. 仅做 module/import、generated Kotlin/Native API 和构建版本适配，并逐文件记录 donor → receiver 映射与理由。

## 禁止的变化

交接不得改变 decode/encode 算法、canonical sorting、sideboard、trailing-byte compatibility、错误映射、numeric boundary、Codable、Equatable、Hashable 或历史 deck data behavior。receiver 不得依赖 donor checkout、subtree、nested submodule、Maven artifact、XCFramework、demo、workflow 或网络才能编译 `:deckstring`。

任何超出批准适配范围的 semantic diff 都必须停止 acceptance，并由独立 behavior change 处理。

## 三仓验收顺序

1. **DeckStringDecoderKMP donor**：manifest、JVM/iOS tests、Swift consumer、artifact、wrapper/dependency/workflow/OpenSpec gates 通过。
2. **BobNoteSharedKMP receiver**：source completeness/hash audit、Kotlin 2.4.10 JVM/iOS tests、无 SKIE Core bridge、Swift overlay Pod consumer 和 provenance/adaptation report 通过，并形成完整 receiver commit。
3. **BobNote app**：锁定 Shared gitlink，提交 `Podfile.lock`，Debug/Release/UT/archive/CI/Fastlane gates 通过；compatibility set 同时记录 BobNote commit、Shared gitlink 与 lock SHA-256。
4. donor 复核 receiver diff 和 BobNote compatibility set 后，才把 acceptance 从 `pending` 改为 `accepted`。

复制源码、Shared 单仓通过或 BobNote 只完成 `pod install` 都不等于 ownership 已切换。

## 整组回滚

新 compatibility set 出现回归时，BobNote 恢复包含 `DeckStringDecoderKMPPackage` exact `0.1.0-kmp.5` pin 的上一完整 App commit；同时恢复当时的 package resolution，不在同一 build 中混合 `.5` 与 `BobNoteSharedCore`，也不增加 runtime fallback。

Remote archive、删除 donor source/CI/demo、停止独立 consumer 支持都不属于本 handoff，必须另行决策和授权。

## 重跑校验

```sh
python3 scripts/deckstring_handoff.py manifest validate \
  --repository <clean-detached-donor-worktree> \
  --manifest handoff/bobnote-shared/deckstring-donor-manifest.json

python3 scripts/deckstring_handoff.py acceptance validate \
  --file handoff/bobnote-shared/receiver-acceptance.md
```
