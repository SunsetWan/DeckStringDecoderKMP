## Purpose

定义 DeckStringDecoderKMP 向 BobNoteSharedKMP 交接 deckstring 源码时的冻结快照、完整性证据、行为验收、产品所有权切换和历史保留边界。

## ADDED Requirements

### Requirement: Transfer uses an immutable and complete donor snapshot
交接 SHALL 固定一个不可变 donor commit，并 SHALL 生成足以从本仓库重新核验 production source、tests 与构建上下文的 manifest。

#### Scenario: Donor manifest is generated
- **WHEN** 交接候选准备给 BobNoteSharedKMP
- **THEN** manifest SHALL 记录 repository identity、完整 commit hash、Kotlin/Gradle/SKIE baseline、生产与测试文件相对路径、逐文件内容校验值和 license/provenance 说明
- **THEN** manifest SHALL NOT 引用未提交文件、mutable branch HEAD 或开发机绝对路径作为交付输入

#### Scenario: Snapshot completeness is checked
- **WHEN** 接收方使用 manifest 重新枚举 donor commit
- **THEN** 所有 deckstring model、decoder、encoder、varint、sideboard、bridge-facing source 与 common tests SHALL 被覆盖
- **THEN** 缺失、额外或内容不匹配文件 SHALL 阻止接收确认

### Requirement: Donor behavior is frozen before transfer
Donor commit SHALL 通过当前 JVM、Kotlin/Native 与 Swift-facing parity gates，并 SHALL 将结果与使用的 fixtures 记录为接收方适配的行为基线。

#### Scenario: Cross-platform core baseline passes
- **WHEN** donor commit 运行 JVM 与 iOS simulator common tests
- **THEN** model、decode、encode、sorting、sideboard、malformed input、numeric boundary 与 golden fixtures SHALL 全部通过

#### Scenario: Swift-facing baseline passes
- **WHEN** 未修改的 donor facade/consumer 运行既有 Swift fixtures
- **THEN** `Deck`、`Card`、`SideboardCard`、`DeckFormat`、`DeckStringError` 与 `DeckStringDecoder` 的 decode、encode、error、Codable、Equatable、Hashable 与 round-trip behavior SHALL 被记录
- **THEN** 记录 SHALL 可与 BobNoteShared overlay consumer 的同组结果逐项比较

### Requirement: Ownership changes only after receiver acceptance
在 BobNoteSharedKMP 记录 donor 内容、必要适配和完整 parity 证据前，本仓库 SHALL 继续是现行 deckstring source owner；接收通过后，BobNote 产品所用实现与 Swift facade 的后续 owner SHALL 唯一切换到 BobNoteSharedKMP。

#### Scenario: Receiver accepts the snapshot
- **WHEN** BobNoteSharedKMP 的 imported-source audit、Kotlin 2.4.10 common/native tests、无 SKIE bridge、Swift overlay consumer 与 BobNote compatibility gates 全部通过
- **THEN** acceptance SHALL 记录 donor commit、receiver commit 与 BobNote compatibility set
- **THEN** 后续 BobNote 产品 deckstring changes SHALL 由 receiver 仓库评审和交付

#### Scenario: Receiver has not accepted the snapshot
- **WHEN** 任一内容、行为、bridge、构建或 consumer gate 未通过
- **THEN** ownership SHALL NOT 标记完成
- **THEN** donor release `0.1.0-kmp.5` SHALL 继续只作为已验证旧组合的回滚基线，而不得与未接受 source Pod 组成混合正式构建

### Requirement: Transfer does not erase history or create dual delivery
本 change SHALL 保留本仓库源码历史、tags、release 与 wrapper evidence，并 SHALL NOT 在 BobNote 切换期间建立两个同时可运行的 KMP delivery paths。

#### Scenario: Historical evidence remains accessible
- **WHEN** ownership acceptance 完成
- **THEN** donor commit、现有 tags、release checksums、consumer evidence 与完整 Git history SHALL 保持可审计
- **THEN** remote archive、源码删除、CI 删除或停止独立 consumer 支持 SHALL 需要后续独立决策

#### Scenario: BobNote production graph is inspected
- **WHEN** BobNote CocoaPods compatibility set 成为默认路径
- **THEN** 本仓库的 SwiftPM artifact SHALL NOT 与 BobNoteShared Core/overlay Pods 同时解析、链接或作为 runtime fallback
- **THEN** 本仓库 SHALL NOT 为迁移后的 BobNote 功能维护平行的新 binary release line

### Requirement: Transfer mechanism preserves provenance without copying Git ownership
源码 SHALL 以 manifest 约束的文件快照进入 BobNoteSharedKMP；双方 SHALL 保留原始 author/history 的可追踪引用，但 SHALL NOT 通过 subtree、submodule、历史重写或伪造提交元数据把 donor Git ownership 嵌入 receiver。

#### Scenario: Receiver records adapted files
- **WHEN** receiver 因 Kotlin 2.4.10、module package 或去除 SKIE 调整导入 source
- **THEN** adaptation report SHALL 将每项 receiver diff 关联到 donor file 与原因
- **THEN** unchanged logic SHALL 可通过 manifest checksum 或语义 diff 追溯

#### Scenario: Git topology is audited
- **WHEN** 检查 receiver repository 和 build graph
- **THEN** receiver SHALL contain ordinary reviewed source files and provenance documents
- **THEN** it SHALL NOT require donor repository checkout、nested Git metadata、Maven artifact or network access to compile deckstring
