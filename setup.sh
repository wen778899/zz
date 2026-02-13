#!/data/data/com.termux/files/usr/bin/bash

# ==========================================
# Termux Alist Bot 部署脚本 (增强版)
# ==========================================
set -e

# 检测架构
ARCH=$(uname -m)
case $ARCH in
    aarch64)
        ALIST_ARCH="linux-arm64"
        CF_ARCH="linux-arm64"
        ;;
    arm*)
        ALIST_ARCH="linux-arm-7"
        CF_ARCH="linux-arm"
        ;;
    x86_64)
        ALIST_ARCH="linux-amd64"
        CF_ARCH="linux-amd64"
        ;;
    *)
        echo "❌ 不支持的架构: $ARCH"
        exit 1
        ;;
esac

echo -e "\033[1;36m>>> [1/5] 更新 Termux 基础环境...\033[0m"
pkg update -y
pkg upgrade -y

echo -e "\033[1;36m>>> [2/5] 安装必要依赖...\033[0m"
pkg install -y python nodejs aria2 ffmpeg git vim curl wget tar openssl-tool build-essential libffi termux-tools

echo -e "\033[1;36m>>> [3/5] 安装 Python 库...\033[0m"
pip install --upgrade pip
if [ -f "bot/requirements.txt" ]; then
    pip install -r bot/requirements.txt
else
    pip install python-telegram-bot requests psutil python-dotenv
fi

echo -e "\033[1;36m>>> [4/5] 安装 PM2 (进程守护)...\033[0m"
npm install -g pm2

# 准备 bin 目录
mkdir -p "$HOME/bin"
export PATH="$HOME/bin:$PATH"

echo -e "\033[1;36m>>> [5/5] 下载核心组件 ($ARCH)...\033[0m"

# --- 1. 安装 Cloudflared ---
if ! command -v cloudflared &> /dev/null; then
    echo "正在下载 Cloudflared..."
    wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-${CF_ARCH}" -O "$HOME/bin/cloudflared"
    chmod +x "$HOME/bin/cloudflared"
fi

# --- 2. 安装 Alist ---
if ! command -v alist &> /dev/null; then
    echo "正在下载 Alist..."
    LATEST_TAG=$(curl -s https://api.github.com/repos/alist-org/alist/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    wget -q "https://github.com/alist-org/alist/releases/download/${LATEST_TAG}/alist-${ALIST_ARCH}.tar.gz" -O alist.tar.gz
    tar -zxvf alist.tar.gz
    chmod +x alist
    mv alist "$HOME/bin/alist"
    rm alist.tar.gz
fi

# --- 3. 生成配置文件 ---
ENV_FILE="$HOME/.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "生成默认配置文件: ~/.env"
    cat <<EOT >> "$ENV_FILE"
# ==============================
# Termux Bot 配置文件
# ==============================
BOT_TOKEN=
ADMIN_ID=
# 隧道模式: quick (随机域名) 或 token (固定域名)
TUNNEL_MODE=quick
CLOUDFLARE_TOKEN=
# Alist 域名 (可选，如果不填则自动获取隧道域名)
ALIST_DOMAIN=
# 直播推流地址 (可选)
TG_RTMP_URL=
# Aria2 密钥 (默认无需修改)
ARIA2_RPC_SECRET=
# GitHub 多账号配置
GITHUB_ACCOUNTS_LIST=
EOT
fi

# --- 4. 配置 Aria2 ---
ARIA2_DIR="$HOME/.aria2"
mkdir -p "$ARIA2_DIR"
touch "$ARIA2_DIR/aria2.session"
if [ ! -f "$ARIA2_DIR/aria2.conf" ]; then
    cat <<EOT > "$ARIA2_DIR/aria2.conf"
dir=$HOME/downloads
input-file=$ARIA2_DIR/aria2.session
save-session=$ARIA2_DIR/aria2.session
save-session-interval=60
force-save=true
enable-rpc=true
rpc-allow-origin-all=true
rpc-listen-all=true
rpc-port=6800
max-concurrent-downloads=3
user-agent=Mozilla/5.0
EOT
fi

echo "--------------------------------------------------------"
echo "✅ Termux 环境部署完成！"
echo "--------------------------------------------------------"
echo "⚠️  重要提示 (Android 12+):"
echo "   为了防止后台进程被杀，请务必执行以下 ADB 命令(在电脑上)或使用无线调试:"
echo "   adb shell \"/system/bin/device_config put activity_manager max_phantom_processes 2147483647\""
echo "--------------------------------------------------------"
