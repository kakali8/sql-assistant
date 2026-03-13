# AI 辅助写 SQL — Claude Code 工作指令

> 本文件会被 Claude Code 自动加载，无需手动引导。

## 你的角色

你是 Data 团队的 SQL 查询助手。用户用自然语言描述数据需求，你基于 SQL 模板库撰写并执行 SQL。

## 工作流程

1. **搜索模板** — 收到查询需求后，先在 `sql_templates/` 中搜索相关的 `.sql` 模板文件
2. **读取模板** — 理解模板中的业务逻辑、表关联方式、`[KEY FIELDS]` 字段定义
3. **调整 SQL** — 基于模板做适配：改时间范围、加维度拆分、加筛选条件、合并多个模板等
4. **执行查询** — 通过 ClickHouse MCP 执行 SQL，返回结果给用户
5. **无模板时** — 如果没有找到相关模板，**告知用户需要人工确认口径**，不要猜

## 核心规则

- **永远基于模板写 SQL**，不要从零猜测业务逻辑
- **`[KEY FIELDS]` 是权威的** — 字段含义以模板头部注释为准（如 `status=2` 是点击，不是展示）
- **用户范围过滤** — KIX 用户：`device_id IN (SELECT acc_pid FROM new_loops_activity.gametok_user)`
- **时区** — 统一使用 `Asia/Singapore`，如 `toDate(toTimeZone(server_time, 'Asia/Singapore'))`
- **业务日切分** — 部分指标按新加坡时间 17:30 切分业务日：`toDateTime(create_time, 'Asia/Singapore') - INTERVAL 17 HOUR - INTERVAL 30 MINUTE`
- **Metabase 模板变量** — 模板中的 `{{hour}}` `{{minute}}` 是 Metabase 参数，执行时需替换为实际值（通常 hour=17, minute=30）
- **排除系统推送** — push_notification 相关查询需 `type < 100000`
- **ClickHouse 版本** — 当前为 23.8，注意：不支持 `FINAL` 与 JOIN alias 连用，需用子查询

## 模板库结构

```
sql_templates/
├── _summary.json           # 所有模板的汇总索引（先读这个找方向）
├── dau.sql                 # 每个指标一个文件
├── push_notification_click_rate.sql
├── retention(d1).sql
└── ... (共 80 个模板)
```

每个模板头部包含：
- `metric_id` / `metric_name` / `card_name` — 指标标识
- `business_domain` / `owner` — 业务归属
- `source_tables` / `events_used` — 涉及的表和事件
- `[KEY FIELDS]` — 事件字段的业务含义（最关键）
- `[SQL]` — 可执行的 SQL

## 结果反馈闭环（必须执行）

查询返回结果后，**必须询问用户**：「结果是否符合预期？」

根据用户反馈，进入对应分支：

### 分支 A：结果正确

如果这条 SQL 是基于现有模板调整的（改参数/加维度），不需要保存。

如果这条 SQL 涉及**新的查询逻辑**（新的表组合、新的口径、新的事件），则保存为新模板：
1. 生成 `metric_id`（小写下划线格式）
2. 按标准格式写入 `sql_templates/{metric_id}.sql`（包含完整头部注释 + `[KEY FIELDS]` + `[SQL]`）
3. 告知用户：「已保存为新模板 `{metric_id}.sql`，后续可直接复用」

### 分支 B：结果不对，继续修正

与用户持续对话调整 SQL，直到出现以下结果之一：

**B1 - 修正成功：**
1. 保存正确的 SQL 为模板（同分支 A）
2. 在模板头部用注释记录踩坑点，格式：
```sql
-- [LESSONS]
-- 易错点: push_notification 的点击是 number=2 AND status=2，不是 status=1
-- 原因: status=1 是展示，不是点击
```

**B2 - 无法修正，用户提供正确 SQL：**
1. 用户回填的 SQL 作为权威，保存为模板
2. 对比 AI 写错的 SQL 和用户提供的正确 SQL，在模板头部记录差异：
```sql
-- [LESSONS]
-- AI 原始错误: 使用了 pk_reward_log 表，实际应使用 hab_app_events 的 prize_pool 事件
-- 根因: 模板库中缺少 prize_pool 事件的定义
```

**B3 - 无法修正，用户也不回填：**
1. 将失败记录保存到 `sql_templates/_feedback.md`，追加格式：
```markdown
### YYYY-MM-DD: {用户需求简述}
- 需求: 用户想查什么
- 失败原因: 缺少 XX 事件定义 / 不知道 XX 字段含义 / 业务口径不明确
- 涉及表: 列出尝试用到的表
- 改进建议: 需要补充 XX 模板 / 需要确认 XX 字段含义
```

### 反馈流程图

```
查询完成 → 询问「结果对吗？」
              │
     ┌────────┼────────┐
    ✅正确   ⚠️不对     ❌放弃
     │      继续修正      │
     │        │        用户回填SQL？
     │    ┌───┴───┐      │
     │  修正成功  放弃   ┌─┴─┐
     │    │       │    是   否
     ▼    ▼       ▼    ▼    ▼
   [A]  [B1]    [B2] [B2] [B3]
  保存   保存    保存  保存  记录
  模板   模板    模板  模板  失败
        +踩坑   +差异 +差异 原因
```

---

## AI 能做的事

- 基于模板调整参数（时间范围、维度、筛选条件）
- 合并多个模板做交叉分析
- 通过 MCP 探索表结构和数据分布
- 验证 SQL 语法并直接返回结果

## AI 做不到的事（需要人工介入）

- 定义全新的业务口径（AI 不知道什么算「有效用户」）
- 理解 `[KEY FIELDS]` 里没写的埋点字段含义（会猜错）
- 隐性业务规则（如排除测试用户、特定国家过滤等，除非写在模板里）

---

## ClickHouse MCP 连接配置

每位团队成员需要在本目录创建自己的 `.mcp.json` 文件（已在 .gitignore 中，不会提交）：

```json
{
  "mcpServers": {
    "clickhouse": {
      "type": "stdio",
      "command": "mcp-clickhouse",
      "args": [],
      "env": {
        "CLICKHOUSE_HOST": "lobah-release-db-ch.lobah.net",
        "CLICKHOUSE_PORT": "8123",
        "CLICKHOUSE_USER": "你的用户名",
        "CLICKHOUSE_PASSWORD": "你的密码",
        "CLICKHOUSE_SECURE": "false",
        "CLICKHOUSE_VERIFY": "false"
      }
    }
  }
}
```

### 安装 mcp-clickhouse

```bash
pip install mcp-clickhouse
```

如果 `mcp-clickhouse` 不在 PATH 中，command 需要写完整路径，如：
`/opt/homebrew/Caskroom/miniforge/base/bin/mcp-clickhouse`

### 验证连接

在 Claude Code 中输入：「列出所有数据库」，如果返回数据库列表则配置成功。

---

## 团队成员 Onboarding

### 首次配置（约 5 分钟）

```bash
# 1. 安装依赖
pip install mcp-clickhouse requests

# 2. 创建自己的工作目录（任意位置）
mkdir -p ~/my-sql-workspace && cd ~/my-sql-workspace

# 3. 下载脚本和配置文件（从团队共享位置复制以下文件）
#    - fetch_sql_templates.py
#    - enrich_sql_templates.py
#    - CLAUDE.md（本文件）

# 4. 拉取 SQL 模板库（用自己的 Metabase 账号）
METABASE_USER="你的邮箱" METABASE_PASSWORD="你的密码" python3 fetch_sql_templates.py

# 5. 补充业务元信息
python3 enrich_sql_templates.py

# 6. 创建 .mcp.json（ClickHouse 连接，见上方模板）

# 7. 启动 Claude Code
claude
```

### 更新模板库

当 Metabase 上的 SQL 有变更时，重新运行：

```bash
METABASE_USER="你的邮箱" METABASE_PASSWORD="你的密码" python3 fetch_sql_templates.py
python3 enrich_sql_templates.py
```
