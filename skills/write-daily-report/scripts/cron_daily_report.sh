#!/bin/bash
# 每天北京时间 18 点自动写日报。
# crontab 每小时触发一次(分钟由 setup.sh 写入),脚本内用北京时间守卫,
# 只有北京时间 18 点的那次真正执行——与机器所在时区无关,冬夏令时自适应。

export PATH="$HOME/.local/bin:$PATH"
# 补上 node(nvm 安装的 claude/lark-cli 需要)
if [ -d "$HOME/.nvm/versions/node" ]; then
    NODE_BIN=$(ls -d "$HOME"/.nvm/versions/node/*/bin 2>/dev/null | sort -V | tail -1)
    [ -n "$NODE_BIN" ] && export PATH="$NODE_BIN:$PATH"
fi

BJ_HOUR=$(TZ=Asia/Shanghai date +%H)
if [ "$BJ_HOUR" != "18" ]; then
    exit 0
fi

LOGDIR="$HOME/.claude/skills/write-daily-report/logs"
mkdir -p "$LOGDIR"
LOG="$LOGDIR/$(TZ=Asia/Shanghai date +%F).log"

# 同一天已成功执行过则跳过(防止重复触发)
if grep -q "^DONE" "$LOG" 2>/dev/null; then
    exit 0
fi

echo "=== 开始写日报 北京时间 $(TZ=Asia/Shanghai date '+%F %T') ===" >> "$LOG"
cd "$HOME" || exit 1
claude -p "/write-daily-report" --dangerously-skip-permissions >> "$LOG" 2>&1
RC=$?
if [ $RC -eq 0 ]; then
    echo "DONE rc=0 北京时间 $(TZ=Asia/Shanghai date '+%F %T')" >> "$LOG"
else
    echo "FAILED rc=$RC 北京时间 $(TZ=Asia/Shanghai date '+%F %T')" >> "$LOG"
fi
exit $RC
