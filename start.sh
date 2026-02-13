#!/data/data/com.termux/files/usr/bin/bash

ENV_FILE="$HOME/.env"
export PATH="$HOME/bin:$PATH"

# 1. 申请唤醒锁，防止息屏后 CPU 降频或休眠
echo "🔒 申请 Termux 唤醒锁 (Wake Lock)..."
termux-wake-lock

if [ -f "$ENV_FILE" ]; then
    echo ">>> 加载配置文件: $ENV_FILE"
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "❌ 未找到 ~/.env 文件，请先运行 ./setup.sh"
    exit 1
fi

# 2. 清理旧的或无法上传的 .cjs 文件
if [ -f "ecosystem.config.cjs" ]; then
    echo "🧹 清理残留文件 ecosystem.config.cjs..."
    rm ecosystem.config.cjs
fi
if [ -f "pm2.config.cjs" ]; then
    rm pm2.config.cjs
fi

echo "✅ 正在启动 PM2 服务组..."

# 3. 使用标准 JS 配置文件启动
pm2 start ecosystem.config.js
pm2 save

echo "-----------------------------------"
echo "🚀 服务已在后台运行"
echo "-----------------------------------"
echo "📊 监控面板: pm2 monit"
echo "📝 查看日志: pm2 logs"
echo "🔄 重启所有: pm2 restart all"
echo "💡 提示: 请勿从多任务后台划掉 Termux"
echo "-----------------------------------"
