# AI 辅助写 SQL 工作流指南

> 适用于：Data 团队成员通过 Claude Code + ClickHouse MCP 进行数据查询
> 核心模式：AI 基于已有 SQL 模板 + 业务上下文辅助撰写/调整 SQL，而非从零生成

---

## 一、AI 写 SQL 前需要的所有输入

### 必需（缺一个都会导致 SQL 写错）

| # | 输入内容 | 作用 | 存放位置 | 格式 |
|---|---------|------|---------|------|
| 1 | **ClickHouse MCP 连接** | AI 直连数据库，查看表结构、验证 SQL、返回结果 | Claude Code MCP 配置 | MCP server |
| 2 | **SQL 模板库** | 提供正确的业务口径、表关联逻辑、字段过滤规则，AI 基于模板做调整 | `sql_templates/*.sql` | 每个指标一个 .sql 文件，头部含业务元信息 |
| 3 | **埋点字段说明** | 告诉 AI 每个 event 的 status/type/number 等字段的业务含义 | 已嵌入 SQL 模板头部的 `[KEY FIELDS]` 区域 | SQL 注释 |

### 推荐（有了更好，没有不会写错）

| # | 输入内容 | 作用 | 存放位置 | 格式 |
|---|---------|------|---------|------|
| 4 | **指标定义文档** | 告诉 AI 每个指标的业务含义、归属部门、评估方向 | 已嵌入 SQL 模板头部 | SQL 注释 |
| 5 | **表级别说明** | 告诉 AI 每张表的业务用途、关键字段备注 | Google Sheet 或 Markdown | 表格 |
| 6 | **业务规则备注** | 如 17:30 切业务日、排除 SG/HK/CN 用户、guest 过滤等隐性规则 | 需人工补充到模板或单独文档 | 文本 |

---

## 二、各输入内容详解

### 2.1 ClickHouse MCP 连接

**作用：** 让 AI 能直接执行 SQL，而不只是生成 SQL 文本。

**配置方式：** 在 Claude Code 的 MCP 设置中添加 ClickHouse server，提供连接地址和凭证。

**AI 可用的操作：**
- `list_databases` — 列出数据库
- `list_tables` — 列出表和字段
- `run_select_query` — 执行 SELECT 查询

### 2.2 SQL 模板库

**作用：** 这是最核心的输入。模板编码了所有 AI 无法从表结构推断的业务逻辑。

**每个模板包含：**
```sql
-- metric_id: push_notification_click_rate
-- metric_name: 推送点击率
-- card_name: Push notification click rate
-- card_id: 3240
-- dashboard: L2 (id=522)
-- business_domain: Engagement
-- owner: product, ops
-- definition: 每天推送点击情况
-- evaluation: higher_is_better
-- source_tables: new_loops_activity.hab_app_events, new_loops_activity.push_history, ...
-- events_used: push_notification
--
-- [KEY FIELDS]
-- event: push_notification
--   status: 1=展示, 2=点击, 3=消息到达客户端
--   number: 1=in-app, 2=out-app (仅Android端有记录)
--   type: 对应 push_history.text_id (推送模板ID, 需 < 100000 排除系统推送)
--
-- [SQL]
WITH ...
```

**AI 基于模板能做的事：**
- 换时间范围（如 30 天改 7 天）
- 加维度拆分（如按 country、text_pool 分组）
- 加筛选条件（如只看某个 text_pool）
- 合并多个模板（如 push 点击 + 参赛率做交叉分析）

**AI 无法做的事（需要人工补充模板）：**
- 创建全新的业务指标口径
- 定义新事件的字段含义

### 2.3 埋点字段说明

**作用：** 告诉 AI `status=2` 是"点击"而不是"展示"。

**来源：** Confluence 埋点文档（Lobah DI），已解析并嵌入到 SQL 模板的 `[KEY FIELDS]` 区域。

**当前覆盖范围：**
- 222 个事件定义已解析
- 42 个 SQL 模板包含事件字段说明
- 关键事件（push_notification、monetization_popup、challenge_reminder 等）的 status/type/number 含义已标注

**需要持续维护的场景：**
- 新增埋点事件
- 字段含义变更（如 push_notification 从 V1 的 `number=1,status=2` 改为 V2 的 `number=2,status=2`）

---

## 三、使用流程

### 3.1 日常查询（最常见场景）

```
用户: "帮我查最近7天 COMPETITION_2 推送的点击率，按国家拆分"

AI 内部流程:
1. 读取 sql_templates/push_notification_click_rate.sql
2. 理解模板中的业务逻辑（number=2 AND status=2 是点击，type < 100000 过滤系统推送）
3. 基于模板调整：改时间窗口、加 text_pool 筛选、加 country 维度
4. 通过 MCP 执行 SQL，返回结果
```

### 3.2 新指标查询（需要人工介入）

```
用户: "帮我查用户看广告后的留存率"

AI 内部流程:
1. 搜索 sql_templates/ 中相关模板（ad_finish_times.sql、retention(d1).sql）
2. 发现没有现成的"广告后留存"模板
3. 告知用户：需要人工确认口径（看广告怎么定义？用 energy_log 的 watch_ad 还是 hab_app_events？留存按什么时间算？）
4. 用户确认后，AI 组合现有模板逻辑写 SQL
5. 建议用户将该 SQL 保存为新模板
```

### 3.3 口径变更

```
当业务口径发生变更时（如 push_notification 的点击定义从 V1 改为 V2）：
1. 在 Metabase 上修改 card 的 SQL
2. 重新运行 fetch_sql_templates.py 拉取最新 SQL
3. 重新运行 enrich_sql_templates.py 补充元信息
4. 如果埋点字段含义有变，手动更新 [KEY FIELDS] 区域
```

---

## 四、模板库维护

### 4.1 自动更新（SQL 内容）

```bash
# 从 Metabase 拉取最新 SQL
python3 fetch_sql_templates.py

# 补充业务元信息
python3 enrich_sql_templates.py
```

### 4.2 手动维护（需要人工做的事）

| 场景 | 操作 |
|------|------|
| 新增 Metabase card | 重新运行上述两个脚本即可 |
| 新增非 Metabase 的业务 SQL | 手动创建 .sql 文件，按模板格式写好头部注释 |
| 埋点字段含义变更 | 更新对应 .sql 文件的 `[KEY FIELDS]` 区域 |
| 新增隐性业务规则 | 补充到对应 .sql 文件注释或单独的规则文档中 |

### 4.3 文件清单

```
AI自动化数据/
├── fetch_sql_templates.py      # 步骤1：从 Metabase 拉取 SQL
├── enrich_sql_templates.py     # 步骤2：补充业务元信息
├── sql_templates/              # SQL 模板库（86个文件）
│   ├── _summary.json           # 汇总索引
│   ├── dau.sql
│   ├── push_notification_click_rate.sql
│   ├── ...
│   └── (共86个 .sql 文件)
├── AI辅助写SQL工作流指南.md     # 本文档
├── AI直连ClickHouse可行性评估报告.md
└── AI自动化数据现状与进展报告.md
```

---

## 五、AI 写 SQL 的能力边界

### 能做好

- 基于模板调整参数（时间、维度、筛选）
- 合并多个模板做交叉分析
- 探索表结构和数据分布
- 验证 SQL 并直接返回结果

### 做不好（需要人兜底）

- 定义新的业务口径（AI 不知道什么算"有效用户"）
- 理解未文档化的埋点字段含义（如果 `[KEY FIELDS]` 里没写，AI 会猜错）
- 隐性业务规则（17:30 切日、排除测试用户等，需要写在模板或文档里）
- 判断数据质量问题（如某个字段在特定时间段有缺失）

### 一句话总结

**人负责定义"什么是对的"（口径、字段含义、业务规则），AI 负责"又快又准地执行"（基于模板写 SQL、跑查询、返回结果）。**
