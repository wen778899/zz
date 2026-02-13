#!/data/data/com.termux/files/usr/bin/bash

# ==========================================
# Termux 自动更新脚本
# ==========================================

# 获取脚本所在目录 (即项目根目录)
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$PROJECT_DIR"

export PATH="$HOME/bin:$PATH"

LOG_FILE="$HOME/.pm2/logs/system_update.log"

echo "[$(date)] ♻️ 开始检查更新..." >> "$LOG_FILE"
echo "📂 工作目录: $PROJECT_DIR" >> "$LOG_FILE"

if [ ! -d ".git" ]; then
    echo "❌ 当前目录不是 Git 仓库，跳过更新" >> "$LOG_FILE"
    exit 1
fi

echo "[$(date)] ⬇️ 拉取最新代码..." >> "$LOG_FILE"
git fetch --all >> "$LOG_FILE" 2>&1
git reset --hard origin/main >> "$LOG_FILE" 2>&1

echo "[$(date)] 📦 更新依赖..." >> "$LOG_FILE"
pip install -r bot/requirements.txt --upgrade --quiet >> "$LOG_FILE" 2>&1

echo "[$(date)] 🔄 重启 PM2..." >> "$LOG_FILE"
pm2 restart all >> "$LOG_FILE" 2>&1

echo "[$(date)] ✅ 更新完成" >> "$LOG_FILE"
