# DeckStringDecoder donor baseline

## 结论

状态：**PASS**（ownership 仍为 `pending`）。

本基线只测试 immutable donor commit `af490607cc79c5f28152537a375dd07adf9f099d` 的源码与既有 Swift facade。执行前后 `git status --porcelain=v1` 均为空；Apply 工作树中的 OpenSpec、脚本和交接文档没有进入 donor build。

## 冻结输入

- Repository：`git@github.com:SunsetWan/DeckStringDecoderKMP.git`
- Donor commit：`af490607cc79c5f28152537a375dd07adf9f099d`
- [Donor manifest](./deckstring-donor-manifest.json) SHA-256：`988b953d23d578170fa16d4dde75eea8e3f9a427e07d3b40c350ea6bf46ae770`
- Manifest inventory：12 files（2 production Kotlin、2 common tests、1 Swift facade、7 build context）
- Manifest 两次独立生成 byte-for-byte 一致，Git tree/source-set 双向 diff 为空。

## 执行环境

- macOS 26.6.1（arm64）
- Xcode 26.4.1（17E202），iPhone 17 / iOS Simulator 26.5
- Swift 6.3.1
- OpenJDK 21.0.11
- Gradle 9.3.0
- Kotlin/KGP 2.3.20（Gradle launcher 自身显示的 embedded Kotlin 2.2.21 不等于项目 KGP）
- SKIE 0.10.11

## Kotlin common behavior

命令：

```sh
./gradlew :deckstring:jvmTest :deckstring:iosSimulatorArm64Test --console=plain
```

结果：`BUILD SUCCESSFUL`，JVM `21/21`、iOS Simulator arm64 `21/21`，均为 0 skipped、0 failure、0 error。

同一套 common tests 覆盖：model construction、canonical sorting、Standard/Wild golden deck strings、decode、encode、decode-encode-decode round trip、sideboard、multi-copy cards、malformed input、truncated payload、invalid reserved/version/format/hero count、varint boundary 与 trailing-byte compatibility。

## Swift-facing behavior

未修改 donor facade 和已提交 local binary consumer，执行：

```sh
./gradlew :deckstring:verifyDeckStringDecoderSwiftPMConsumer --console=plain
```

结果：`BUILD SUCCESSFUL`；已提交 consumer `3/3` 通过，覆盖：

- `DeckStringDecoder` 构造、decode、encode 与 round trip；
- Standard/Wild、sideboard 与总卡数；
- `DeckStringError` 映射；
- `Deck`、`Card`、`SideboardCard`、`DeckFormat` 的 Codable、Equatable、Hashable 行为。

冻结 binary 另使用 [SwiftNumericBoundaryProbeTests.swift](./SwiftNumericBoundaryProbeTests.swift) 做外部补充探针；探针不修改 facade、artifact 或已提交 consumer source。iPhone 17 consumer 合计 `4/4` 通过，确认 hero、card dbfId/count、sideboard dbfId/count/owner 的 `Int32.max + 1` 均保持既有 `.unexpectedEndOfData` 拒绝行为。

当前机器从 donor commit 重建的 artifact：

- Size：1,648,304 bytes
- SHA-256 / SwiftPM checksum：`3bac1c8ad1e948368afb01f7e2da7aa65110b1361540bb4820da62d7cf98d7b1`
- `scripts/verify-swiftpm-artifact.sh`：PASS

公开 rollback baseline `0.1.0-kmp.5` 另行回读验证：

- Wrapper tag commit：`2476e1adbcdd1a3a5028ffc639fe67da6b989b44`
- Download size：1,647,951 bytes
- Published checksum：`c3f1e218e3146363ec1cafd37b7a406da2fdd7694328b55aead6077fc3e50ccb`

本机重建 checksum 与历史发布 checksum 是两个不同构建实例；rollback 只使用已发布 `.5` compatibility set，不把本机重建产物冒充历史 release。

## 构建输入与失败门禁

- `gradle-wrapper.jar` SHA-256：`b3a875ddc1f044746e1b1a55f645584505f4a10438c1afea9f15e92a7c42ec13`
- Gradle distribution SHA-256：`0d585f69da091fc5b2beced877feab55a3064d43b8a1d46aeb07996b0915e0e0`
- `./gradlew --offline --version`：PASS；wrapper files 与 donor Git tree 无 diff。
- Donor commit 没有预提交 `gradle/verification-metadata.xml`。为审计已解析依赖，执行 `--write-verification-metadata sha256` 生成 101 个 component 的派生 metadata（SHA-256 `ed5c73013243ae5153f7c1f114d27103dff3c6d6a89a8120a4f96e4c8249513f`），随后以 `--dependency-verification strict` 重跑 JVM/iOS tests：PASS。派生文件随后删除以恢复 clean donor；这项证据不得被描述为 donor 已有的长期 dependency lock。
- 两个 workflow 的所有 `uses:` 均为完整 40 位 commit；JDK 21、OpenSpec 1.10.0、release tag uniqueness/concurrency、artifact/local/public consumer gates 均存在；没有 `continue-on-error: true` 或 branch/tag HEAD action input。
- Donor `openspec validate --changes --strict --no-interactive`：1/1 PASS。
- Apply 工作树同一命令：2/2 PASS。

以上命令均以非零退出码作为失败，没有跳过失败门禁。
