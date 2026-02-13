# Termux Alist Bot

专为 **Android Termux** 打造的轻量级网盘与下载机器人。

## ✨ 功能特点

*   📱 **手机即服务器**: 利用旧手机搭建 Alist 网盘。
*   🚀 **内网穿透**: 内置 Cloudflare Tunnel，无公网 IP 也能访问。
*   🤖 **Telegram 控制**: 在 TG 上管理文件、添加下载任务。
*   ⬇️ **离线下载**: 集成 Aria2，支持 http/ftp/magnet 下载。
*   🔄 **自动更新**: 代码推送到 GitHub，手机端自动同步升级。

## ⚠️ 关键设置 (Android 12+)

Android 12 及更高版本有名为 "Phantom Process Killer" 的机制，会在后台杀掉 Termux 的子进程。

**解决方法 (推荐):**
连接电脑使用 ADB 执行：
```bash
adb shell "/system/bin/device_config put activity_manager max_phantom_processes 2147483647"
```

## 🛠️ 安装教程

1.  **下载 Termux**: 建议从 F-Droid 下载最新版。
2.  **配置权限**: `termux-setup-storage`
3.  **拉取代码**:
    ```bash
    git clone https://github.com/YOUR_NAME/YOUR_REPO.git bot
    cd bot
    ```
4.  **一键安装**:
    ```bash
    chmod +x setup.sh
    ./setup.sh
    ```
5.  **配置变量**:
    ```bash
    nano ~/.env
    ```
    *参考项目中的 `.env.example` 文件填写。*

6.  **启动**: `./start.sh`

## 📝 配置文件说明 (~/.env)

| 变量名 | 必填 | 说明 |
| :--- | :--- | :--- |
| `BOT_TOKEN` | ✅ | Telegram 机器人 Token |
| `ADMIN_ID` | ✅ | 你的 Telegram 用户 ID |
| `TUNNEL_MODE` | ✅ | `quick` (随机) 或 `token` (固定) |
| `CLOUDFLARE_TOKEN` | ❌ | 固定域名模式必须填 |
| `ALIST_DOMAIN` | ❌ | 固定域名地址 (不带http) |
| `ARIA2_RPC_SECRET` | ❌ | Aria2 密码，推荐设置 |
| `TG_RTMP_URL` | ❌ | 直播推流地址 |

## 📂 目录结构

*   `~/bin/`: 存放二进制文件 (alist, cloudflared)
*   `~/.aria2/`: Aria2 配置与会话
*   `~/downloads/`: 默认下载目录
*   `~/.env`: **配置文件 (位于 Termux 根目录)**
