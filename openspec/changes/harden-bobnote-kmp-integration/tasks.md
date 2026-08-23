## 1. Swift facade 兼容

- [x] 1.1 保留显式相等语义，并导出原 Swift source package 的四个 equality ABI 入口
- [x] 1.2 验证 Swift-facing equality、Hashable、Codable 与错误比较行为
- [x] 1.3 在 artifact gate 中验证 device/simulator slices 均包含四个迁移符号
- [x] 1.4 用已有 BobNote 增量产物验证同名 module 原位替换可以链接

## 2. Shared core 多目标验证

- [x] 2.1 增加 JVM target
- [x] 2.2 在 JVM 与 iOS simulator 运行同一套 `commonTest`
- [x] 2.3 在 CI 与 release workflow 增加 JVM test gate

## 3. 构建链可复现性

- [x] 3.1 固定 Gradle distribution SHA-256
- [x] 3.2 固定 OpenSpec 版本与 GitHub Actions commit SHA
- [x] 3.3 校验 release tag 格式与远端唯一性，并串行化发布任务
- [x] 3.4 验证 OpenSpec、wrapper、artifact 结构与 checksum

## 4. 发布与真实接入

- [x] 4.1 生成并验证 release XCFramework 与 local SwiftPM consumer
- [ ] 4.2 发布 `0.1.0-kmp.4` wrapper artifact 并回读公开 checksum
- [ ] 4.3 让 BobNote 精确锁定新 release，并通过完整 UT、Debug 与 Release build
