# DeckStringDecoderKMP 版本号规则文档计划

## Summary

采用固定 release tag 格式：

```text
<semver>-kmp.<n>
```

当前 public wrapper 最新 release 是 `0.1.0-kmp.2`。本次 `DeckStringCore` parity/optimization 不改变 Swift-facing API、platform、SwiftPM product/module 名称，因此下一次真实 release tag 应为：

```text
0.1.0-kmp.3
```

## Key Changes

- 在 `README.md` 的 `Release` 段新增版本号规则，说明：
  - `semver` 表示 Swift-facing API 版本。
  - `kmp.N` 表示 KMP/SKIE binary artifact 发布序号。
  - Swift API、platform、product/module 名不变时，只递增 `kmp.N`。
  - API 兼容性新增时递增 minor，例如 `0.2.0-kmp.1`。
  - API 破坏性变化在 `1.0.0` 前递增 minor；稳定后按 SemVer 递增 major。
  - 文档-only 且不改变 artifact URL/checksum 时不发新版本。
- 必选修改 `.github/workflows/release.yml` 的 `release_tag` input description，写明格式和示例，使用以下文案：

```yaml
description: "Release tag for DeckStringDecoderKMPPackage. Format: <semver>-kmp.<n>, for example 0.1.0-kmp.3"
```

- 不修改 release 执行逻辑、Gradle 配置、wrapper 更新脚本或 artifact 生成流程。

## Interfaces

- GitHub Actions 手动输入 `release_tag` 的约定正式固定为 `<semver>-kmp.<n>`。
- Swift public API、SwiftPM product/module、artifact 文件名、wrapper repo URL 均不变化。

## Test Plan

- 检查 `release.yml` YAML 语法有效。
- 确认 `README.md` 中下一次推荐版本为 `0.1.0-kmp.3`。
- 运行或确认 `gh workflow list` 能继续识别 `Release` workflow。
- 不触发真实 Release workflow，因为它会修改 wrapper repo、打 tag、创建 GitHub Release。

## Assumptions

- 当前 public wrapper 最新 tag 保持为 `0.1.0-kmp.2`。
- 这次 core parity/optimization 不改变 Swift-facing API，所以不升到 `0.2.0`。
- 下一次真实 release 使用 `0.1.0-kmp.3`。
