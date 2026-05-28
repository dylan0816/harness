---
name: key-points-mem
description: 结构化通用要点记忆与知识生命周期管理工具。用于沉淀跨工程复用的关键知识点、踩坑记录、最佳实践。仅当知识具有通用性且经用户主动授权时才写入。当用户需要排查问题、建立通用知识库、或更新旧有技术方案时调用。
---

# 要点记忆 (Point Memory) 核心机制

> **定位**: `key-points-mem` 是 harness 工程的**通用知识库**，仅沉淀具有**跨工程复用价值**的知识点。
>
> **写入边界**: `.claude/skills/key-points-mem/references/` 在业务工程中是软链接路径，AI **不得自动写入**。仅当用户明确授权且知识满足通用性要求时方可写入。
>
> **与 Context Guard 的关系**: Context Guard 负责工程级对话沉淀（自动评估 + 用户确认，按天归档），key-points-mem 负责通用知识提炼（用户主动授权后 AI 提炼，按主题归档）。两个系统独立运行。从 `.context-guard/` 升级到 key-points-mem 由用户手动发起。
>
> **文件格式**: 所有 reference 文件遵循统一格式：`现象 → 原因 → 解决 → 经验 → 标签 → 来源`。格式模板见 `references/index.md`。
