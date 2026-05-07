"""后台管理 - 活跃用户追踪"""

import time
from datetime import datetime, timedelta
from database import get_user_by_id

# 活跃用户字典: { user_id: { "last_active": timestamp, "username": str, "nickname": str } }
_active_users: dict[int, dict] = {}

# 活跃超时时间（秒），超过这个时间视为离线
ACTIVE_TIMEOUT = 30 * 60  # 30 分钟


def touch_user(user_id: int):
    """更新用户最后活跃时间"""
    user = get_user_by_id(user_id)
    _active_users[user_id] = {
        "last_active": time.time(),
        "username": user.get("username", "") if user else "",
        "nickname": user.get("nickname", "") if user else "",
        "avatar": user.get("avatar", "🐰") if user else "🐰",
    }


def remove_user(user_id: int):
    """移除用户（登出时调用）"""
    _active_users.pop(user_id, None)


def get_active_users(minutes: int = 30) -> list[dict]:
    """获取最近 N 分钟内有活动的用户列表"""
    cutoff = time.time() - (minutes * 60)
    active = []
    expired_ids = []
    for uid, info in _active_users.items():
        if info["last_active"] >= cutoff:
            time_diff = time.time() - info["last_active"]
            if time_diff < 60:
                ago = f"{int(time_diff)}秒前"
            elif time_diff < 3600:
                ago = f"{int(time_diff / 60)}分钟前"
            else:
                ago = f"{int(time_diff / 3600)}小时前"
            active.append({
                "user_id": uid,
                "username": info.get("username", ""),
                "nickname": info.get("nickname", ""),
                "avatar": info.get("avatar", "🐰"),
                "last_active": datetime.fromtimestamp(info["last_active"]).strftime("%H:%M:%S"),
                "active_ago": ago,
            })
        else:
            expired_ids.append(uid)
    # 清理过期
    for uid in expired_ids:
        _active_users.pop(uid, None)
    return active


def get_active_count() -> int:
    """获取当前在线用户数"""
    cutoff = time.time() - ACTIVE_TIMEOUT
    return sum(1 for v in _active_users.values() if v["last_active"] >= cutoff)

