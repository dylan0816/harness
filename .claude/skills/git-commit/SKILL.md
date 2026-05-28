---
name: git-commit
description: 自动分析代码变更并生成符合 Conventional Commits 规范的语义化 Git 提交信息，支持按需推送至远端。在收到 "帮我提交"、"git 提交"、"commit 一下"、"push"、"提交并推送" 等请求时调用。
---

# Auto Git Commit

本 Skill 用于创建标准化、语义化的 Git 提交，严格遵循 [Conventional Commits](https://www.conventionalcommits.org/) 规范。通过分析实际 diff 内容来确定合适的提交类型（type）、范围（scope）和描述（description）。

---

## 提交格式

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### 提交类型 (Type)

| 类型 | 用途 |
|------|------|
| `feat` | 新功能 |
| `fix` | 修复 Bug |
| `docs` | 仅文档变更 |
| `style` | 格式/样式调整（不影响逻辑） |
| `refactor` | 代码重构（非新增功能/修复 Bug） |
| `perf` | 性能优化 |
| `test` | 新增/更新测试 |
| `build` | 构建系统/依赖变更 |
| `ci` | CI/配置变更 |
| `chore` | 维护/杂项 |
| `revert` | 回滚提交 |

### 破坏性变更 (Breaking Changes)

```
# 方式一：在 type/scope 后加感叹号
feat!: remove deprecated endpoint

# 方式二：在 footer 中标注 BREAKING CHANGE
feat: allow config to extend other configs

BREAKING CHANGE: `extends` key behavior changed
```

---

## 工作流程

### 1. 分析变更 (Analyze Diff)

优先查看已暂存的变更；若未暂存，则查看工作区变更。

```bash
# 查看已暂存的 diff
git diff --staged

# 若未暂存，查看工作区 diff
git diff

# 查看文件状态
git status --porcelain
```

### 2. 暂存文件 (Stage Files)

若没有任何文件被暂存，或需要按逻辑分组暂存：

```bash
# 暂存指定文件
git add path/to/file1 path/to/file2

# 按模式暂存
git add *.test.*
git add src/components/*

# 交互式暂存
git add -p
```

> ⚠️ **安全提醒**：永远不要提交敏感文件（如 `.env`、`credentials.json`、私钥等）。

### 3. 生成提交信息 (Generate Commit Message)

基于 diff 分析确定以下要素：

- **Type**：这是什么类型的变更？
- **Scope**：影响的是哪个模块/领域？
- **Description**：一句话概括变更内容（使用现在时、祈使句，控制在 72 字符以内）

**提交日志必须使用中文编写。** 除非项目本身或用户明确要求使用英文，否则默认以中文输出提交信息。

### 4. 执行提交 (Execute Commit)

```bash
# 单行提交
git commit -m "<type>[scope]: <description>"

# 多行提交（含 body/footer）
git commit -m "$(cat <<'EOF'
<type>[scope]: <description>

<optional body>

<optional footer>
EOF
)"
```

### 5. 推送至远端 (Push to Remote)

根据用户意图判断是否需要推送。识别触发推送的典型表达：

- "提交并推送"
- "push 一下"
- "推到远端"
- "commit and push"
- "提交到远程"

若用户明确要求推送，执行：

```bash
# 先检查当前分支及追踪关系
git branch -vv

# 推送到当前分支的默认上游
git push

# 若当前分支没有上游追踪关系，先建立再推送（需确认分支名）
git push -u origin <branch-name>
```

> ⚠️ **安全提醒**：
> - 推送前确认当前分支名，避免误推送到受保护分支（如 `main`/`master`）。
> - **禁止** 使用 `git push --force` 或 `git push -f`。
> - 若推送被拒绝，先拉取最新代码（`git pull`）处理冲突后再推送，不要强制覆盖。

---

## 最佳实践

- **单一逻辑**：每个提交只包含一个逻辑变更
- **现在时**：用 "添加" 而非 "添加了"
- **祈使句**：用 "修复 bug" 而非 "修复了 bug"
- **中文优先**：提交日志默认使用中文编写
- **关联 Issue**：如 `Closes #123`、`Refs #456`
- **控制长度**：描述行尽量不超过 72 个字符

---

## Git 安全协议

- **禁止** 修改 git config
- **禁止** 在未获得明确授权的情况下运行破坏性命令（如 `--force`、hard reset）
- **禁止** 跳过 hooks（`--no-verify`），除非用户主动要求
- **禁止** 向 main/master 分支强制推送
- **禁止** 使用 `git push --force` 或 `git push -f`
- 若提交因 hook 失败，应修复问题后创建**新的提交**，不要 amend
