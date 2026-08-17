---
name: write-daily-report
description: 用户说"写日报"或每日定时任务触发时使用。汇总当天(北京时间)所有 Claude Code 会话窗口的工作内容,自动填入飞书日报表格中本人行、当天日期的"今日完成"列,并根据会话中的未完事项填写"明日计划"列。
---

# 写日报

把当天(**一律按北京时间 Asia/Shanghai 算日期,不是系统时区**)的工作总结写入飞书日报表。

## 0. 读取个人配置

```bash
cat ~/.config/feishu-daily-report.json
```

字段: `name`(日报表 A 列里本人的名字)、`sheet_url`(日报表格链接)、`sheet_name`(子表名,默认"日报")。

**环境自检**(缺什么就引导用户补什么,全部就绪则跳过):

1. `lark-cli` 未安装 → `npm install -g @larksuite/cli`(国内加 `--registry=https://registry.npmmirror.com`);
2. `lark-cli auth status` 报未配置 → 运行 `lark-cli config init --new`,把输出的链接给用户在浏览器完成应用创建;
3. user 身份缺失 → `lark-cli auth login --domain docs,drive,sheets,base,wiki --recommend --no-wait --json` 拿 verification_url 给用户扫码授权,完成后用返回的 device_code 执行 `lark-cli auth login --device-code <code>`;
4. 配置文件不存在 → 询问用户"你在日报表 A 列的名字"和"日报表格链接",写入上述 JSON;
5. 用户想要每日自动执行 → 参考仓库里的 `setup.sh` 安装 crontab 条目(每小时触发 `scripts/cron_daily_report.sh`,脚本内只在北京时间 18 点真正执行)。

## 1. 收集当天所有窗口的工作内容

```bash
python3 ~/.claude/skills/write-daily-report/scripts/collect_today.py
```

输出当天北京日期内所有项目、所有会话窗口的用户消息和每个会话最后的助手回复。

## 2. 总结

把所有会话归纳成日报内容,要求:

- **简短**:每条工作一句话,通常 1~3 条,用换行分隔;整体越短越好。
- **每条前加序号**:格式 `1、`、`2、`……(今日完成和明日计划都要,单条也编 `1、`)。
- **只写工作**:开发、编译烧录、联调排查、方案设计、工具链搭建等。**凡是私人事务(生活、健康、财务、购物、娱乐、个人问题咨询等)一律不写入日报**。
- 写"做了什么+结果",不写过程细节。会话标题和最后回复可帮助判断结果。

同时归纳**明日计划**:

- 来源:会话中明确的未完事项、待修复问题、用户提到的下一步安排(如"待修复""下次继续""明天要"之类线索)。
- 同样 1~3 条、一句话一条、只写工作;没有明确线索时写当天工作的自然延续(如联调验证、收尾),**不要凭空编造新任务**。

## 3. 定位目标单元格(必须动态定位,严禁写死坐标)

1. `lark-cli sheets +workbook-info --url <sheet_url>` 找到 `sheet_name` 对应的 sheet_id;
2. `lark-cli sheets +csv-get` 读表头前 3 行和 A 列;
3. **列**: 在第 2 行找当天北京日期(格式如 `8/11 周二`)所在列。每天占两列,日期在合并单元格、CSV 中值只出现在左列;左列第 3 行应为`今日完成`,右列(左列+1)第 3 行应为`明日计划`——两列都是目标列;
4. **行**: 在 A 列(表头之后)找配置中 `name` 所在行;
5. 若当天日期列不存在(周末/超出表格范围)或找不到本人名字,不要写,直接报告原因结束。右列第 3 行若不是`明日计划`(表格结构有变),只写今日完成并在报告中说明。

## 4. 写入(先读后写,不盲目覆盖)

「今日完成」和「明日计划」两格分别执行,流程相同:

1. 先 `+cells-get` 读目标格。若已有内容:保留已有要点,合并补充本次新增要点,去重;不删除用户手写内容;
2. 写入(cells 元素必须是含 `value` 的对象,纯字符串会报错):
   ```bash
   lark-cli sheets +cells-set --url "<sheet_url>" --sheet-id <id> --range <列><行> \
     --cells '[[{"value":"<内容>"}]]'
   ```
3. `+cells-get` 回读验证,确认内容一致后报告写入位置和内容(两格都要报告)。

## 异常处理

- lark-cli 报 authentication 错误(token 失效): 交互模式下引导用户重新授权——
  `lark-cli auth login --domain docs,drive,sheets,base,wiki --recommend`(扫码);
  无头/定时模式下把错误写日志并以非零码退出,不要重试。
- 除目标单元格外**不得改动表格其他任何位置**。
