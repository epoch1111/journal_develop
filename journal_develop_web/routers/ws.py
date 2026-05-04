"""
WebSocket 路由 —— 实时消息推送（单机内存模式）
端点: /ws/messages?token=<jwt_token>
"""

import logging
from datetime import datetime

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from services.auth_service import decode_access_token
from database import get_user_by_id
from services.websocket_manager import connect, disconnect

logger = logging.getLogger("uvicorn")
router = APIRouter()


@router.websocket("/ws/messages")
async def ws_messages(websocket: WebSocket, token: str = ""):
    # 验证 JWT token
    if not token:
        await websocket.close(code=1008, reason="缺少 token")
        return

    payload = decode_access_token(token)
    if payload is None:
        await websocket.close(code=1008, reason="token 无效或已过期")
        return

    user_id = int(payload.get("sub", 0))
    if not user_id:
        await websocket.close(code=1008, reason="token 无效")
        return

    user = get_user_by_id(user_id)
    if user is None:
        await websocket.close(code=1008, reason="用户不存在")
        return

    # 注册连接
    await connect(user_id, websocket)

    try:
        while True:
            data = await websocket.receive_json()
            msg_type = data.get("type", "")

            if msg_type == "ping":
                await websocket.send_json({
                    "type": "pong",
                    "ts": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                })
            else:
                logger.debug(f"[WS] unknown message type from user {user_id}: {msg_type}")

    except WebSocketDisconnect:
        pass
    except Exception as e:
        logger.error(f"[WS] error for user {user_id}: {e}")
    finally:
        await disconnect(user_id, websocket)
