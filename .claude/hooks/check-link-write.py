"""PreToolUse hook: 阻止对软链接/硬链接文件直接写入，强制回源仓库修改。"""

import json
import os
import sys


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

    file_path = data.get("tool_input", {}).get("file_path", "")
    if not file_path:
        sys.exit(0)

    # key-points-mem/references/ 允许写入
    if "key-points-mem" in file_path.replace("\\", "/").split("/"):
        sys.exit(0)

    # 检查是否为链接
    try:
        if os.path.islink(file_path):
            link_type = "SymbolicLink"
        elif os.path.isfile(file_path):
            # 硬链接检测：仅文件有意义（目录的 st_nlink 始终 ≥2）
            st = os.lstat(file_path)
            if st.st_nlink > 1:
                link_type = "HardLink"
            else:
                sys.exit(0)
        else:
            # 目录或不存在的路径，放行
            sys.exit(0)
    except OSError:
        sys.exit(0)

    msg = (
        f"链接只读边界: 目标 [{file_path}] 为 {link_type}。"
        "请在 dev-harness 源仓库修改后重新 init，不要就地编辑链接文件。"
    )
    output = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": msg,
        }
    }
    print(json.dumps(output, ensure_ascii=False))
    sys.exit(0)


if __name__ == "__main__":
    main()
