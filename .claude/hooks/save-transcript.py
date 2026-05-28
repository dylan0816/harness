"""SessionEnd hook: 对话结束后将完整 transcript 存档为 Markdown。"""

import json
import os
import sys
from datetime import datetime


SIGNAL_NAMES = [
    "架构决策", "根因分析", "规范确立", "知识盲区",
    "方案对比", "踩坑记录",
]


def extract_text(content):
    """从 message content 中提取文本（支持 string / array 两种格式）。"""
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        parts = []
        for block in content:
            if not isinstance(block, dict):
                continue
            if block.get("type") == "thinking":
                t = block.get("thinking", "")
                if t and t.strip():
                    parts.append(("thinking", t.strip()))
            elif block.get("type") == "text":
                t = block.get("text", "")
                if t and t.strip():
                    parts.append(("text", t.strip()))
        return parts
    return None


def parse_transcript(lines):
    """解析 JSONL transcript，返回 (questions, thinking, conclusions)。"""
    questions = []
    thinking = []
    conclusions = []

    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue

        message = obj.get("message", {})
        role = message.get("role", "")
        content = message.get("content", "")

        extracted = extract_text(content)
        if not extracted:
            continue

        if role == "user":
            if isinstance(extracted, str):
                questions.append(extracted)
            else:
                texts = [t for kind, t in extracted if kind == "text"]
                if texts:
                    questions.append("\n".join(texts))
        elif role == "assistant":
            if isinstance(extracted, str):
                conclusions.append(extracted)
            else:
                for kind, text in extracted:
                    if kind == "thinking":
                        thinking.append(text)
                    elif kind == "text":
                        conclusions.append(text)

    return questions, thinking, conclusions


def build_markdown(questions, thinking, conclusions):
    timestamp = datetime.now().strftime("%Y-%m-%d-%H%M%S")
    parts = [f"# 对话记录 - {timestamp}\n"]

    if questions:
        parts.append("## 问题\n")
        for i, q in enumerate(questions):
            parts.append(q)
            if i < len(questions) - 1:
                parts.append("\n---\n")
        parts.append("")

    if thinking:
        parts.append("## 思考\n")
        for i, t in enumerate(thinking):
            parts.append(t)
            if i < len(thinking) - 1:
                parts.append("\n---\n")
        parts.append("")

    if conclusions:
        parts.append("## 结论\n")
        for i, c in enumerate(conclusions):
            parts.append(c)
            if i < len(conclusions) - 1:
                parts.append("\n---\n")
        parts.append("")

    return "\n".join(parts)


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

    # 递归保护（Stop hook 用）
    if data.get("stop_hook_active"):
        sys.exit(0)

    tp = data.get("transcript_path") or os.environ.get("CLAUDE_CODE_TRANSCRIPT_PATH", "")
    if not tp or not os.path.isfile(tp):
        sys.exit(0)

    try:
        with open(tp, "r", encoding="utf-8") as f:
            lines = f.readlines()
    except OSError:
        sys.exit(0)

    if not lines:
        sys.exit(0)

    questions, thinking, conclusions = parse_transcript(lines)
    if not questions and not thinking and not conclusions:
        sys.exit(0)

    markdown = build_markdown(questions, thinking, conclusions)

    out_dir = os.path.join(os.getcwd(), ".context-guard", "transcripts")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, f"{datetime.now().strftime('%Y-%m-%d-%H%M%S')}.md")

    with open(out_path, "w", encoding="utf-8") as f:
        f.write(markdown)

    sys.exit(0)


if __name__ == "__main__":
    main()
