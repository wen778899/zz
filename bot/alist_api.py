
import requests
import logging
import json
from .system import get_admin_pass

logger = logging.getLogger(__name__)

ALIST_API_URL = "http://127.0.0.1:5244"
_cached_token = None

def get_token():
    """获取或刷新 Alist Token"""
    global _cached_token
    if _cached_token: return _cached_token
    
    password = get_admin_pass()
    if not password or "失败" in password:
        logger.error("无法获取 Alist 密码，API 调用失败")
        return None

    try:
        # 尝试登录获取 Token
        url = f"{ALIST_API_URL}/api/auth/login"
        r = requests.post(url, json={"username": "admin", "password": password}, timeout=5)
        data = r.json()
        if data.get("code") == 200:
            _cached_token = data["data"]["token"]
            return _cached_token
        else:
            logger.error(f"Alist 登录失败: {data}")
            return None
    except Exception as e:
        logger.error(f"Alist API 连接失败: {e}")
        return None

def fetch_file_list(path="/", page=1, per_page=100):
    """获取文件列表"""
    token = get_token()
    if not token: return None, "无法获取 Token，请检查 Alist 是否启动"

    url = f"{ALIST_API_URL}/api/fs/list"
    headers = {"Authorization": token}
    payload = {
        "path": path,
        "page": page,
        "per_page": per_page,
        "refresh": False
    }

    try:
        r = requests.post(url, headers=headers, json=payload, timeout=10)
        data = r.json()
        if data.get("code") == 200:
            return data["data"]["content"], None
        else:
            return None, f"API 错误: {data.get('message')}"
    except Exception as e:
        return None, str(e)

def get_file_info(path):
    """获取单个文件信息 (用于获取直链等，暂时备用)"""
    token = get_token()
    url = f"{ALIST_API_URL}/api/fs/get"
    headers = {"Authorization": token}
    try:
        r = requests.post(url, headers=headers, json={"path": path}, timeout=5)
        return r.json()
    except:
        return None
