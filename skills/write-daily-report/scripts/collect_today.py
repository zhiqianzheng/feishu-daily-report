#!/usr/bin/env python3
"""汇总当天(北京时间)所有 Claude Code 会话窗口的用户消息,供写日报用。

输出: 按会话分组的人类消息(含会话标题、项目目录),以及每个会话最后一条助手文本(截断)。
用法: python3 collect_today.py [YYYY-MM-DD]  # 日期缺省为今天(北京时间)
"""
import json
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

BJT = timezone(timedelta(hours=8))
PROJECTS = Path.home() / ".claude" / "projects"

target = sys.argv[1] if len(sys.argv) > 1 else datetime.now(BJT).strftime("%Y-%m-%d")

def bj_date(ts: str) -> str:
    try:
        return (
            datetime.fromisoformat(ts.replace("Z", "+00:00"))
            .astimezone(BJT)
            .strftime("%Y-%m-%d")
        )
    except (ValueError, AttributeError):
        return ""

def text_of(content) -> str:
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        return "\n".join(
            c.get("text", "").strip() for c in content if isinstance(c, dict) and c.get("type") == "text"
        ).strip()
    return ""

sessions = []
cutoff = time.time() - 48 * 3600  # mtime 预筛,避免解析历史大文件
for f in PROJECTS.glob("*/*.jsonl"):
    if f.stat().st_mtime < cutoff:
        continue
    title, cwd, human_msgs, last_assistant = "", "", [], ""
    try:
        with open(f, encoding="utf-8") as fh:
            for line in fh:
                try:
                    d = json.loads(line)
                except json.JSONDecodeError:
                    continue
                t = d.get("type")
                if t == "ai-title":
                    title = d.get("title", title) or title
                elif t == "user":
                    if d.get("origin", {}).get("kind") != "human":
                        continue
                    if bj_date(d.get("timestamp", "")) != target:
                        continue
                    txt = text_of(d.get("message", {}).get("content"))
                    if txt:
                        cwd = d.get("cwd", cwd) or cwd
                        human_msgs.append(txt[:600])
                elif t == "assistant" and human_msgs:
                    if bj_date(d.get("timestamp", "")) == target:
                        txt = text_of(d.get("message", {}).get("content"))
                        if txt:
                            last_assistant = txt
    except OSError:
        continue
    if human_msgs:
        sessions.append(
            {
                "session": f.stem,
                "title": title,
                "cwd": cwd,
                "user_messages": human_msgs,
                "last_assistant_reply_truncated": last_assistant[:800],
            }
        )

print(json.dumps({"date_beijing": target, "session_count": len(sessions), "sessions": sessions}, ensure_ascii=False, indent=1))
