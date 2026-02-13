const os = require('os');
const path = require('path');
const fs = require('fs');

const HOME = os.homedir();

// 动态解析 .env 文件以确定隧道模式
let tunnelArgs = ['tunnel', '--url', 'http://localhost:5244', '--no-autoupdate', '--metrics', 'localhost:49500'];

try {
  const envPath = path.join(HOME, '.env');
  if (fs.existsSync(envPath)) {
    const envContent = fs.readFileSync(envPath, 'utf8');
    
    // 简易解析 .env
    const tokenMatch = envContent.match(/^CLOUDFLARE_TOKEN=(.+)$/m);
    const modeMatch = envContent.match(/^TUNNEL_MODE=(.+)$/m);
    
    const token = tokenMatch ? tokenMatch[1].trim() : '';
    const mode = modeMatch ? modeMatch[1].trim() : 'quick';

    if (mode === 'token' && token) {
      tunnelArgs = ['tunnel', 'run', '--token', token];
    }
  }
} catch (error) {
  console.error("⚠️ 读取 .env 配置失败，将使用默认 Quick Tunnel 模式", error);
}

module.exports = {
  apps: [
    {
      name: "alist",
      script: path.join(HOME, "bin/alist"),
      args: "server",
      cwd: path.join(HOME, "bin"),
      autorestart: true,
      restart_delay: 5000,
      max_restarts: 10,
    },
    {
      name: "aria2",
      script: "aria2c",
      args: `--conf-path=${path.join(HOME, ".aria2/aria2.conf")}`,
      autorestart: true,
      restart_delay: 5000,
    },
    {
      name: "bot",
      script: "python3",
      args: "-u -m bot.main", // -u: 禁用输出缓冲，确保日志实时显示
      cwd: __dirname,
      autorestart: true,
      restart_delay: 3000,
    },
    {
      name: "tunnel",
      script: path.join(HOME, "bin/cloudflared"),
      args: tunnelArgs,
      autorestart: true,
      restart_delay: 5000,
      max_restarts: 10,
    }
  ]
};