# 多工程 AI 协作环境

> 一个工程，多种 AI CLI；一个好用提示词，又想同步到多个项目——你受够了到处复制、漏改、行为不一致了吗？

---

## 这是解决什么问题的

我遇到的混乱主要来自两件事：

1. **同一个工程里同时使用多种 AI CLI / IDE**：Claude Code、Zed、Cursor 等工具各有各的 Skill 规范、提示词、流程约定和本地记忆规则。一旦切换会话、关闭终端或迁移环境，状态就容易散落一地。
2. **一个工程里提炼出的提示词和规范，很快会想复用到别的项目**：某个项目里验证过的工作流、踩坑规则、代码审查习惯，往往不是只对这个项目有价值。但如果靠手动复制，每次同步都要翻多个目录，漏一个地方就会出现行为不一致。

这两件事叠在一起，就是典型的本地 AI 协作环境失控：**累，而且不可靠。**

本工程就是为这个场景造的：**写一次，全部生效。**

核心思路很简单：把 AI 协作规范（`CLAUDE.md`）、Skills、Hooks、IDE 引导规则都放在这个仓库里集中维护，再通过软链接和批量部署脚本分发到需要接入的业务工程。这样，同一工程里的多种 AI CLI 可以围绕同一套规则工作；在某个工程中沉淀出的提示词和技能，也能回到 Harness 统一维护，再同步给其他项目。

---

## 怎么工作

```text
                +-------------------------+
                |         Harness         |
                |      (唯一真相源)        |
                |                         |
                |  CLAUDE.md              |
                |  .claude/skills/        |
                |  .claude/hooks/         |
                |  .claude/settings.json  |
                |  deploy.sh / deploy.ps1 |
                +----+---------+----------+
                     |         |
              软链接 |         | 软链接
                     v         v
              +----------+ +----------+ +----------+
              | 工程 A   | | 工程 B   | | 工程 C   |
              | 多种 AI  | | 多种 AI  | | 多种 AI  |
              +----------+ +----------+ +----------+
```

- **`CLAUDE.md` / Skills / Hooks** -> 软链接分发。源仓库改完，下游工程不用逐个拷贝。
- **`.cursorrules`** -> 物理文件分发。允许下游工程按需本地化覆盖，不强行锁死 IDE 引导词。
- **Hook 保护** -> `check-link-write.py` 阻止 AI 对链接文件直接写入，强制回源修改，保证“唯一真相源”不被打散。
- **批量部署** -> `targets.txt` 里列好所有工程，一次同步；不存在的路径自动跳过，方便 Windows/macOS/Linux 共用同一份目标列表。

---

## 前置条件

| 平台              | 要求                                                                                                                       |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------- |
| **Windows**       | 开启[开发者模式](https://learn.microsoft.com/windows/apps/get-started/enable-your-device-for-development) 或使用管理员终端 |
| **Linux / macOS** | `ln` 命令开箱即用                                                                                                          |

---

## 目录结构

```text
harness/
├── CLAUDE.md                      # AI 协作规范（REAP 流程、行为红线、协作约定）
├── README.md                      # 本文件
├── deploy.sh                      # 部署脚本 (Linux/macOS)
├── deploy.ps1                     # 部署脚本 (Windows)
├── targets.txt                    # 批量部署目标工程列表
├── .cursorrules                   # IDE 引导规则模板
├── .gitignore
└── .claude/
    ├── settings.json              # Hook 触发配置
    ├── settings.local.json        # 本地权限覆盖（不参与分发）
    ├── hooks/
    │   ├── check-link-write.py    # 阻止直接写入软/硬链接
    │   ├── check-end-marker.py    # 强制每轮知识沉淀评估
    │   └── save-transcript.py     # 会话结束时存档 transcript
    └── skills/
        ├── context-guard/         # 上下文沉淀评估
        ├── game-config-builder/   # 生成游戏配置表/Excel
        ├── git-commit/            # 自动 Git 提交与推送
        ├── golang-patterns/       # Go 代码模式、审查与重构
        ├── key-points-mem/        # 通用知识库（REAP R 阶段调用）
        ├── narrative-designer/    # 叙事与世界观设计
        ├── python-expert/         # Python 编码、类型提示、调试
        └── skill-creator/         # 创建/注册新技能
```

---

## 快速开始

### 一次部署一个工程

```bash
# Linux / macOS
./deploy.sh /path/to/project

# Windows（需开发者模式或管理员终端）
.\deploy.ps1 D:\projects\my-app
```

### 一次部署全部工程

把目标路径写进 `targets.txt`，一行一个，`#` 开头为注释：

```text
# 我的业务工程
D:\projects\game-server
D:\projects\admin-panel
/Users/me/work/api-service
```

然后直接运行：

```bash
./deploy.sh
.\deploy.ps1
```

不存在的目标目录会自动跳过，所以一份 `targets.txt` 可以同时包含 Windows 和 macOS/Linux 路径。

### 其他用法

| 场景                 | Bash                         | PowerShell                             |
| -------------------- | ---------------------------- | -------------------------------------- |
| 指定配置文件         | `./deploy.sh -c my-list.txt` | `.\deploy.ps1 -ConfigFile my-list.txt` |
| 先看看会处理哪些目标 | `./deploy.sh -d`             | `.\deploy.ps1 -DryRun`                 |
| 执行前确认           | `./deploy.sh -a`             | `.\deploy.ps1 -Ask`                    |

### 部署了什么

| 产物                    | 类型     | 用途                                                  |
| ----------------------- | -------- | ----------------------------------------------------- |
| `CLAUDE.md`             | 软链接   | 核心 AI 协作规范，供支持的 AI 工具或 IDE 引导规则引用 |
| `.claude/skills/*/`     | 软链接   | 各技能目录，AI 按需加载                               |
| `.claude/settings.json` | 软链接   | Hook 触发配置                                         |
| `.claude/hooks/*.py`    | 软链接   | Hook 脚本                                             |
| `.cursorrules`          | 物理文件 | IDE 引导规则，可按项目本地修改                        |
| `.gitignore` 更新       | 物理文件 | 忽略链接文件和本地沉淀产物，避免污染业务仓库          |

---

## Hook 体系

Hook 由 `.claude/settings.json` 驱动，分发到目标工程后由 Claude Code CLI 自动加载：

| 事件         | 脚本                  | 干什么                                           |
| ------------ | --------------------- | ------------------------------------------------ |
| `PreToolUse` | `check-link-write.py` | AI 要写链接文件时阻断，提示回 Harness 源仓库修改 |
| `Stop`       | `check-end-marker.py` | 每轮对话结束时检查是否做了知识沉淀评估           |
| `SessionEnd` | `save-transcript.py`  | 会话结束时自动存档完整对话记录                   |

---

## 知识沉淀

两套机制保证经验和决策不散落：

| 层级       | 存哪里                                      | 存什么                                   |
| ---------- | ------------------------------------------- | ---------------------------------------- |
| **工程级** | `<业务工程>/.context-guard/`                | 当前工程的对话决策、踩坑记录、上下文资料 |
| **通用级** | `.claude/skills/key-points-mem/references/` | 跨工程可复用的模式、教训、避坑指南       |

每轮对话结束，AI 需要自检是否涉及以下任一信号，命中则沉淀：

1. **架构决策** — 分层、边界、技术选型
2. **根因分析** — 定位原因，而不是只修表面症状
3. **规范确立** — 新的约定、命名、流程或编码规范
4. **知识盲区** — 暴露了团队或 AI 不知道的事
5. **方案对比** — A/B 方案取舍讨论
6. **踩坑记录** — 非显而易见的坑和解决方式

命中任一信号时，将结论写入 `.context-guard/`，回复“已记录”或“等待确认”。全部未命中时，回复“已评估知识沉淀价值（跳过：原因）”。

---

## 技能清单

每个技能通过 `SKILL.md` 定义触发规则和使用说明，AI 按需加载：

| 技能                    | 什么时候触发                         |
| ----------------------- | ------------------------------------ |
| **key-points-mem**      | REAP 的 R 阶段默认调用，检索通用知识 |
| **context-guard**       | 每轮结束，评估上下文沉淀价值         |
| **git-commit**          | “提交”、“commit”、“push”             |
| **golang-patterns**     | Go 代码编写、审查、重构              |
| **python-expert**       | Python 编码、类型提示、调试          |
| **game-config-builder** | 生成游戏配置表/Excel                 |
| **narrative-designer**  | 剧情、世界观、角色与叙事结构设计     |
| **skill-creator**       | “创建新技能”、“注册 skill”           |

---

## 故障排查

| 症状                                 | 原因                         | 怎么办                                          |
| ------------------------------------ | ---------------------------- | ----------------------------------------------- |
| 无法创建符号链接                     | 权限不足                     | Windows 开启开发者模式，或使用管理员终端        |
| 改了 Harness 后下游没有新 skill/hook | 新增目录需要重新创建链接     | 重新运行 `deploy`                               |
| `.cursorrules` 没自动同步            | 它是物理文件，允许项目本地化 | 需要时重新部署或手动更新目标工程                |
| `check-link-write.py` 误阻断         | 写入目标被识别为链接         | 检查路径；`key-points-mem/references/` 是白名单 |
| Hook 超时                            | Python 未安装或不在 PATH 中  | 确保 `python` 可执行                            |

---

## 扩展

加新技能：

```bash
mkdir -p .claude/skills/<new-skill>
# 参考现有 SKILL.md 编写触发规则和内容
# 重新部署即可让目标工程获得新技能链接
```

也可以直接对 AI 说：“用 skill-creator 创建一个新技能”。
