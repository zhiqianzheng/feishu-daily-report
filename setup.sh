#!/bin/bash
# 飞书日报自动化 - 一键安装
# 用法: bash setup.sh
set -e

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DST="$HOME/.claude/skills/write-daily-report"
CONFIG="$HOME/.config/feishu-daily-report.json"
# 可选:安装前 export DAILY_REPORT_SHEET_URL=<团队日报表链接> 可作为默认值,免得每人手动粘贴
DEFAULT_SHEET_URL="${DAILY_REPORT_SHEET_URL:-}"

echo "==== 飞书日报自动化 安装 ===="

# 1. 前置检查
command -v node >/dev/null || { echo "错误: 未找到 node,请先安装 Node.js (>=18)"; exit 1; }
command -v python3 >/dev/null || { echo "错误: 未找到 python3"; exit 1; }
command -v claude >/dev/null || { echo "错误: 未找到 claude,请先安装并登录 Claude Code"; exit 1; }

# 2. 安装飞书官方 CLI
if ! command -v lark-cli >/dev/null; then
    echo "-> 安装 @larksuite/cli ..."
    npm install -g @larksuite/cli --registry=https://registry.npmmirror.com \
        || npm install -g @larksuite/cli
fi
echo "-> lark-cli: $(lark-cli --version)"

# 3. 初始化飞书应用(每人一次,浏览器/扫码操作)
if ! lark-cli auth status >/dev/null 2>&1; then
    echo "-> 首次配置: 请按屏幕提示打开链接或扫码,给应用起个名字并点 Create"
    lark-cli config init --new
fi

# 4. 用户身份授权(扫码,以本人身份读写文档)
if lark-cli auth status 2>/dev/null | grep -q '"status": "missing"'; then
    echo "-> 请扫码授权文档/表格权限(本人身份)"
    lark-cli auth login --domain docs,drive,sheets,base,wiki --recommend
fi
echo "-> 飞书鉴权 OK"

# 5. 个人配置
if [ -f "$CONFIG" ]; then
    echo "-> 已有配置 $CONFIG,跳过(如需修改请直接编辑该文件)"
else
    read -rp "你在日报表 A 列里的名字(如 Cian): " MY_NAME
    [ -n "$MY_NAME" ] || { echo "名字不能为空"; exit 1; }
    if [ -n "$DEFAULT_SHEET_URL" ]; then
        read -rp "日报表格链接(回车用默认: ${DEFAULT_SHEET_URL:0:50}...): " SHEET_URL
        SHEET_URL="${SHEET_URL:-$DEFAULT_SHEET_URL}"
    else
        read -rp "日报表格链接(飞书电子表格 URL): " SHEET_URL
    fi
    [ -n "$SHEET_URL" ] || { echo "表格链接不能为空"; exit 1; }
    mkdir -p "$HOME/.config"
    printf '{\n  "name": "%s",\n  "sheet_url": "%s",\n  "sheet_name": "日报"\n}\n' \
        "$MY_NAME" "$SHEET_URL" > "$CONFIG"
    echo "-> 已写入 $CONFIG"
fi

# 6. 安装 Skill
mkdir -p "$HOME/.claude/skills"
rm -rf "$SKILL_DST"
cp -r "$KIT_DIR/skills/write-daily-report" "$SKILL_DST"
chmod +x "$SKILL_DST"/scripts/*.sh "$SKILL_DST"/scripts/*.py
echo "-> Skill 已安装到 $SKILL_DST"

# 7. 安装定时任务: 每小时触发一次,脚本内只在北京时间 18 点真正执行(与本机时区无关)
CRON_LINE="7 * * * * $SKILL_DST/scripts/cron_daily_report.sh"
if crontab -l 2>/dev/null | grep -qF "cron_daily_report.sh"; then
    echo "-> crontab 已有条目,跳过"
else
    if ! pgrep -x cron >/dev/null && ! pgrep -x crond >/dev/null; then
        echo "!! 警告: cron 服务未在运行(WSL 需启用 systemd 或手动 service cron start),定时不会生效"
    fi
    (crontab -l 2>/dev/null; echo "# 每天北京时间18点自动写日报(每小时触发,脚本内按北京时间守卫)"; echo "$CRON_LINE") | crontab -
    echo "-> crontab 已安装: $CRON_LINE"
fi

echo ""
echo "==== 安装完成 ===="
echo "手动触发: 在 Claude Code 里说\"写日报\"(或输入 /write-daily-report)"
echo "自动触发: 每天北京时间 18:07 左右(前提: 当时本机和 WSL 开着)"
echo "执行日志: $SKILL_DST/logs/"
echo "卸载: crontab -e 删掉相应行; rm -rf $SKILL_DST $CONFIG"
