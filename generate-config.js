import fs from 'fs';
import path from 'path';
import os from 'os';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const HOME = os.homedir();

// 获取 Python 解释器的绝对路径 (Termux 环境通常在 /data/data/com.termux/files/usr/bin/python)
let pythonExec = "python3";
try {
  const check = execSync("which python3").toString().trim();
  if (check && fs.existsSync(check)) {
    pythonExec = check;
  }
} catch (e) {
  // fallback to default
}

console.log(`ℹ️ Python 路径: ${pythonExec}`);

// 默认隧道参数
let tunnelArgs = ['tunnel', '--url', 'http://localhost:5244', '--no-autoupdate', '--metrics', 'localhost:49500'];

const envPath = path.join(HOME, '.env');

try {
  if (fs.existsSync(envPath)) {
    const envContent = fs.readFileSync(envPath, 'utf8');
    
    // 解析 .env 获取 Cloudflare 配置
    const tokenMatch = envContent.match(/^CLOUDFLARE_TOKEN=(.+)$/m);
    const modeMatch = envContent.match(/^TUNNEL_MODE=(.+)$/m);
    
    const token = tokenMatch ? tokenMatch[1].trim() : '';
    const mode = modeMatch ? modeMatch[1].trim() : 'quick';

    if (mode === 'token' && token) {
      tunnelArgs = ['tunnel', 'run', '--token', token];
    }
  }
} catch (error) {
  console.error("⚠️ 读取 .env 失败，将使用默认配置:", error);
}

// 定义 PM2 配置对象
const config = {
  apps: [
    {
      name: "alist",
      script: path.join(HOME, "bin/alist"),
      args: ["server"],
      cwd: path.join(HOME, "bin"),
      autorestart: true,
      restart_delay: 5000,
      max_restarts: 10,
    },
    {
      name: "aria2",
      script: "aria2c",
      args: [`--conf-path=${path.join(HOME, ".aria2/aria2.conf")}`],
      autorestart: true,
      restart_delay: 5000,
    },
    {
      name: "bot",
      script: pythonExec,
      args: ["-u", "-m", "bot.main"],
      cwd: __dirname,
      autorestart: true,
      restart_delay: 3000,
      // 传递环境变量，确保代理设置等生效
      env: {
        ...process.env,
        PYTHONUNBUFFERED: "1"
      }
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

// 写入 JSON 文件
const outputPath = path.join(__dirname, 'ecosystem.config.json');
try {
  fs.writeFileSync(outputPath, JSON.stringify(config, null, 2));
  console.log(`✅ 已生成 PM2 配置文件: ${outputPath}`);
} catch (err) {
  console.error("❌ 生成配置文件失败:", err);
  process.exit(1);
}
