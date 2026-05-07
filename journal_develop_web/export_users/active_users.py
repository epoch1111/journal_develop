# -*- coding: utf-8 -*-
"""查看当前在线用户（需服务运行）"""
import urllib.request
import json
import sys

try:
    url = "http://localhost:8000/api/admin/online"
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req, timeout=5) as resp:
        data = json.loads(resp.read().decode("utf-8"))
except Exception as e:
    print(f"[ERROR] 无法连接服务器: {e}")
    print("请确保后端服务已启动（start.bat）")
    sys.exit(1)

online = data.get("online", [])
total = data.get("total", 0)

print()
if total == 0:
    print("  暂无在线用户")
else:
    print(f"  共 {total} 人在线：")
    print()
    for u in online:
        avatar = u.get("avatar", "🐰")
        nickname = u.get("nickname") or "小兔"
        username = u.get("username", "")
        uid = u.get("user_id", "?")
        ago = u.get("active_ago", "?")
        print(f"  {avatar}  {nickname}")
        print(f"     @{username}  UID:{uid}  {ago}")
        print()
