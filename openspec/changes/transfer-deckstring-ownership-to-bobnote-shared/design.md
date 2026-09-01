## Context

见 [proposal.md](./proposal.md) 的动机。当前 donor commit 为 `af490607cc79c5f28152537a375dd07adf9f099d`：`:deckstring` 同时拥有 Kotlin common core/tests、SKIE-bundled Swift facade、独立 XCFramework/SwiftPM packaging 与 `0.1.0-kmp.5` 发布流程。BobNoteSharedKMP 将在另一个 change 中统一到 Kotlin/KGP 2.4.10、KMP-NativeCoroutines 与单一 Core/overlay Pods，因此本仓库不能直接把现有 Gradle module作为 composite build接入。

本 change 的产物是可验证的交接记录和 owner 切换门禁，不是删除或归档。交接完成前，本仓库仍是当前实现 owner；交接完成后，它继续保存历史和旧 release，但不再为 BobNote 产品并行演进新 artifact。

## Goals / Non-Goals

**Goals:**

- 用 immutable commit、逐文件 hash 与可重跑测试定义 donor snapshot。
- 把 Kotlin source/tests 和 Swift facade 来源完整交给 receiver，同时明确允许的适配边界。
- 只有 receiver 与 BobNote consumer 全部验收后才切换 product ownership。
- 保留完整 Git/release history 和可恢复的 `0.1.0-kmp.5` 基线。

**Non-Goals:**

- 不在本仓库实现 CocoaPods、Kotlin 2.4.10 或 BobNoteShared overlay。
- 不删除 SKIE、SwiftPM、demo、CI 或 source；这些仍是 donor 历史和独立 consumer 证据。
- 不自动 archive remote、不重写 Git history、不把 donor 作为 receiver submodule。
- 不改变任何 deckstring algorithm 或 Swift-facing behavior。

## Decisions

### 1. 交接根目录使用确定性 manifest 与人工可读说明

新增 `handoff/bobnote-shared/`：

- `deckstring-donor-manifest.json`：schema version、repository URL、完整 donor commit、source/test/facade 文件、POSIX relative path、SHA-256、Kotlin/Gradle/SKIE baseline、fixture集合和验证命令；
- `README.md`：owner 边界、receiver change、允许的适配、验收顺序、回滚与非目标；
- `donor-baseline.md`：命令、环境、通过结果、public release/checksum引用；
- `receiver-acceptance.md`：最初为 pending，只在 receiver commit 和 BobNote compatibility set均有真实证据时填写 accepted。

manifest 由 repository script 从已提交 tree生成/校验，按 path稳定排序，内容 hash基于 Git blob bytes而非工作区换行转换。脚本必须先验证 `HEAD`/指定 revision clean且与 manifest donor commit一致。选择 JSON + Markdown 是为了机器校验与审阅并存；只写一段 handoff note无法发现漏文件或内容漂移。

### 2. Inventory 覆盖 Kotlin实现、测试、fixtures和 Swift facade来源

允许交接的文件集合只来自 donor commit，并至少覆盖：

- `deckstring/src/commonMain/kotlin/**`；
- `deckstring/src/commonTest/kotlin/**` 及其 test resources/fixtures（如存在）；
- `deckstring/src/commonMain/swift/DeckStringDecoderFacade.swift`；
- 为理解 compilation 与依赖版本所需的 `deckstring/build.gradle.kts`、version/lock metadata快照。

build/release scripts、XCFramework zip、demo project和 GitHub workflows 不复制进 receiver；它们在 manifest中只作为 donor baseline reference。Swift facade source会进入 receiver overlay并产生适配 diff，不作为 `:deckstring` Kotlin module source继续编译。

### 3. Donor baseline 先于任何 receiver adaptation

在 frozen commit上按现有仓库声明运行：Gradle checksum/wrapper检查、`:deckstring:jvmTest`、`:deckstring:iosSimulatorArm64Test`、Swift facade/local binary consumer与 OpenSpec strict validation。记录 fixture count、关键行为类别、toolchain和 artifact checksum；不把现有工作区未提交结果写成 donor证据。

Receiver 使用同一 fixtures做 Kotlin 2.4.10与 overlay parity。允许的差异只有 package/module重定位、构建版本统一、移除 SKIE、Core bridge与 Swift import/module适配；任何 algorithm、error case、numeric boundary、sorting或 Codable差异都需停止接收并另开行为 change。

### 4. Ownership 是显式状态机，不因复制文件自动完成

`receiver-acceptance.md` 状态只允许：

1. `pending`：donor manifest已冻结，receiver尚未完整验证；
2. `accepted`：记录 receiver完整 commit、其 donor/adaptation audit、Shared Pod consumer结果，以及 BobNote `{commit, gitlink, Podfile.lock}` compatibility set；
3. 后续若要 `archived` donor remote，必须由另一个 change/明确授权处理，不属于本状态机自动转换。

复制 source或 Shared单仓 tests通过不等于 accepted；BobNote真实 consumer尚未切换时仍为 pending。这样避免 receiver build成功但 Swift overlay/历史数据不兼容时过早终止旧 owner。

### 5. `0.1.0-kmp.5` 是整组 rollback evidence，不是 parallel release line

现有 tag、wrapper revision、XCFramework checksum、Swift interface/symbol和 retained-object证据继续保留。BobNote在新 CocoaPods compatibility set出问题时可以恢复包含 `.5` pin的完整旧 App commit；新 App commit不得同时链接 `.5` 和 Shared Core，也不得用 runtime flag动态选择。

accepted 后，本仓库 README/maintainer note标明：BobNote product的新 deckstring source owner是 BobNoteSharedKMP，本仓库不为 BobNote功能发布新的平行 `kmp.N` artifact。若独立外部 consumer仍需维护，必须通过后续独立决策明确范围，不能让它隐式恢复双 owner。

### 6. Git 历史保留在 donor，receiver用 provenance引用

Receiver普通复制文件并在 commit message/doc中引用 donor full hash；不使用 `git subtree`、`filter-repo`、submodule或伪造 author提交。adaptation report逐文件/主题说明与 donor的差异，自动校验 unchanged files hash，人工审查 changed files semantic diff。

这一选择牺牲 `git blame` 在 receiver中的逐行原历史，但换来单一 owner和简单 build graph；完整 blame/history始终可通过 donor commit追溯。复制整段 Git历史会模糊两个仓库的责任边界，因此拒绝。

## Risks / Trade-offs

- **[manifest遗漏隐式 fixture或 build input]** → 从 Git tree和 Gradle source sets双向枚举，receiver再做缺失/额外文件校验；不手写清单作为唯一来源。
- **[donor worktree脏改动污染快照]** → hash只读取指定 commit的 Git blobs，baseline要求 clean detached/worktree或显式 revision checkout。
- **[Kotlin 2.4.10适配被误当行为变化]** → adaptation report逐项分类，使用同一 common/Swift fixtures；非允许差异阻止 acceptance。
- **[owner切换过早导致无维护者]** → acceptance必须包含 receiver和BobNote两级证据，pending期间donor仍是owner。
- **[历史保留被误解为继续双发布]** → README与acceptance明确“历史/回滚”与“新产品owner”区别；accepted后不得为BobNote并行发版。
- **[receiver缺少逐行 blame]** → manifest提供full commit/path/hash，adaptation doc提供映射；需要历史时回到donor repo查询。

## Migration Plan

1. 在当前 change worktree固定 donor commit，生成并自校验 manifest/inventory。
2. 从该 commit运行 donor JVM、iOS simulator、Swift consumer与OpenSpec baseline，写入真实证据。
3. 将 manifest与允许适配说明交给 BobNoteSharedKMP；receiver导入并返回完整 commit及差异报告。
4. 复核 receiver source completeness、Kotlin/Swift parity、无SKIE边界和 Pod consumer结果，状态仍保持pending。
5. BobNote锁定 receiver commit并完成 CocoaPods compatibility set门禁后，填写 accepted三仓证据并更新maintainer说明。
6. 保留源码、CI、tags、release和wrapper；远端归档或进一步清理另开change。

Rollback：accepted前直接拒绝receiver candidate；accepted后若新路径回归，BobNote恢复上一完整App commit和`.5` pin。本仓库不需要回写或删除数据，也不发布临时双链接补丁。
