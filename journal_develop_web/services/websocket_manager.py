"""
WebSocket 连接管理器（单机内存模式）
- 支持同一用户多标签页在线
- 仅内存管理，不引入 Redis
- 连接断开时自动清理，不抛异常
"""

import json
import logging

from fastapi import WebSocket

logger = logging.getLogger("uvicorn")

# user_id → [WebSocket, ...]
_active_connections: dict[int, list[WebSocket]] = {}


async def connect(user_id: int, websocket: WebSocket):
    """接受连接并注册"""
    await websocket.accept()
    _active_connections.setdefault(user_id, []).append(websocket)
    logger.info(f"[WS] user {user_id} connected (total connections for user: {len(_active_connections[user_id])})")


async def disconnect(user_id: int, websocket: WebSocket):
    """断开连接并清理"""
    conns = _active_connections.get(user_id, [])
    if websocket in conns:
        conns.remove(websocket)
    if not conns:
        _active_connections.pop(user_id, None)
    logger.info(f"[WS] user {user_id} disconnected (remaining: {len(conns)})")


async def send_to_user(user_id: int, payload: dict):
    """向指定用户的所有连接发送 JSON"""
    if user_id not in _active_connections:
        return  # 用户不在线，不报错

    conns = _active_connections[user_id]
    dead = []
    for ws in conns:
        try:
            await ws.send_json(payload)
        except Exception:
            dead.append(ws)
    for ws in dead:
        conns.remove(ws)
    if not conns:
        _active_connections.pop(user_id, None)


async def broadcast_to_users(user_ids: list[int], payload: dict):
    """向多个用户推送"""
    for uid in user_ids:
        await send_to_user(uid, payload)


def get_online_user_ids() -> list[int]:
    """获取当前在线用户列表（调试用）"""
    return list(_active_connections.keys())
