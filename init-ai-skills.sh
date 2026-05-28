#!/bin/bash

# =================================================================
# AI Skills 分发部署脚本 (Bash 版)
# =================================================================

# 定义颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

TARGET_FOLDER="$1"

# 1. 路径及权限校验
if [ -z "$TARGET_FOLDER" ]; then
    echo -e "${RED}❌ 错误: 请提供目标工程的路径。${NC}"
    exit 1
fi

SOURCE_PATH=$(pwd)
SOURCE_AGENT_PATH="$SOURCE_PATH/CLAUDE.md"
SOURCE_SKILLS_PATH="$SOURCE_PATH/.claude/skills"

if [ ! -f "$SOURCE_AGENT_PATH" ]; then
    echo -e "${RED}❌ 错误: 请在包含 CLAUDE.md 的根目录下执行此脚本。${NC}"
    exit 1
fi

if [ ! -d "$TARGET_FOLDER" ]; then
    echo -e "${RED}❌ 错误: 目标路径不存在 ($TARGET_FOLDER)。${NC}"
    exit 1
fi

# 解析为绝对路径 (兼容 macOS 和 Linux)
TARGET_PATH=$(cd "$TARGET_FOLDER" && pwd)

echo -e "${CYAN}🚀 开始向目标工程分发 AI 技能环境...${NC}"

# 2. 创建软链接
echo -e "${CYAN}🔗 [1/3] 正在创建核心规范链接...${NC}"
# 强制创建/更新 CLAUDE.md 链接
if ! ln -sf "$SOURCE_AGENT_PATH" "$TARGET_PATH/CLAUDE.md"; then
    echo -e "${YELLOW}❌ 创建 CLAUDE.md 软链接失败！${NC}"
    exit 1
fi

# 创建 .claude/skills 真实目录，然后为每个 skill 创建独立软链接
mkdir -p "$TARGET_PATH/.claude/skills"

for skill_dir in "$SOURCE_SKILLS_PATH"/*/; do
    skill_name=$(basename "$skill_dir")
    if ! ln -sfn "$skill_dir" "$TARGET_PATH/.claude/skills/$skill_name"; then
        echo -e "${YELLOW}❌ 创建 .claude/skills/$skill_name 软链接失败！${NC}"
        exit 1
    fi
done

# 分发 settings.json（钩子配置）
SOURCE_SETTINGS="$SOURCE_PATH/.claude/settings.json"
if [ -f "$SOURCE_SETTINGS" ]; then
    ln -sf "$SOURCE_SETTINGS" "$TARGET_PATH/.claude/settings.json"
fi

# 分发 hooks 脚本
SOURCE_HOOKS_DIR="$SOURCE_PATH/.claude/hooks"
mkdir -p "$TARGET_PATH/.claude/hooks"
if [ -d "$SOURCE_HOOKS_DIR" ]; then
    for hook_file in "$SOURCE_HOOKS_DIR"/*; do
        hook_name=$(basename "$hook_file")
        ln -sf "$hook_file" "$TARGET_PATH/.claude/hooks/$hook_name"
    done
fi

# 3. 注入 IDE 指令文件
echo -e "${CYAN}🛠️ [2/3] 配置 IDE 引导规则...${NC}"
# .cursorrules (物理文件，支持本地化覆盖)
RULES_CONTENT="你是一个通用的工程智能助手。\n在开始工作前，请务必阅读并严格遵循项目根目录下的 CLAUDE.md，**启动协议** 必须执行。\n执行任务请遵循 REAP 流程。\n\n【每轮对话结束时必须进行知识沉淀评估】\n逐项检查本轮是否涉及：1.架构决策 2.根因分析 3.规范确立 4.知识盲区 5.方案对比 6.踩坑记录。\n命中 → 写入 .context-guard/ 回复\"已记录\"或\"等待确认\"。\n未命中 → 回复\"已评估知识沉淀价值（跳过：原因）\"。"
echo -e "$RULES_CONTENT" > "$TARGET_PATH/.cursorrules"

# 4. 精准更新 .gitignore
echo -e "${CYAN}🙈 [3/3] 更新目标工程的 .gitignore...${NC}"
GITIGNORE_PATH="$TARGET_PATH/.gitignore"
REQUIRED_IGNORES=("AGENTS.md" "CLAUDE.md" ".cursorrules" ".claude/skills/*" ".claude/settings.json" ".claude/hooks/*" ".context-guard/transcripts/*")

# 确保文件存在
if [ ! -f "$GITIGNORE_PATH" ]; then
    touch "$GITIGNORE_PATH"
fi

LINES_TO_ADD=()

# 检查哪些忽略项还不在文件中
for ITEM in "${REQUIRED_IGNORES[@]}"; do
    # 使用 grep 的 -F(固定字符串) -x(整行匹配) 来实现精准判定
    if ! grep -qFx "$ITEM" "$GITIGNORE_PATH" 2>/dev/null; then
        LINES_TO_ADD+=("$ITEM")
    fi
done

if [ ${#LINES_TO_ADD[@]} -gt 0 ]; then
    # 如果文件不为空且最后一行没有换行符，先补一个换行
    if [ -s "$GITIGNORE_PATH" ] && [ -n "$(tail -c 1 "$GITIGNORE_PATH")" ]; then
        echo "" >> "$GITIGNORE_PATH"
    fi

    echo "# AI Skills Support" >> "$GITIGNORE_PATH"
    for LINE in "${LINES_TO_ADD[@]}"; do
        echo "$LINE" >> "$GITIGNORE_PATH"
        echo -e "${GREEN}✅ 已添加忽略: $LINE${NC}"
    done
else
    echo -e "${GRAY}ℹ️ .gitignore 已包含所有必要的忽略项。${NC}"
fi

echo "------------------------------------------------"
echo -e "${GREEN}✨ 部署完成！目标工程 AI 环境已就绪。${NC}"
