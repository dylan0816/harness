"""Stop hook: 每轮对话结束强制要求知识沉淀评估。

仅当本轮存在 Write/Edit/NotebookEdit 操作时才要求评估标记。
通过 transcript JSONL 中的 tool_use 记录检测文件修改。
"""

import json
import os
import re
import sys

END_MARKER = "已评估知识沉淀价值"
MODIFY_TOOLS = {"Write", "Edit", "NotebookEdit"}


# ── transcript 解析 ──────────────────────────────────


def find_last_user_index(lines):
    for i in range(len(lines) - 1, -1, -1):
        s = lines[i].strip()
        if not s:
            continue
        try:
            obj = json.loads(s)
        except json.JSONDecodeError:
            continue
        if obj.get("type") == "user":
            return i
    return 0


def find_last_assistant_text(lines):
    """获取最后一轮 assistant 中的纯文本内容（跳过纯 thinking 消息）。"""
    last_user = find_last_user_index(lines)
    for i in range(len(lines) - 1, last_user - 1, -1):
        s = lines[i].strip()
        if not s:
            continue
        try:
            obj = json.loads(s)
        except json.JSONDecodeError:
            continue
        if obj.get("type") != "assistant":
            continue
        c = obj.get("message", {}).get("content", "")
        if isinstance(c, str):
            return c
        if isinstance(c, list):
            texts = [
                b.get("text", "")
                for b in c
                if isinstance(b, dict) and b.get("type") == "text"
            ]
            if texts:
                return "\n".join(texts)
    return None


def find_current_turn_start(lines):
    """通过 last-prompt 定位当前轮次的起始行。"""
    for i in range(len(lines) - 1, -1, -1):
        s = lines[i].strip()
        if not s:
            continue
        try:
            obj = json.loads(s)
        except json.JSONDecodeError:
            continue
        if obj.get("type") == "last-prompt":
            return i
    return 0


def has_modify_in_current_turn(lines):
    """扫描当前轮次中是否存在 Write/Edit/NotebookEdit 操作。"""
    start = find_current_turn_start(lines)
    for i in range(start, len(lines)):
        s = lines[i].strip()
        if not s:
            continue
        try:
            obj = json.loads(s)
        except json.JSONDecodeError:
            continue

        content = obj.get("message", {}).get("content", "")
        if isinstance(content, list):
            for block in content:
                if isinstance(block, dict) and block.get("type") == "tool_use":
                    if block.get("name", "") in MODIFY_TOOLS:
                        return True

    return False


# ── 技能枚举检测 ─────────────────────────────────────


def check_skill_enumeration(lines):
    has_enum = False
    has_skill_read = False
    skills_pat = re.compile(r"\.claude[\\/]skills[\\/]?")
    skill_md_pat = re.compile(r"\.claude[\\/]skills[\\/][^\\/]+[\\/]SKILL\.md$")

    for line in lines:
        if has_enum and has_skill_read:
            break
        s = line.strip()
        if not s:
            continue
        try:
            obj = json.loads(s)
        except json.JSONDecodeError:
            continue

        content = obj.get("message", {}).get("content", "")
        if isinstance(content, list):
            for block in content:
                if not isinstance(block, dict) or block.get("type") != "tool_use":
                    continue
                name = block.get("name", "")
                inp = block.get("input", {})
                if not has_enum and name in ("Bash", "PowerShell"):
                    if skills_pat.search(inp.get("command", "")):
                        has_enum = True
                if not has_skill_read and name == "Read":
                    if skill_md_pat.search(inp.get("file_path", "")):
                        has_skill_read = True

        tool = obj.get("tool", "")
        ti = obj.get("tool_input", {})
        if not has_enum and tool in ("Bash", "PowerShell"):
            if skills_pat.search(ti.get("command", "")):
                has_enum = True
        if not has_skill_read and tool == "Read":
            if skill_md_pat.search(ti.get("file_path", "")):
                has_skill_read = True

    return has_enum, has_skill_read


# ── 合规判定 ─────────────────────────────────────────


EVAL_RULES = (
    "逐项检查本轮是否涉及：1.架构决策 2.根因分析 3.规范确立 4.知识盲区 5.方案对比 6.踩坑记录。"
    "命中 → 写入 .context-guard/ 回复「已记录」或「等待确认」。"
    "未命中 → 回复「已评估知识沉淀价值（跳过：原因）」。"
)


def evaluate(last_text, has_modify):
    if not has_modify:
        return (False, None)
    if not last_text or END_MARKER not in last_text:
        return (True, "本轮对话未完成知识沉淀评估。\n" + EVAL_RULES)
    return (False, None)


# ── 主入口 ───────────────────────────────────────────


def main():
    try:
        raw = sys.stdin.read()
    except Exception:
        sys.exit(0)
    if not raw.strip():
        sys.exit(0)
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        sys.exit(0)

    tp = data.get("transcript_path", "")
    if not tp or not os.path.isfile(tp):
        sys.exit(0)
    if data.get("stop_hook_active"):
        sys.exit(0)

    try:
        with open(tp, "r", encoding="utf-8") as f:
            lines = f.readlines()
    except OSError:
        sys.exit(0)
    if not lines:
        sys.exit(0)

    modify = has_modify_in_current_turn(lines)
    last_text = find_last_assistant_text(lines)
    block, reason = evaluate(last_text, modify)

    has_enum, has_skill_read = check_skill_enumeration(lines)

    parts = ["[hook] 每轮评估检查"]
    if block:
        parts.append("→ 阻断")
    else:
        parts.append("→ 通过")
    if not has_enum:
        parts.append("未枚举 skills")
    if not has_skill_read:
        parts.append("未读 SKILL.md")

    out = {}
    if block:
        out["decision"] = "block"
        out["reason"] = reason
    out["systemMessage"] = " | ".join(parts)

    print(json.dumps(out, ensure_ascii=False))
    sys.exit(0)


if __name__ == "__main__":
    main()
