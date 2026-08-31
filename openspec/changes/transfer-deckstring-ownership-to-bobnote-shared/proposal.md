## Why

BobNote 计划通过一个 BobNoteShared CocoaPods source integration 消费全部 KMP 能力，因此 deckstring 不能继续作为第二套独立 framework 与发布链演进。需要先建立可审计、可重复的源码交接合同，在不丢失历史和行为证据的前提下把后续产品所有权移交给 BobNoteSharedKMP。

## What Changes

- 冻结用于交接的 donor commit，并生成 Kotlin source/test 文件清单、内容校验值、工具链版本与基线测试证据。
- 将 `deckstring` Kotlin common source 与 tests 作为带 provenance 的快照交付给 BobNoteSharedKMP；不使用 Git subtree、嵌套 submodule、Maven artifact 或历史重写。
- BobNoteSharedKMP 接受快照后成为 BobNote 产品所用 deckstring Kotlin 实现、bridge 与 Swift facade 的唯一 owner；本仓库保留完整历史、现有 tag、release 与 wrapper 作为回滚和审计证据。
- 在 BobNote CocoaPods 切换通过前，现有 SwiftPM `0.1.0-kmp.5` 只作为冻结回滚基线；不得与新 source Pod 在同一 BobNote build 中共同链接，也不再作为新功能的并行发布目标。
- 远端仓库归档、删除旧源码/CI 或停止所有独立 consumer 支持均不属于本 change；只有 BobNote 正式切换稳定后才能通过独立决策处理。
- deckstring decode、encode、错误映射、排序、sideboard、Codable/Equatable 与历史数据行为不变；交接不是功能重写。

## Capabilities

### New Capabilities

- `deckstring-ownership-transfer`: 定义 donor 快照、来源清单、行为证据、接收确认、产品 owner 切换与历史保留合同。

### Modified Capabilities


## Impact

- 影响本仓库的交接 manifest、验证记录、维护说明与后续发布责任，不在本 change 中删除现有源码、SKIE/XCFramework/SwiftPM 产物或历史 tag。
- BobNoteSharedKMP change `consolidate-deckstring-and-expose-cocoapods` 负责实际导入、Kotlin 2.4.10 适配、去除 SKIE 与新 Core/overlay Pods；BobNote change `migrate-kmp-integration-to-cocoapods` 负责最终 consumer 切换。
- BBNote-Server、BobNote UIKit、个人卡组数据与公共 deckstring 行为不受影响。
