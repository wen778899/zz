const fs = require('fs');
const os = require('os');
const path = require('path');

const HOME = os.homedir();
const PROJECT_ROOT = __dirname;

// Termux 中脚本通常在 HOME/bin 下
const alistPath = path.join(HOME, 'bin', 'alist');
const cloudflaredPath = path.join(HOME, 'bin', 'cloudflared');

// 读取环境配置 (通过 start.sh 加载进来的环境变量)
const mode = process.env.TUNNEL_MODE || 'quick';
const token = process.env.CLOUDFLARE_TOKEN;
const aria2Secret = process.env.ARIA2_RPC_SECRET;

// 配置 Cloudflare Tunnel
let tunnelArgs = [];
if (mode === 'token' && token) {
  tunnelArgs = ["tunnel", "run"]; 
} else {
  // 默认使用 Quick Tunnel 转发 Alist 的 5244 端口
  tunnelArgs = ["tunnel", "--url", "http://localhost:5244"];
}

// 配置 Aria2
let aria2Args = [`--conf-path=${HOME}/.aria2/aria2.conf`];
if (aria2Secret) {
  // 如果环境变量中设置了密钥，则动态添加到启动参数中
  aria2Args.push(`--rpc-secret=${aria2Secret}`);
}

module.exports = {
  apps : [
    {
      name: "alist",
      script: alistPath,
      args: "server",
      autorestart: true,
      max_memory_restart: '300M',
      out_file: "/dev/null", 
      error_file: path.join(HOME, ".pm2", "logs", "alist-error.log")
    },
    {
      name: "aria2",
      script: "aria2c",
      args: aria2Args, // 使用动态生成的参数
      autorestart: true
    },
    {
      name: "bot",
      script: path.join(PROJECT_ROOT, "bot", "main.py"),
      interpreter: "python",
      autorestart: true,
      env: {
        PYTHONUNBUFFERED: "1"
      }
    },
    {
      name: "tunnel",
      script: cloudflaredPath,
      args: tunnelArgs,
      autorestart: true,
      restart_delay: 5000
    },
    {
      name: "monitor",
      script: path.join(PROJECT_ROOT, "monitor.sh"),
      interpreter: "bash",
      autorestart: true
    }
  ]
};