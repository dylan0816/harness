#!/bin/bash

# =================================================================
# Harness 部署脚本 (Bash) — 将 AI 协作规范分发到目标工程
#
# 用法:
#   ./deploy.sh /path/to/proj                           # 单目标 (兼容旧用法)
#   ./deploy.sh /p1 /p2 /p3                             # 多目标
#   ./deploy.sh -c targets.txt                          # 配置文件
#   ./deploy.sh                                         # 默认读取 targets.txt
#   ./deploy.sh -d                                      # 预览
#   ./deploy.sh -a                                      # 执行前确认
#
# 配置文件格式: 每行一个目标路径, # 注释, 空行忽略
# 目标目录不存在时自动跳过 (不视为失败)
# =================================================================

set -euo pipefail

# --- 颜色 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✅ $*${NC}"; }
fail() { echo -e "${RED}❌ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
step() { echo -e "${CYAN}👉 $*${NC}"; }
info() { echo -e "${GRAY}ℹ️  $*${NC}"; }
skip_msg() { echo -e "${GRAY}⏭️  $*${NC}"; }

# --- 参数解析 ---
CONFIG_FILE=""
DRY_RUN=false
ASK_CONFIRM=false
TARGETS=()
HAS_EXPLICIT=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -a|--ask)
            ASK_CONFIRM=true
            shift
            ;;
        -h|--help)
            echo "用法:"
            echo "  $0 /path/to/proj                        # 单目标"
            echo "  $0 /p1 /p2 /p3                          # 多目标"
            echo "  $0 -c targets.txt                       # 配置文件"
            echo "  $0                                      # 默认读取 targets.txt"
            echo "  $0 -d                                   # 预览"
            echo "  $0 -a                                   # 执行前确认"
            exit 0
            ;;
        -*)
            fail "未知参数: $1"
            exit 1
            ;;
        *)
            TARGETS+=("$1")
            HAS_EXPLICIT=1
            shift
            ;;
    esac
done

# --- 收集目标 ---
ALL_TARGETS=()

# 命令行参数
if [ "$HAS_EXPLICIT" -eq 1 ]; then
    for t in "${TARGETS[@]}"; do
        ALL_TARGETS+=("$t")
    done
fi

# 配置文件
if [ -n "$CONFIG_FILE" ]; then
    if [ ! -f "$CONFIG_FILE" ]; then
        fail "配置文件不存在: $CONFIG_FILE"
        exit 1
    fi
    count=0
    while IFS= read -r line || [ -n "$line" ]; do
        trimmed="${line#"${line%%[![:space:]]*}"}"
        trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
        if [ -n "$trimmed" ] && [[ "$trimmed" != \#* ]]; then
            ALL_TARGETS+=("$trimmed")
            count=$((count + 1))
        fi
    done < "$CONFIG_FILE"
    printf "${GRAY}ℹ️  共 %d 个目标（%s）${NC}\n" "$count" "$CONFIG_FILE"
fi

# 默认读取 targets.txt
if [ "$HAS_EXPLICIT" -eq 0 ] && [ -z "$CONFIG_FILE" ]; then
    CONFIG_FILE="targets.txt"
    if [ -f "$CONFIG_FILE" ]; then
        count=0
        while IFS= read -r line || [ -n "$line" ]; do
            trimmed="${line#"${line%%[![:space:]]*}"}"
            trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
            if [ -n "$trimmed" ] && [[ "$trimmed" != \#* ]]; then
                ALL_TARGETS+=("$trimmed")
                count=$((count + 1))
            fi
        done < "$CONFIG_FILE"
        printf "${GRAY}ℹ️  共 %d 个目标（%s）${NC}\n" "$count" "$CONFIG_FILE"
    fi
fi

if [ ${#ALL_TARGETS[@]} -eq 0 ]; then
    fail "未指定任何目标工程。"
    echo ""
    echo "用法:"
    echo "  $0 /path/to/proj                        # 单目标"
    echo "  $0 /p1 /p2 /p3                          # 多目标"
    echo "  $0 -c targets.txt                       # 配置文件"
    echo "  $0                                      # 默认读取 targets.txt"
    echo "  $0 -d                                   # 预览"
    echo "  $0 -a                                   # 执行前确认"
    echo ""
    echo "配置文件 targets.txt 格式:"
    echo "  # 我的业务工程"
    echo "  /home/user/projects/game-server"
    echo "  /home/user/projects/admin-panel"
    exit 1
fi

# --- 预检：过滤不存在的目录 ---
VALID_TARGETS=()
SKIPPED=()

for t in "${ALL_TARGETS[@]}"; do
    if [ -d "$t" ]; then
        VALID_TARGETS+=("$t")
    else
        SKIPPED+=("$t")
    fi
done

if [ ${#SKIPPED[@]} -gt 0 ]; then
    warn "以下 ${#SKIPPED[@]} 个目标目录不存在，已自动跳过:"
    for s in "${SKIPPED[@]}"; do
        skip_msg "  $s"
    done
    echo ""
fi

if [ ${#VALID_TARGETS[@]} -eq 0 ]; then
    fail "所有目标目录均不存在。请检查路径。"
    exit 1
fi

# --- DryRun ---
if [ "$DRY_RUN" = true ]; then
    step "=== DRY RUN (不会执行任何操作) ==="
    echo "将处理 ${#VALID_TARGETS[@]} 个目标:"
    for t in "${VALID_TARGETS[@]}"; do
        echo "  - $t"
    done
    exit 0
fi

# --- 确认 ---
if [ "$ASK_CONFIRM" = true ]; then
    echo "即将对 ${#VALID_TARGETS[@]} 个工程执行部署:"
    for t in "${VALID_TARGETS[@]}"; do
        echo "  - $t"
    done
    read -r -p $'\n确认执行? (y/N) ' confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        info "已取消。"
        exit 0
    fi
fi

# =================================================================
# 核心部署逻辑
# =================================================================
init_one() {
    local TARGET="$1"

    TARGET=$(cd "$TARGET" && pwd)
    local SOURCE=$(pwd)
    local SOURCE_AGENT="$SOURCE/CLAUDE.md"
    local SOURCE_SKILLS="$SOURCE/.claude/skills"

    if [ ! -f "$SOURCE_AGENT" ]; then
        echo "源路径不含 CLAUDE.md (请在 harness 根目录执行)"
        return 1
    fi

    # [1/3] 软链接
    ln -sf "$SOURCE_AGENT" "$TARGET/CLAUDE.md" || { echo "创建 CLAUDE.md 链接失败"; return 1; }

    mkdir -p "$TARGET/.claude/skills"
    for skill_dir in "$SOURCE_SKILLS"/*/; do
        [ -d "$skill_dir" ] || continue
        local skill_name
        skill_name=$(basename "$skill_dir")
        ln -sfn "$skill_dir" "$TARGET/.claude/skills/$skill_name" || { echo "创建 skills/$skill_name 链接失败"; return 1; }
    done

    local SOURCE_SETTINGS="$SOURCE/.claude/settings.json"
    if [ -f "$SOURCE_SETTINGS" ]; then
        ln -sf "$SOURCE_SETTINGS" "$TARGET/.claude/settings.json"
    fi

    local SOURCE_HOOKS="$SOURCE/.claude/hooks"
    mkdir -p "$TARGET/.claude/hooks"
    if [ -d "$SOURCE_HOOKS" ]; then
        for hook_file in "$SOURCE_HOOKS"/*; do
            [ -f "$hook_file" ] || continue
            local hook_name
            hook_name=$(basename "$hook_file")
            ln -sf "$hook_file" "$TARGET/.claude/hooks/$hook_name"
        done
    fi

    # [2/3] .cursorrules
    cat > "$TARGET/.cursorrules" << 'CURSORRULES_EOF'
你是一个通用的工程智能助手。
在开始工作前，请务必阅读并严格遵循项目根目录下的 CLAUDE.md，**启动协议** 必须执行。
执行任务请遵循 REAP 流程。

【每轮对话结束时必须进行知识沉淀评估】
逐项检查本轮是否涉及：1.架构决策 2.根因分析 3.规范确立 4.知识盲区 5.方案对比 6.踩坑记录。
命中 → 写入 .context-guard/ 回复"已记录"或"等待确认"。
未命中 → 回复"已评估知识沉淀价值（跳过：原因）"。
CURSORRULES_EOF

    # [3/3] .gitignore
    local GI="$TARGET/.gitignore"
    local REQUIRED=("AGENTS.md" "CLAUDE.md" ".cursorrules" ".claude/skills/*" ".claude/settings.json" ".claude/hooks/*" ".context-guard/transcripts/*")

    [ ! -f "$GI" ] && touch "$GI"

    local TO_ADD=()
    for item in "${REQUIRED[@]}"; do
        if ! grep -qFx "$item" "$GI" 2>/dev/null; then
            TO_ADD+=("$item")
        fi
    done

    if [ ${#TO_ADD[@]} -gt 0 ]; then
        [ -s "$GI" ] && [ -n "$(tail -c 1 "$GI")" ] && echo "" >> "$GI"
        echo "# AI Skills Support" >> "$GI"
        for line in "${TO_ADD[@]}"; do
            echo "$line" >> "$GI"
        done
    fi

    return 0
}

# =================================================================
# 执行
# =================================================================
TOTAL=${#VALID_TARGETS[@]}
SUCCESS=0
FAILED=0
declare -a FAILURE_PATHS=()
declare -a FAILURE_MSGS=()
IS_SINGLE=false
[ "$TOTAL" -eq 1 ] && IS_SINGLE=true

if [ "$IS_SINGLE" = false ]; then
    echo ""
    echo -e "${CYAN}========================================"
    echo -e "  AI Skills 批量部署 - 共 $TOTAL 个目标"
    echo -e "========================================${NC}"
    echo ""
fi

idx=0
for target in "${VALID_TARGETS[@]}"; do
    idx=$((idx + 1))

    if [ "$IS_SINGLE" = true ]; then
        echo -e "${CYAN}🚀 开始向目标工程分发 AI 技能环境...${NC}"
    else
        step "[$idx/$TOTAL] 处理: $target"
    fi

    err=$(init_one "$target" 2>&1) && ec=$? || ec=$?

    if [ $ec -eq 0 ]; then
        if [ "$IS_SINGLE" = true ]; then
            echo -e "${GREEN}✨ 部署完成！目标工程 AI 环境已就绪。${NC}"
        else
            ok "部署成功: $target"
        fi
        SUCCESS=$((SUCCESS + 1))
    else
        fail "部署失败: $target"
        warn "原因: $err"
        FAILED=$((FAILED + 1))
        FAILURE_PATHS+=("$target")
        FAILURE_MSGS+=("$err")
    fi

    if [ "$IS_SINGLE" = false ]; then
        echo ""
    fi
done

# --- 多目标汇总 ---
if [ "$IS_SINGLE" = false ]; then
    echo -e "${CYAN}========================================"
    echo -e "  批量部署完成"
    echo -e "========================================${NC}"
    echo -ne "总计: ${#ALL_TARGETS[@]} | 跳过: ${#SKIPPED[@]} | 执行: $TOTAL | 成功: "
    echo -ne "${GREEN}$SUCCESS${NC}"
    echo -ne " | 失败: "
    if [ "$FAILED" -gt 0 ]; then
        echo -e "${RED}$FAILED${NC}"
    else
        echo "$FAILED"
    fi

    if [ "$FAILED" -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}失败明细:${NC}"
        for i in "${!FAILURE_PATHS[@]}"; do
            echo -e "  ${RED}- ${FAILURE_PATHS[$i]}${NC}"
            echo -e "    ${GRAY}${FAILURE_MSGS[$i]}${NC}"
        done
    fi

    echo ""
    if [ "$FAILED" -gt 0 ]; then
        warn "部分目标部署失败，请检查上方明细。"
        exit 1
    else
        ok "全部目标部署成功！"
    fi
fi

if [ "$IS_SINGLE" = true ] && [ "$FAILED" -gt 0 ]; then
    exit 1
fi
