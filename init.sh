#!/bin/bash
# AI 辅助写 SQL — 一键初始化
# 用法1（已有目录）: cd sql-assistant && bash init.sh
# 用法2（从零开始）: bash <(curl -s https://raw.githubusercontent.com/kakali8/sql-assistant/main/init.sh)

set -e

REPO_URL="https://github.com/kakali8/sql-assistant.git"
DIR_NAME="sql-assistant"

echo "=== AI SQL 助手初始化 ==="
echo ""

# 0. 如果不在仓库目录内，先 clone
if [ ! -f "CLAUDE.md" ]; then
    echo "0. 获取项目文件..."
    if [ -d "$HOME/$DIR_NAME" ]; then
        echo "   目录已存在，拉取最新代码..."
        cd "$HOME/$DIR_NAME" && git pull
    else
        git clone "$REPO_URL" "$HOME/$DIR_NAME"
        cd "$HOME/$DIR_NAME"
    fi
    echo "   ✅ 项目就绪: $(pwd)"
fi

# 1. 检查依赖
echo ""
echo "1. 检查依赖..."
pip install -q mcp-clickhouse requests pyyaml 2>/dev/null || {
    echo "❌ pip install 失败，请确认 Python 环境"
    exit 1
}
echo "   ✅ 依赖已安装"

# 2. 拉取 SQL 模板
echo ""
echo "2. 从 Metabase 拉取 SQL 模板..."
if [ -z "$METABASE_USER" ] || [ -z "$METABASE_PASSWORD" ]; then
    read -p "   Metabase 邮箱: " METABASE_USER
    read -s -p "   Metabase 密码: " METABASE_PASSWORD
    echo ""
    export METABASE_USER METABASE_PASSWORD
fi
python3 fetch_sql_templates.py

# 3. 补充业务元信息
echo ""
echo "3. 补充业务元信息..."
python3 enrich_sql_templates.py

# 4. 配置 ClickHouse MCP
if [ ! -f ".mcp.json" ]; then
    echo ""
    echo "4. 配置 ClickHouse MCP 连接..."
    read -p "   ClickHouse 用户名: " CH_USER
    read -s -p "   ClickHouse 密码: " CH_PASSWORD
    echo ""
    cat > .mcp.json << EOF
{
  "mcpServers": {
    "clickhouse": {
      "type": "stdio",
      "command": "mcp-clickhouse",
      "args": [],
      "env": {
        "CLICKHOUSE_HOST": "lobah-release-db-ch.lobah.net",
        "CLICKHOUSE_PORT": "8123",
        "CLICKHOUSE_USER": "${CH_USER}",
        "CLICKHOUSE_PASSWORD": "${CH_PASSWORD}",
        "CLICKHOUSE_SECURE": "false",
        "CLICKHOUSE_VERIFY": "false"
      }
    }
  }
}
EOF
    echo "   ✅ .mcp.json 已创建"
else
    echo ""
    echo "4. .mcp.json 已存在，跳过"
fi

# 5. 完成
echo ""
echo "==========================="
echo "✅ 初始化完成！"
echo ""
echo "使用方式:"
echo "  cd $(pwd)"
echo "  claude"
echo ""
echo "然后直接用自然语言提问，例如:"
echo '  "帮我查最近7天的DAU，按国家拆分"'
echo "==========================="
