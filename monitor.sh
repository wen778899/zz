#!/data/data/com.termux/files/usr/bin/bash

# ==========================================
# 更新监控守护进程
# ==========================================

# 获取脚本所在目录 (即项目根目录)
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$PROJECT_DIR"

export PATH="$HOME/bin:$PATH"

LOG_FILE="$HOME/.pm2/logs/monitor.log"
UPDATE_SCRIPT="$PROJECT_DIR/update.sh"

while true; do
    # 简单的网络检查
    if curl -s --head https://github.com > /dev/null; then
        git fetch origin main &> /dev/null
        
        LOCAL=$(git rev-parse HEAD)
        REMOTE=$(git rev-parse origin/main)
        
        if [ "$LOCAL" != "$REMOTE" ]; then
            echo "[$(date)] ⚡ 发现新版本，执行更新..." >> "$LOG_FILE"
            if [ -f "$UPDATE_SCRIPT" ]; then
                bash "$UPDATE_SCRIPT" >> "$LOG_FILE" 2>&1
            else
                echo "[$(date)] ❌ 找不到 update.sh" >> "$LOG_FILE"
            fi
        fi
    fi
    # 每 5 分钟检查一次
    sleep 300
done
