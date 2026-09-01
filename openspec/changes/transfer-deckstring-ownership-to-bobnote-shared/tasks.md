## 1. 冻结 donor 快照

- [x] 1.1 先为 manifest 生成/校验器增加自动化测试，覆盖指定 commit、稳定排序、Git blob SHA-256、脏工作区拒绝、漏文件与额外文件拒绝，并运行该测试确认在实现前以预期原因失败
- [x] 1.2 实现从 `af490607cc79c5f28152537a375dd07adf9f099d` 读取 Git tree 的 manifest 生成/校验脚本，生成 `handoff/bobnote-shared/deckstring-donor-manifest.json`，并运行两次生成后比较 byte-for-byte 一致且校验器通过
- [x] 1.3 用 source-set 与 Git tree 双向审计 manifest，确认 common Kotlin source、common tests/resources、Swift facade source、build/version/lock context 全覆盖，且 receiver 清单不包含 XCFramework、demo、workflow 或绝对路径

## 2. 建立 donor 行为基线

- [x] 2.1 在冻结 commit 与仓库声明的 JDK/Gradle 下运行 `./gradlew :deckstring:jvmTest :deckstring:iosSimulatorArm64Test --console=plain`，记录环境、fixture 类别和通过结果到 `handoff/bobnote-shared/donor-baseline.md`
- [x] 2.2 运行未修改 Swift facade/local binary consumer 的 decode、encode、error、sideboard、Codable、Equatable、Hashable、numeric-boundary 与 round-trip tests，并把真实命令、结果和 artifact checksum 写入 donor baseline
- [x] 2.3 运行 Gradle Wrapper checksum、dependency verification、CI/release input audit 与 `openspec validate --changes --strict --no-interactive`，确认 donor 证据只来自已提交 commit 且没有跳过失败门禁

## 3. 交付与接收合同

- [x] 3.1 编写 `handoff/bobnote-shared/README.md`，固定双方 owner、允许的 Kotlin 2.4.10/去 SKIE/Core/overlay 适配、禁止的算法/行为变化、三仓验收顺序与整组回滚，并用文档链接检查确认所有引用可解析
- [x] 3.2 创建状态为 `pending` 的 `receiver-acceptance.md`，让校验器拒绝缺少完整 receiver commit、Shared consumer evidence 或 BobNote `{commit, gitlink, Podfile.lock}` compatibility set 的 `accepted` 状态，并运行负例测试证明门禁生效
- [x] 3.3 接收 BobNoteSharedKMP 的 provenance/adaptation report 后，运行逐文件 completeness/hash/semantic-diff 审计，确认所有改动均属于已批准适配且 donor behavior parity 全绿
- [x] 3.4 BobNote CocoaPods compatibility set 完成后，将 acceptance 更新为 `accepted` 并记录三仓完整 commits、Pod lock hash 与验证证据；重新运行 acceptance validator 确认状态转换可审计

## 4. 所有权与历史边界

- [x] 4.1 仅在 acceptance 通过后更新 README/maintainer 说明，标明 BobNote 产品的新 deckstring owner 为 BobNoteSharedKMP、`0.1.0-kmp.5` 仅为历史/整组回滚基线，并以 `rg` 确认没有文案声称继续为 BobNote 平行发版
- [x] 4.2 审计 Git history、tags、release references、wrapper checksum、source、demo 与现有 CI 均未被本 change 删除或重写，并确认 remote archive 仍明确留给后续独立决策

## 5. 最终验证

- [x] 5.1 运行 manifest/acceptance 自动化测试、JVM/iOS common tests、Swift consumer tests、dependency verification 与 `git diff --check`，保存完整交接验证摘要
- [x] 5.2 运行 `openspec validate transfer-deckstring-ownership-to-bobnote-shared --strict --no-interactive`、all-active 与 archived strict validation，确认 change 和仓库历史规格全部通过
