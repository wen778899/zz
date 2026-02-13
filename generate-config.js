
import fs from 'fs';
import path from 'path';
import os from 'os';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const HOME = os.homedir();

// 1. 获取 Python 解释器路径
let pythonExec = "python3";
try {
  const check = execSync("command -v python3").toString().trim();
  if (check) {
    pythonExec = check;
  }
} catch (e) {
  const termuxPy = "/data/data/com.termux/files/usr/bin/python3";
  if (fs.existsSync(termuxPy)) {
    pythonExec = termuxPy;
  }
}

console.log(`ℹ️ Python 路径: ${pythonExec}`);

// 2. 检测 termux-chroot (解决 DNS 问题的关键)
let termuxChrootPath = "";
let useProot = false;
try {
  termuxChrootPath = execSync("command -v termux-chroot").toString().trim();
  if (termuxChrootPath) {
      useProot = true;
      console.log(`ℹ️ 检测到 Termux 环境: 将启用 termux-chroot (${termuxChrootPath})`);
  }
} catch (e) {
  console.log("ℹ️ 未检测到 termux-chroot，将直接运行");
}

// 3. 准备目录
const alistDataDir = path.join(HOME, 'alist-data');
if (!fs.existsSync(alistDataDir)) {
    try {
        fs.mkdirSync(alistDataDir, { recursive: true });
        console.log(`✅ 创建 Alist 数据目录: ${alistDataDir}`);
    } catch (e) {
        console.error("❌ 无法创建数据目录:", e);
    }
}

// 4. 解析配置
// 添加 --edge-ip-version 4 强制 IPv4，提高稳定性
// 关键: 指向 localhost 而不是 127.0.0.1 有时在 proot 下更好，但保持 127.0.0.1 通常更明确
let tunnelArgs = ['tunnel', '--url', 'http://127.0.0.1:5244', '--no-autoupdate', '--protocol', 'http2', '--edge-ip-version', '4', '--metrics', '127.0.0.1:49500'];

const envPath = path.join(HOME, '.env');

try {
  if (fs.existsSync(envPath)) {
    const envContent = fs.readFileSync(envPath, 'utf8');
    
    const getEnv = (key, defaultVal) => {
        const regex = new RegExp(`^${key}=(.*)$`, 'm');
        const match = envContent.match(regex);
        if (!match) return defaultVal;
        let val = match[1].trim();
        if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
            val = val.slice(1, -1);
        }
        return val;
    };
    
    const token = getEnv('CLOUDFLARE_TOKEN', '');
    const mode = getEnv('TUNNEL_MODE', 'quick');

    if (mode === 'token' && token) {
      tunnelArgs = ['tunnel', 'run', '--token', token, '--protocol', 'http2', '--edge-ip-version', '4', '--metrics', '127.0.0.1:49500'];
      console.log(`ℹ️ 启用 Tunnel Token 模式 (Token 长度: ${token.length})`);
    } else {
        console.log(`ℹ️ 启用 Tunnel Quick 模式`);
    }
  }
} catch (error) {
  console.error("⚠️ 读取 .env 失败，将使用默认配置:", error);
}

// 5. 定义 App 配置
// Alist
const alistApp = {
  name: "alist",
  script: path.join(HOME, "bin/alist"),
  args: ["server", "--data", alistDataDir],
  cwd: alistDataDir,
  interpreter: "none",
  autorestart: true,
  restart_delay: 5000,
  max_restarts: 10,
};

// Cloudflared
const cloudflaredApp = {
    name: "tunnel",
    script: path.join(HOME, "bin/cloudflared"),
    args: tunnelArgs,
    interpreter: "none",
    autorestart: true,
    restart_delay: 5000,
    max_restarts: 10
};

// 如果在 Termux 下，使用 termux-chroot 启动
// ⚡️ 核心修改: 将 Alist 和 Tunnel 都放入 proot 环境，确保网络环境一致
if (useProot) {
    // Alist
    alistApp.script = termuxChrootPath;
    alistApp.interpreter = "bash";
    alistApp.args = [path.join(HOME, "bin/alist"), "server", "--data", alistDataDir];

    // Tunnel
    cloudflaredApp.script = termuxChrootPath;
    cloudflaredApp.interpreter = "bash";
    cloudflaredApp.args = [path.join(HOME, "bin/cloudflared"), ...tunnelArgs];
}

// 6. 最终 PM2 配置
const config = {
  apps: [
    alistApp,
    {
      name: "aria2",
      script: "aria2c",
      args: [`--conf-path=${path.join(HOME, ".aria2/aria2.conf")}`],
      interpreter: "none", 
      autorestart: true,
      restart_delay: 5000,
    },
    {
      name: "bot",
      script: pythonExec,
      args: ["-u", "-m", "bot.main"],
      cwd: __dirname,
      interpreter: "none",
      autorestart: true,
      restart_delay: 3000,
      env: {
        ...process.env,
        PYTHONUNBUFFERED: "1"
      }
    },
    cloudflaredApp
  ]
};

// 7. 写入文件
const outputPath = path.join(__dirname, 'ecosystem.config.json');
try {
  fs.writeFileSync(outputPath, JSON.stringify(config, null, 2));
  console.log(`✅ 已生成 PM2 配置文件: ${outputPath}`);
} catch (err) {
  console.error("❌ 生成配置文件失败:", err);
  process.exit(1);
}
