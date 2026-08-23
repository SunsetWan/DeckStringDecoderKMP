## ADDED Requirements

### Requirement: KMP build inputs are reproducible
项目 SHALL 将安全敏感的构建与 CI 输入固定为不可变或经过 checksum 验证的值。

#### Scenario: Gradle distribution is checksum verified
- **WHEN** Gradle Wrapper 下载配置的 distribution
- **THEN** `gradle-wrapper.properties` SHALL include the SHA-256 published for that exact Gradle distribution

#### Scenario: CI tools are pinned
- **WHEN** CI 或 release workflow 安装 OpenSpec 或调用 GitHub Action
- **THEN** OpenSpec SHALL use an exact version
- **THEN** each GitHub Action SHALL use a full commit SHA with its human-readable release tag retained as a comment

### Requirement: Release retains full verification
release workflow SHALL 在报告发布完成前运行 specification validation、JVM 与 iOS common tests、artifact verification、local consumer tests 和 public consumer tests。

#### Scenario: Release tag is safe and unique
- **WHEN** 执行者请求 binary release
- **THEN** release tag SHALL 严格匹配 `<semver>-kmp.<positive-integer>`
- **THEN** workflow SHALL 在修改 wrapper 前拒绝已经存在的远端 tag
- **THEN** 同一时间 SHALL 最多运行一个 binary release job

#### Scenario: New KMP artifact is published
- **WHEN** release `0.1.0-kmp.4` is requested
- **THEN** the workflow SHALL generate and checksum the XCFramework zip
- **THEN** the public wrapper SHALL point to the uploaded artifact with the verified checksum
- **THEN** the public consumer SHALL pass through the Swift-facing API

#### Scenario: Packaged migration ABI is verified
- **WHEN** artifact verifier 检查 release XCFramework zip
- **THEN** 每个 Apple slice SHALL 包含 source-package replacement 所需的四个 equality symbol
