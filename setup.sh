
#!/data/data/com.termux/files/usr/bin/bash

# ==========================================
# Termux Alist Bot 部署脚本 (纯净版)
# ==========================================
set -e

# 检测架构 (仅用于 Cloudflared)
ARCH=$(uname -m)
case $ARCH in
    aarch64)
        CF_ARCH="linux-arm64"
        ;;
    arm*)
        CF_ARCH="linux-arm"
        ;;
    x86_64)
        CF_ARCH="linux-amd64"
        ;;
    *)
        echo "❌ 不支持的架构: $ARCH"
        exit 1
        ;;
esac

echo -e "\033[1;36m>>> [1/5] 更新 Termux 基础环境...\033[0m"
# 使用 || true 防止源更新失败导致脚本退出
pkg update -y || true
pkg upgrade -y || true

echo -e "\033[1;36m>>> [2/5] 安装必要依赖...\033[0m"
# ⚡️ 关键修改: 
# 1. 添加 proot (用于模拟 /etc/resolv.conf 路径，解决 DNS 问题)
# 2. 直接安装 alist
pkg install -y python nodejs aria2 ffmpeg git vim curl wget tar openssl-tool build-essential libffi termux-tools ca-certificates alist proot

# --- 修复 Termux DNS (配合 proot 使用) ---
RESOLV_CONF="$PREFIX/etc/resolv.conf"
if [ ! -f "$RESOLV_CONF" ] || [ ! -s "$RESOLV_CONF" ]; then
    echo "🔧 修复 DNS 配置 (创建 $RESOLV_CONF)..."
    mkdir -p "$(dirname "$RESOLV_CONF")"
    echo "nameserver 8.8.8.8" > "$RESOLV_CONF"
    echo "nameserver 1.1.1.1" >> "$RESOLV_CONF"
else
    echo "✅ DNS 配置已存在"
fi

# --- 修复 Cloudflared SSL 证书问题 (配合 proot) ---
echo "🔧 修复 SSL 证书路径..."
mkdir -p "$PREFIX/etc/ssl/certs"
rm -f "$PREFIX/etc/ssl/certs/ca-certificates.crt"
ln -sf "$PREFIX/etc/tls/cert.pem" "$PREFIX/etc/ssl/certs/ca-certificates.crt"
rm -f "$PREFIX/etc/ssl/cert.pem"
ln -sf "$PREFIX/etc/tls/cert.pem" "$PREFIX/etc/ssl/cert.pem"
echo "✅ SSL 证书链接已建立"

echo -e "\033[1;36m>>> [3/5] 安装 Python 库...\033[0m"
if [ -f "bot/requirements.txt" ]; then
    pip install -r bot/requirements.txt
else
    pip install python-telegram-bot requests psutil python-dotenv
fi

echo -e "\033[1;36m>>> [4/5] 安装 PM2 (进程守护)...\033[0m"
if ! command -v pm2 &> /dev/null; then
    npm install -g pm2
else
    echo "PM2 已安装"
fi

# 准备 bin 目录
mkdir -p "$HOME/bin"
export PATH="$HOME/bin:$PATH"

echo -e "\033[1;36m>>> [5/5] 配置核心组件...\033[0m"

# --- 1. 安装 Cloudflared ---
CLOUDFLARED_BIN="$HOME/bin/cloudflared"
if [ ! -f "$CLOUDFLARED_BIN" ]; then
    echo "⬇️ 正在下载 Cloudflared..."
    wget -O "$CLOUDFLARED_BIN" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-${CF_ARCH}"
    chmod +x "$CLOUDFLARED_BIN"
    echo "✅ Cloudflared 下载完成"
else
    echo "✅ Cloudflared 已存在 ($CLOUDFLARED_BIN)"
fi

# 验证 Cloudflared 二进制
if "$CLOUDFLARED_BIN" --version > /dev/null; then
    echo "✅ Cloudflared 运行正常！"
else
    echo "⚠️  Cloudflared 运行失败，尝试删除..."
    rm -f "$CLOUDFLARED_BIN"
    echo "❌ 请重新运行 ./setup.sh"
fi

# --- 2. 配置 Alist (官方源) ---
ALIST_BIN="$HOME/bin/alist"
pm2 stop alist >/dev/null 2>&1 || true

echo "⚙️ 配置 Alist..."
TERMUX_ALIST_PATH="$PREFIX/bin/alist"

if [ -f "$TERMUX_ALIST_PATH" ]; then
    echo "✅ 检测到系统内置 Alist: $TERMUX_ALIST_PATH"
    rm -f "$ALIST_BIN"
    ln -sf "$TERMUX_ALIST_PATH" "$ALIST_BIN"
elif command -v alist &> /dev/null; then
    SYSTEM_ALIST=$(command -v alist)
    if [ "$SYSTEM_ALIST" == "$ALIST_BIN" ]; then
        pkg reinstall -y alist
        if [ -f "$TERMUX_ALIST_PATH" ]; then
             rm -f "$ALIST_BIN"
             ln -sf "$TERMUX_ALIST_PATH" "$ALIST_BIN"
        else
             exit 1
        fi
    else
        rm -f "$ALIST_BIN"
        ln -sf "$SYSTEM_ALIST" "$ALIST_BIN"
    fi
else
    echo "⚠️  未检测到 Alist，正在尝试安装..."
    pkg install -y alist
    if [ -f "$TERMUX_ALIST_PATH" ]; then
        rm -f "$ALIST_BIN"
        ln -sf "$TERMUX_ALIST_PATH" "$ALIST_BIN"
    else
        echo "❌ 错误: Alist 安装失败。"
        exit 1
    fi
fi

# --- 3. 生成配置文件 ---
ENV_FILE="$HOME/.env"
echo "📝 配置文件路径: $ENV_FILE"

if [ ! -f "$ENV_FILE" ]; then
    echo "生成默认配置文件: ~/.env"
    # ⚠️ 移除了所有隧道相关的变量，强制使用 Quick Tunnel
    cat <<EOT >> "$ENV_FILE"
# ==============================
# Termux Bot 配置文件
# ==============================
BOT_TOKEN=
ADMIN_ID=

# Alist 密码 (推荐配置)
# 填入你的 Alist 密码，Bot 将直接使用此密码登录
ALIST_PASSWORD=

# 直播推流基础地址 (例如 rtmp://ip:port/live/)
TG_RTMP_URL=
# Aria2 密钥 (默认无需修改)
ARIA2_RPC_SECRET=
# GitHub 多账号配置
GITHUB_ACCOUNTS_LIST=
EOT
else
    echo "✅ 配置文件已存在，跳过覆盖。"
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

# --- 5. 赋予脚本执行权限 ---
echo "🔧 设置脚本权限..."
chmod +x start.sh update.sh monitor.sh set_pass.sh

echo "--------------------------------------------------------"
echo "✅ Termux 环境部署完成！"
echo "--------------------------------------------------------"
echo "👉 1. 请先运行: ./setup.sh"
echo "👉 2. 然后运行: ./start.sh"
echo "--------------------------------------------------------"
