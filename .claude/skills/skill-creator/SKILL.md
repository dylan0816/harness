---
name: skill-creator
description: 创建和维护 harness 工程中的通用技能。在收到"创建新技能"、"添加技能"、"新建 skill" 等请求时调用。
---

# Skill Creator — 技能创建与维护指南

> 用于在当前 harness 工程中创建新的通用技能，或重构现有技能。

---

## 技能定义

一个技能 = 一个目录 + 一份 `SKILL.md`，按需包含 `references/` 和 `scripts/`。

### 目录结构

```
.claude/skills/<skill-name>/
├── SKILL.md              # 必选 — 技能描述、触发条件、使用方法
├── references/           # 可选 — 参考资料（仅跨工程通用知识点）
└── scripts/              # 可选 — 可执行脚本
```

### 准入标准

新技能必须同时满足：

1. **通用型** — 可被多个业务工程复用，非业务专属
2. **独立职责** — 不与现有技能的功能重叠
3. **有触发场景** — AI 能在明确的条件下识别并调用

> 业务专属技能（如特定项目的配置助手、特定框架的部署助手）应存放在对应业务工程中，不要放入 harness。

---

## SKILL.md 标准结构

```markdown
---
name: <skill-name>
description: <一句话描述技能用途，用于触发匹配>
---

# <技能名称>

> 定位：<一句话说明技能解决什么问题>

## 触发条件

<AI 在什么场景下调用此技能>

## 使用方法

<具体的执行步骤或规则>
```

---

## 创建流程

### Step 1: 确认必要性

自检清单：

- [ ] 这个技能能被 ≥2 个业务工程复用？
- [ ] 现有技能中是否有功能重叠？
- [ ] AI 能在什么场景下自动识别需要调用它？
- [ ] 如果只是一个代码片段，能否放入 key-points-mem 而非独立技能？

若以上任一不通过，停止创建。

### Step 2: 创建目录和 SKILL.md

```bash
mkdir .claude/skills/<skill-name>
```

按上面的模板编写 `SKILL.md`。文件名统一小写+连字符。

### Step 3: 注册到 CLAUDE.md

在 CLAUDE.md 的「技能索引」表格中新增一行（仅作快速概览，可选）：

```
| <skill-name> | <一句话用途> |
```

### Step 4: 确认索引完整性

确保 `README.md` 的技能清单也同步更新（如存在）。

---

## 现有技能清单

| 技能 | 路径 | 职责 |
|------|------|------|
| git-commit | `.claude/skills/git-commit/` | 语义化 Git 提交与推送 |
| context-guard | `.claude/skills/context-guard/` | 对话价值评估与工程级沉淀 |
| game-config-builder | `.claude/skills/game-config-builder/` | 生成游戏配置表/Excel |
| golang-patterns | `.claude/skills/golang-patterns/` | Go 语言惯用模式 |
| key-points-mem | `.claude/skills/key-points-mem/` | 跨工程通用知识库 |
| narrative-designer | `.claude/skills/narrative-designer/` | 剧情与神话设定设计 |
| python-expert | `.claude/skills/python-expert/` | Python 编码准则 |
| **skill-creator** | `.claude/skills/skill-creator/` | **技能创建与维护（本文件）** |
