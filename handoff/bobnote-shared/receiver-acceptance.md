# BobNoteShared receiver acceptance

当前状态：`accepted`。

BobNoteSharedKMP 已接收 donor source/tests/facade provenance，BobNote 已固定并验证 source Pod compatibility set。BobNote 产品使用的 deckstring implementation、Core bridge 与 Swift facade ownership 现属于 BobNoteSharedKMP；本仓库保留历史、独立 consumer 和整组回滚证据。

<!-- deckstring-handoff-acceptance
{
  "bobNoteCompatibilitySet": {
    "commit": "ad959b63f7770c80c3fb03138cdf0f09bf2db567",
    "gatesEvidence": "BobNote@ad959b63: openspec/changes/migrate-kmp-integration-to-cocoapods/task-2.1-5.2-clean-checkout-evidence.md; task-6.1-7.3-final-acceptance-evidence.md; task-6.3-compatibility-rollback-evidence.md",
    "podfileLockSha256": "002fffbce40932baee7c817a656a08260139256518767efa5885c9e07c8a0f91",
    "sharedGitlink": "4a14ecf03d6b9c2069c1b39e73f1df34cb825aca"
  },
  "donorCommit": "af490607cc79c5f28152537a375dd07adf9f099d",
  "receiver": {
    "commit": "2642442f485d784d1efd6c8d2cbc788be442b58d",
    "commonTestsEvidence": "BobNoteSharedKMP@2642442f: task-6.1-full-quality-gates-evidence.md records deckstring 21/21 JVM and 21/21 iOS plus shared JVM/iOS gates",
    "nativeTestsEvidence": "BobNoteSharedKMP@2642442f: task-2.2-shared-bridge-green-evidence.md and task-3.2-swift-facade-green-evidence.md",
    "podConsumerEvidence": "BobNoteSharedKMP@2642442f: task-4.4-pod-consumer-evidence.md and task-4.5-pod-regression-evidence.md record 31/31 Debug and 31/31 Release, device Archive, API/symbol/link audits",
    "provenanceReport": "docs/provenance/deckstring-adaptation.md",
    "provenanceReportSha256": "6f0c3004b8d6d00d25514497a0c1917b1795c2f7858d58cb06638fb05845935c"
  },
  "schemaVersion": 1,
  "status": "accepted"
}
-->

已验收的边界：

- Shared source delivery commit 为 `8fd41a30792a890af8c3f15f2b72ec3221975568`；BobNote 使用的完整 gitlink commit 为 `4a14ecf03d6b9c2069c1b39e73f1df34cb825aca`；`2642442f485d784d1efd6c8d2cbc788be442b58d` 只追加 receiver acceptance 与最终 adaptation 说明，不改变 BobNote 所消费的 source/lock 输入。
- BobNote 产品 source commit 为 `92aa0f6b8e200a327b00d127175f7d1d49994bc2`，`ad959b63f7770c80c3fb03138cdf0f09bf2db567` 追加 clean-checkout、rollback 和跨 change 接收证据。
- BobNote 全量 UT 908/908、Debug、Release、device Archive、单一 static Core/Kotlin runtime、35,807-card parity 和上一整组 SwiftPM 回滚构建均通过。
- Remote publication、GitHub Actions 执行与 donor remote archive 没有发生；它们不是本地 ownership acceptance 的伪造组成部分。

`0.1.0-kmp.5` 仅保留为上一整组 App 输入的历史回滚基线。BobNote 不在同一 build 中混合它与 `BobNoteSharedCore`，本仓库也不再为 BobNote 产品并行发布新的 deckstring artifact。
