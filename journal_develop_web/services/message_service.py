"""私信系统 - 业务逻辑层"""

from fastapi import HTTPException

from database import (
    get_user_by_id,
    get_latest_greet_between,
    has_accepted_greet_between,
    get_or_create_conversation as db_get_or_create,
    get_conversation_by_id,
    get_conversation_between,
    list_user_conversations as db_list_convs,
    create_private_message as db_create_msg,
    list_private_messages as db_list_msgs,
    mark_conversation_read as db_mark_read,
    count_unread_messages as db_count_unread,
    update_conversation_last_message as db_update_last,
)

MAX_CONTENT_LENGTH = 1000


def can_message(user_a_id: int, user_b_id: int) -> bool:
    """检查两人之间是否存在 accepted 的打招呼关系"""
    return has_accepted_greet_between(user_a_id, user_b_id)


def _get_other_user_id(conv: dict, current_user_id: int) -> int:
    """返回会话中对方的 user_id"""
    if conv["user1_id"] == current_user_id:
        return conv["user2_id"]
    return conv["user1_id"]


def _check_can_message(user_a_id: int, user_b_id: int):
    if user_a_id == user_b_id:
        raise HTTPException(status_code=400, detail="不能给自己发消息哦")
    if not can_message(user_a_id, user_b_id):
        raise HTTPException(status_code=403, detail="你们还没有互相认识，暂时不能私信")


# ============ 会话 ============

def get_or_create_chat(current_user_id: int, target_user_id: int) -> dict:
    _check_user_exists(target_user_id)
    from services.safety_service import check_block_or_raise
    check_block_or_raise(current_user_id, target_user_id)
    _check_can_message(current_user_id, target_user_id)

    conv = db_get_or_create(current_user_id, target_user_id)
    if not conv:
        raise HTTPException(status_code=500, detail="创建会话失败")

    other = get_user_by_id(target_user_id)
    return {
        "ok": True,
        "conversation": {
            "id": conv["id"],
            "other_user": {
                "id": other["id"],
                "nickname": other.get("nickname", "小兔"),
                "avatar": other.get("avatar", "🐰"),
            } if other else None,
        },
    }


def list_conversations(current_user_id: int) -> list[dict]:
    convs = db_list_convs(current_user_id)
    return [
        {
            "id": c["id"],
            "other_user": c.get("other_user"),
            "last_message": c.get("last_message", ""),
            "last_message_at": c.get("last_message_at", ""),
            "unread_count": c.get("unread_count", 0),
        }
        for c in convs
    ]


# ============ 消息 ============

def _check_user_exists(user_id: int):
    if not get_user_by_id(user_id):
        raise HTTPException(status_code=404, detail="用户不存在")


def _get_conversation_for_user(conversation_id: int, user_id: int) -> dict:
    """获取会话并验证参与者身份"""
    conv = get_conversation_by_id(conversation_id)
    if not conv:
        raise HTTPException(status_code=404, detail="会话不存在")
    if conv["user1_id"] != user_id and conv["user2_id"] != user_id:
        raise HTTPException(status_code=403, detail="无权访问此会话")
    return conv


def send_message(current_user_id: int, conversation_id: int, content: str, image_url: str = '') -> dict:
    conv = _get_conversation_for_user(conversation_id, current_user_id)
    receiver_id = _get_other_user_id(conv, current_user_id)
    from services.safety_service import check_block_or_raise
    check_block_or_raise(current_user_id, receiver_id)
    content = (content or "").strip()
    if not content and not image_url:
        raise HTTPException(status_code=400, detail="消息内容或图片不能为空")
    if len(content) > MAX_CONTENT_LENGTH:
        raise HTTPException(
            status_code=400,
            detail=f"消息内容过长，最多 {MAX_CONTENT_LENGTH} 字",
        )

    mid = db_create_msg(conversation_id, current_user_id, receiver_id, content, image_url)
    if mid is None:
        raise HTTPException(status_code=500, detail="发送失败")

    from datetime import datetime
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    preview = image_url if not content else content
    db_update_last(conversation_id, preview, now)

    message_obj = {
        "id": mid,
        "conversation_id": conversation_id,
        "sender_id": current_user_id,
        "receiver_id": receiver_id,
        "content": content,
        "image_url": image_url,
        "is_read": False,
        "created_at": now,
    }

    # WebSocket 实时推送（后台异步，不阻塞 HTTP 响应）
    import asyncio
    async def _push():
        from services.websocket_manager import send_to_user
        # 推送给接收方
        await send_to_user(receiver_id, {
            "type": "new_message",
            "conversation_id": conversation_id,
            "message": message_obj,
            "conversation": {
                "id": conversation_id,
                "last_message": content,
                "last_message_at": now,
            },
        })
        # 推送给发送方确认
        await send_to_user(current_user_id, {
            "type": "message_sent",
            "conversation_id": conversation_id,
            "message_id": mid,
        })
        # 推送未读数更新给接收方
        unread = db_count_unread(receiver_id)
        await send_to_user(receiver_id, {
            "type": "message_unread_count_update",
            "unread_count": unread,
        })
    try:
        asyncio.create_task(_push())
    except Exception:
        pass  # WebSocket 推送失败不影响 HTTP 响应

    return {
        "ok": True,
        "message": message_obj,
    }


def list_messages(current_user_id: int, conversation_id: int, page: int = 1, page_size: int = 30) -> dict:
    _get_conversation_for_user(conversation_id, current_user_id)
    page = max(1, page)
    page_size = min(max(1, page_size), 50)
    # 自动标记已读
    db_mark_read(conversation_id, current_user_id)
    return db_list_msgs(conversation_id, page, page_size)


def mark_read(current_user_id: int, conversation_id: int) -> dict:
    _get_conversation_for_user(conversation_id, current_user_id)
    db_mark_read(conversation_id, current_user_id)
    return {"ok": True}


def get_unread_count(current_user_id: int) -> dict:
    return {"unread_count": db_count_unread(current_user_id)}
