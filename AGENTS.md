# DeckStringDecoder Agent 指南

## 语言与文档规则

- 后续计划说明、设计讨论、OpenSpec proposal/design/tasks/spec 正文默认使用中文（简体）。
- 在 OpenSpec artifacts 中保留解析依赖的英文结构标记，例如：
  - `## ADDED Requirements`
  - `### Requirement:`
  - `#### Scenario:`
  - `**WHEN**`
  - `**THEN**`
  - `- [ ] 1.1`
- 技术标识符、文件路径、命令、API 名称、版本号保持原文。
- 如果用户明确要求英文，或上游工具/schema 明确要求英文，则按该更高优先级要求执行。

## OpenSpec 注意事项

- `openspec/config.yaml` 已包含中文写作约束；本文件作为面向 agent 的项目级长期规则。
- 修改 OpenSpec artifacts 时，正文可中文化，但不要翻译会影响 OpenSpec 解析的结构性标题、关键字和 checkbox 格式。
