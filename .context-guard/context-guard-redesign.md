# context-guard 重构

**标签**: #architecture #convention #decision

> **概述**: context-guard 技能从按天归档重构为按课题归档，记录决策从每轮弹窗改为默认自动记录（仅 A/B 取舍或"暂定"结论时询问），同时移除 #guard 命令族的 DSL 触发方式。归档结构、检索机制、标签体系同步建立。

---

## 2026-05-28 第1轮 — 整体重构

核心改动三项：

1. **归档方式：天 → 课题**。旧版 `YYYY-MM-DD.md` 导致同一件事多轮讨论散落多个文件，检索时必须逐文件全量读取。新版 `<课题>.md` 逐轮追加，一个文件包含完整演进史。配合 `index.md` 索引表（`INDEX_START/END` 标记），AI 先读索引定位，再读课题文件，检索效率大幅提升。

2. **记录决策：全询问 → 默认自动**。旧版每轮弹窗"是否记录"，打断感强。新版默认自动记录，仅两个场景询问：结论涉及 A/B 方案取舍 AI 无法判断用户偏好、用户表态"暂定"等临时结论。`#undo` 提供撤回安全网。

3. **触发方式：移除 #guard 命令族**。`#guard` / `#guard force` / `#guard skip` / `#guard show` 全部删除。理由：用户直接说话就能触发 skill（description 自动匹配），不需要学一套 DSL。

同时建立标签体系：六大信号标签（#architecture / #root-cause / #convention / #knowledge-gap / #decision / #pitfall）+ 自由领域标签。文件顶部 2-3 句概述让 AI 快速判断是否继续阅读，每轮 ≤300 字防膨胀。
