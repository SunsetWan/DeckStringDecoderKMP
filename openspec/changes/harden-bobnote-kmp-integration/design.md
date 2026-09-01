# Design

## Context

BobNote 旧依赖 `HS_DeckStringDecoder` source package，目标依赖 `DeckStringDecoderKMPPackage` binary target；二者共享 Swift module/product 名 `DeckStringDecoder`。全新 DerivedData 可以使用当前 binary，但已有增量对象可能引用 source package 的自动合成 `Equatable` 实现符号，并按 non-resilient source value type 的固定布局生成构造器与属性访问调用。真实 BobNote 链接和运行验证因此比最小 consumer 多覆盖了一层 package replacement 兼容性。

Kotlin core 已在 `commonMain` 中完成单遍 grouping、`ByteArray` writer、预分配下界检查与 malformed varint 防护，本次不改解析算法，也不引入与纯函数解析无关的 Ktor、SQLDelight、Coil、Okio、`expect/actual` 或 `cinterop`。

## Goals / Non-Goals

**Goals:**

- 保持原 Swift source package 的源码与协议行为兼容，并改善同名 module 原位替换的增量链接兼容。
- 保持原 Swift source package 的固定 value-type layout 与构造器/属性 ABI，使旧 object 不只“能链接”，也能正确运行。
- 在 JVM 与 Kotlin/Native iOS simulator 上运行同一套 common tests。
- 让 CI 关键下载和 action 输入可复现、可审计。
- 生成并验证 BobNote 可消费的新 SwiftPM binary release。

**Non-Goals:**

- 不新增 Android、鸿蒙或 UI/render target；本模块是无 UI 的 deckstring domain core。
- 不声称没有基准数据支持的 FFI、GC、内存或速度提升。
- 不改变公开 Swift API，不让 BobNote 直接接触 Kotlin bridge 类型。

## Decisions

### 1. 保留公开相等语义，并补齐迁移期 ABI 入口

facade 继续显式实现 `Card`、`SideboardCard`、`Deck` 与 `DeckStringError` 的 `==`，维持已经发布的 Swift-facing 行为。另以内部 `@_silgen_name` 函数导出 `HS_DeckStringDecoder` 1.0.1 曾由 Swift 编译器生成的四个 equality 符号，使按旧 source package 编译且未重新编译的 BobNote object file 也能链接同名 KMP binary module。

曾尝试删除显式 `==`、让编译器重新合成符号，但 Xcode 26.6 在验证 generated module interface 时把 `DeckStringDecoder.Card` 中的 `DeckStringDecoder` 解析为同名 struct 而非 module，导致 `verify-emitted-module-interface` 失败。因此不依赖编译器合成的接口文本，改为明确而受测试约束的迁移 shim。shim 不设为 `public` Swift API，但必须在 XCFramework 的 device 与 simulator Mach-O 中保留，并由 artifact verifier 检查。

### 2. 固定 source-package 值类型布局

为 `DeckFormat`、`Card`、`SideboardCard`、`Deck`、`DeckStringError` 与 `DeckStringDecoder` 添加 `@frozen`。旧 source package 的 consumer 在编译时可见完整声明，会把这些值类型视为固定布局；未标记 `@frozen` 的 library-evolution binary 则使用 resilient 调用约定。`.4` 虽已补齐 equality symbols 并通过 fresh consumer，但保留旧 `DeckAnnotationTextTests.o` 运行时在首个 `Card(dbfId: 251, count: 2)` 构造器把 `251` 当返回缓冲区地址，稳定触发 `EXC_BAD_ACCESS`。

Xcode 26.6 / Swift 6.3 又会为 fixed-layout types 在 interface 尾部自动生成 module-qualified `BitwiseCopyable`，并为无存储属性的 decoder 生成 `Sendable`；由于 module 与 struct 同名，这些扩展再次被解析成 `DeckStringDecoder.DeckStringDecoder.<Type>` 而无法验证。相关 conformance 因此显式写入类型声明，避免生成有歧义的扩展。最终 `.swiftinterface` 能通过 `verify-emitted-module-interface`，artifact verifier 再检查所有 device/simulator interface 的 `@frozen` 声明。

### 3. 用 JVM target 证明 common core 可移植性

在 KMP module 添加 `jvm()`。现有 `commonTest` 不复制到平台目录，CI 分别执行 `jvmTest` 和 `iosSimulatorArm64Test`。这证明解析逻辑至少跨 JVM 与 Kotlin/Native 编译模型运行，但不把测试 target 描述为 Android production integration。

### 4. 固定构建链输入

- `gradle-wrapper.properties` 记录 Gradle 官方 distribution SHA-256。
- npm 安装固定 OpenSpec 精确版本。
- GitHub Actions 使用完整 commit SHA，并在注释保留可读 tag。
- release workflow 严格校验 `<semver>-kmp.<positive-integer>`、拒绝已存在的远端 tag，并以 concurrency group 防止两个发布同时写 wrapper。

### 5. 让本地 consumer 缓存跟随 artifact 身份

本地 consumer 的 binary target URL 始终是同一个相对路径。若把新 zip 覆盖到该路径却复用固定 DerivedData，Xcode 不会感知 package identity 或版本变化，可能继续运行按上一版 resilient interface 编译的 object；fixed-layout binary 虽能链接，值调用约定仍不兼容并会产生运行时数据损坏。这是本地同路径热替换制造的缓存假象，不是正常 SwiftPM `.4` → `.5` 版本升级流程。

`verifyDeckStringDecoderSwiftPMConsumer` 因此使用 SwiftPM artifact checksum 作为 DerivedData 子目录。相同 artifact 仍能增量复用，不同 artifact 必须重新编译 consumer。对 source package → 同名 binary package 的特殊迁移兼容，则继续由真实 BobNote 旧 object 测试覆盖；不伪造跨任意已发布 binary layout 的热替换兼容。

## Risks / Trade-offs

- `@_silgen_name` 使用编译器级符号名，属于有版本边界的迁移措施；必须同时通过 Mach-O symbol gate、完整 XCFramework consumer 与真实 BobNote 增量链接验证，而不能只检查源码。
- `@frozen` 是公开 ABI 承诺，未来不能在兼容版本中随意增删存储属性或 enum case；代价是以明确稳定性换取 source→binary 原位替换能力。
- `.4` 与 `.5` 的 binary layout 不可在同一个缓存身份下热替换；正常 SwiftPM 版本更新必须触发 consumer 重编译，门禁以 artifact checksum 隔离缓存来显式保证这一点。
- 新增 JVM target 会增加少量 CI 时间，但复用同一套 tests，避免复制测试与语义漂移。
- 固定工具版本会推迟自动升级；后续升级必须显式改值并通过完整门禁。
