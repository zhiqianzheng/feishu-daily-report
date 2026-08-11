# 飞书日报自动化 · Feishu Daily Report Skill

一个 Claude Code Skill:每天自动汇总你当天**所有 Claude Code 会话窗口**里的工作,
总结成几句话,自动填进飞书(Lark)日报表格里**你名字那一行、当天日期的「今日完成」列**。

> An Agent Skill for Claude Code that summarizes all of today's Claude Code sessions
> and writes a one-line daily report into your team's Feishu/Lark spreadsheet —
> the right row (your name) and the right column (today's date), automatically at
> 18:00 Beijing time regardless of your machine's timezone.

## 功能

- **手动**:对 Claude 说「写日报」,几十秒后日报出现在表格里
- **自动**:每天北京时间 18 点后台无人值守执行(用北京时间守卫实现,机器在任何时区、有无夏令时都不用改配置)
- **多窗口汇总**:并行开的所有 Claude Code 会话都会被遍历总结
- **隐私过滤**:只总结工作内容,私人对话不写入日报
- **安全**:动态定位单元格(按姓名找行、按日期找列),先读后写、合并去重,绝不覆盖手写内容、不碰其他单元格;飞书授权是你个人扫码,凭据只存本机

## 安装

### 方式一:一键脚本(推荐,含定时任务)

```bash
git clone https://github.com/zhiqianzheng/feishu-daily-report.git
cd feishu-daily-report
bash setup.sh
```

过程中扫码两次(创建飞书应用 + 本人身份授权),回答两个问题(你在日报表 A 列的名字、表格链接),完成。

团队管理员可先 `export DAILY_REPORT_SHEET_URL=<团队表格链接>` 再让成员执行,省去粘贴链接。

### 方式二:skills 包管理器(只装 Skill,环境由 Claude 首次运行时引导补齐)

```bash
npx skills add zhiqianzheng/feishu-daily-report
```

之后在 Claude Code 里说「写日报」,缺的环境(lark-cli、扫码授权、配置)Claude 会一步步引导你补上;想要每日自动执行再按提示装定时任务。

## 前置条件

- Linux / macOS / WSL2(定时功能依赖 cron;WSL 需启用 systemd)
- Node.js ≥ 18、python3
- 已安装并登录 [Claude Code](https://claude.com/claude-code)
- 飞书账号对目标表格有编辑权限

## 对日报表格的假设

Skill 按下面这种常见周报模板定位(不符合的话改 `SKILL.md` 第 3 节的定位规则即可):

| A 列 | 第 1 行 | 第 2 行 | 第 3 行 |
|---|---|---|---|
| 姓名 | 周(如 `第33周(8/10-8/14)`) | 日期(如 `8/11 周二`,每天横跨 2 列) | `今日完成` / `明日计划` |

成员名字在 A 列第 4 行起,每人一行。

## 注意事项

- 自动执行的前提是北京时间 18 点时**电脑和 cron 服务开着**;错过了就手动说一句「写日报」补,同一天重复执行会合并去重,不会写重。
- 定时任务用 `claude -p --dangerously-skip-permissions` 无头执行(定时场景无法弹权限确认),它只按 SKILL.md 流程读写一个单元格,介意者可只用手动模式(不装 crontab 即可)。
- 执行日志:`~/.claude/skills/write-daily-report/logs/`,每天一个文件。
- 改名字/表格链接:编辑 `~/.config/feishu-daily-report.json`。

## 卸载

```bash
crontab -e            # 删除 cron_daily_report.sh 相关两行
rm -rf ~/.claude/skills/write-daily-report ~/.config/feishu-daily-report.json
npm uninstall -g @larksuite/cli   # 可选
```

## 目录结构

```
├── README.md
├── LICENSE
├── setup.sh                      一键安装
└── skills/write-daily-report/
    ├── SKILL.md                  Claude 执行流程(总结规则、动态定位、防覆盖)
    └── scripts/
        ├── collect_today.py      汇总当天(北京时间)所有会话窗口的用户消息
        └── cron_daily_report.sh  定时入口(每小时触发,仅北京 18 点真正执行)
```

## License

MIT
