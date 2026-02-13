import traceback
import html
import json
import logging
import os
from telegram import Update, ReplyKeyboardMarkup
from telegram.ext import ContextTypes
from telegram.constants import ParseMode

from .config import MAIN_MENU, ADMIN_MENU, check_auth, get_account_count, ADMIN_ID
from .system import (
    get_system_stats, 
    get_log_file_path,
    get_public_url, 
    get_admin_pass, 
    restart_pm2_services, 
    add_aria2_task,
    check_services_health,
    get_aria2_status
)
from .github import trigger_stream_action, get_all_usage_stats

logger = logging.getLogger(__name__)

async def global_error_handler(update: object, context: ContextTypes.DEFAULT_TYPE) -> None:
    logger.error("Exception while handling an update:", exc_info=context.error)
    if ADMIN_ID:
        try:
            await context.bot.send_message(chat_id=ADMIN_ID, text=f"🚨 Bot 发生错误: {context.error}")
        except:
            pass

# --- 定时任务 ---
LAST_SERVICE_STATUS = {}
async def monitor_services_job(context: ContextTypes.DEFAULT_TYPE):
    global LAST_SERVICE_STATUS
    current_status = check_services_health()
    alerts = []
    for svc, is_running in current_status.items():
        if LAST_SERVICE_STATUS.get(svc, True) and not is_running:
            alerts.append(f"❌ 服务挂掉: `{svc}`")
        elif not LAST_SERVICE_STATUS.get(svc, False) and is_running:
             alerts.append(f"✅ 服务已恢复: `{svc}`")
    LAST_SERVICE_STATUS = current_status
    if alerts and ADMIN_ID:
        try:
            alert_msg = "🔔 *系统监控报告*\n\n" + "\n".join(alerts)
            await context.bot.send_message(chat_id=ADMIN_ID, text=alert_msg, parse_mode=ParseMode.MARKDOWN)
        except:
            pass

# --- 命令处理器 ---

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not check_auth(update.effective_user.id): return
    await show_main_menu(update)

async def show_main_menu(update: Update):
    markup = ReplyKeyboardMarkup(MAIN_MENU, resize_keyboard=True)
    await update.message.reply_text("🤖 *Termux 控制台*", reply_markup=markup, parse_mode=ParseMode.MARKDOWN)

async def download_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not check_auth(update.effective_user.id): return
    if not context.args: 
        await update.message.reply_text("用法: `/dl http://example.com/file.zip`", parse_mode=ParseMode.MARKDOWN)
        return
    success, msg = add_aria2_task(context.args[0])
    await update.message.reply_text(msg, parse_mode=ParseMode.MARKDOWN)

async def trigger_stream(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not check_auth(update.effective_user.id): return
    if not context.args:
        await update.message.reply_text("用法: `/stream /path/to/video.mp4`")
        return
    base_url = get_public_url()
    if not base_url:
        await update.message.reply_text("❌ 隧道未启动，无法生成外网链接")
        return
    success, msg, _ = trigger_stream_action(base_url, " ".join(context.args))
    await update.message.reply_text(msg, parse_mode=ParseMode.MARKDOWN)

# --- 消息处理器 ---

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not check_auth(update.effective_user.id): return
    text = update.message.text
    
    if text == "📊 状态": await send_status(update, context)
    elif text == "📥 任务": await send_tasks(update, context)
    elif text == "☁️ 隧道": await send_tunnel(update, context)
    elif text == "⬇️ 下载": await send_download_help(update, context)
    elif text == "📺 推流": await send_stream_help(update, context)
    elif text == "📝 日志": await send_logs(update, context)
    elif text == "⚙️ 管理": await show_admin_menu(update, context)
    elif text == "🔄 重启服务": await restart_services(update, context)
    elif text == "🔑 查看密码": await send_admin_pass(update, context)
    elif text == "📉 GitHub 用量": await send_usage_stats(update, context)
    elif text == "❓ 帮助": await send_help(update, context)
    elif text == "🔙 返回主菜单": await start(update, context)

# --- 辅助函数 ---

async def show_admin_menu(update: Update, context: ContextTypes.DEFAULT_TYPE):
    markup = ReplyKeyboardMarkup(ADMIN_MENU, resize_keyboard=True)
    await update.message.reply_text("⚙️ *系统管理*", reply_markup=markup, parse_mode=ParseMode.MARKDOWN)

async def send_status(update: Update, context: ContextTypes.DEFAULT_TYPE):
    msg = get_system_stats()
    await update.message.reply_text(msg, parse_mode=ParseMode.MARKDOWN)

async def send_tasks(update: Update, context: ContextTypes.DEFAULT_TYPE):
    msg = get_aria2_status()
    await update.message.reply_text(msg, parse_mode=ParseMode.MARKDOWN)

async def send_logs(update: Update, context: ContextTypes.DEFAULT_TYPE):
    log_file = get_log_file_path("alist")
    if os.path.exists(log_file):
        await update.message.reply_text("📂 正在上传 Alist 日志文件...")
        await update.message.reply_document(document=open(log_file, 'rb'))
    else:
        await update.message.reply_text("❌ 日志文件不存在")

async def send_tunnel(update: Update, context: ContextTypes.DEFAULT_TYPE):
    url = get_public_url()
    await update.message.reply_text(f"☁️ *Cloudflare:* `{url if url else 'N/A'}`", parse_mode=ParseMode.MARKDOWN)

async def restart_services(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("⏳ 正在重启服务... (Bot 可能会短暂离线)")
    # 这里 PM2 重启会导致 Bot 进程也重启，所以消息发完可能就断了，正常现象
    restart_pm2_services()

async def send_admin_pass(update: Update, context: ContextTypes.DEFAULT_TYPE):
    res = get_admin_pass()
    await update.message.reply_text(f"🔑 *Alist 密码:*\n`{res}`", parse_mode=ParseMode.MARKDOWN)

async def send_usage_stats(update: Update, context: ContextTypes.DEFAULT_TYPE):
    results = get_all_usage_stats()
    msg = "📉 *GitHub 用量:*\n\n" + ("\n".join(results) if results else "未配置")
    await update.message.reply_text(msg, parse_mode=ParseMode.MARKDOWN)

async def send_download_help(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        "⬇️ *下载功能*\n"
        "发送 `/dl <链接>` 让 Aria2 下载文件。\n"
        "文件将保存到 Termux 的 `~/downloads` 目录，"
        "你可以通过 Alist 在线管理这些文件。",
        parse_mode=ParseMode.MARKDOWN
    )

async def send_stream_help(update: Update, context: ContextTypes.DEFAULT_TYPE):
    count = get_account_count()
    await update.message.reply_text(
        f"📺 *推流功能*\n"
        f"当前可用账号池: {count} 个\n\n"
        "用法: `/stream /video.mp4`\n"
        "Bot 会自动拼接你的 Cloudflare 域名，并调用 GitHub Actions "
        "将该视频推流到你配置的 Telegram 直播间。",
        parse_mode=ParseMode.MARKDOWN
    )

async def send_help(update: Update, context: ContextTypes.DEFAULT_TYPE):
    help_text = (
        "📖 *Termux Bot 使用指南*\n\n"
        "1. *文件管理*: 使用浏览器访问 Cloudflare 链接进入 Alist。\n"
        "2. *离线下载*: 使用 `/dl` 命令添加任务，使用 '📥 任务' 查看进度。\n"
        "3. *直播推流*: 确保 `~/.env` 配置了 `TG_RTMP_URL`。\n"
        "4. *自动更新*: 修改 GitHub 代码后，Bot 会自动同步并重启。\n"
        "5. *保活*: 请勿在多任务界面划掉 Termux，建议开启唤醒锁。"
    )
    await update.message.reply_text(help_text, parse_mode=ParseMode.MARKDOWN)
