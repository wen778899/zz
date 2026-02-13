import json
import os
import logging
from .config import HOME_DIR

# 使用隐藏目录，确保不受项目文件夹名称变更影响
DATA_DIR = os.path.join(HOME_DIR, ".alist-bot-data")
DATA_FILE = os.path.join(DATA_DIR, "stream_keys.json")

logger = logging.getLogger(__name__)

def _load_data():
    """加载数据，如果文件不存在或损坏则返回空字典"""
    if not os.path.exists(DATA_DIR):
        try:
            os.makedirs(DATA_DIR, exist_ok=True)
        except Exception as e:
            logger.error(f"创建数据目录失败: {e}")
            return {}
    
    if not os.path.exists(DATA_FILE):
        return {}
    
    try:
        with open(DATA_FILE, 'r', encoding='utf-8') as f:
            content = f.read().strip()
            if not content: return {}
            return json.load(f)
    except json.JSONDecodeError:
        logger.error("配置文件 JSON 格式错误，已重置为空。")
        # 备份损坏的文件
        try:
            os.rename(DATA_FILE, DATA_FILE + ".bak")
        except: pass
        return {}
    except Exception as e:
        logger.error(f"读取密钥文件失败: {e}")
        return {}

def _save_data(data):
    """保存数据"""
    if not os.path.exists(DATA_DIR):
        os.makedirs(DATA_DIR, exist_ok=True)
    try:
        with open(DATA_FILE, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.flush()
            os.fsync(f.fileno()) # 强制写入磁盘
        return True
    except Exception as e:
        logger.error(f"写入密钥文件失败: {e}")
        return False

def add_key(name, url):
    """添加或更新密钥"""
    try:
        data = _load_data()
        data[name] = url.strip()
        return _save_data(data)
    except Exception as e:
        logger.error(f"添加密钥逻辑错误: {e}")
        return False

def delete_key(name):
    """删除密钥"""
    try:
        data = _load_data()
        if name in data:
            del data[name]
            _save_data(data)
            return True
        return False
    except Exception:
        return False

def get_key(name):
    """获取指定名称的密钥"""
    data = _load_data()
    return data.get(name)

def get_all_keys():
    """获取所有密钥"""
    return _load_data()

def get_default_key():
    """获取第一个密钥作为默认值"""
    data = _load_data()
    if data:
        # 返回 (名称, URL)
        key = next(iter(data))
        return key, data[key]
    return None, None
