"""通知中心 - 业务逻辑层"""

from fastapi import HTTPException

from database import (
    create_notification as db_create_notification,
    notification_exists as db_notification_exists,
    list_notifications as db_list_notifications,
    count_unread_notifications as db_count_unread,
    mark_notification_read as db_mark_read,
    mark_all_notifications_read as db_mark_all_read,
    delete_notification as db_delete_notification,
    get_user_by_id,
    get_diary_by_id,
    get_user_recent_public_diaries,
    get_block_direction,
)


def _should_notify(recipient_id: int, actor_id: int) -> bool:
    """检查是否应该发送通知（recipient 未拉黑 actor）"""
    if not recipient_id or not actor_id:
        return True
    direction = get_block_direction(recipient_id, actor_id)
    # 如果 recipient 拉黑了 actor，不发送通知
    return direction != 'blocked'


def _get_nickname(user_id: int | None) -> str:
    if not user_id:
        return "匿名小伙伴"
    user = get_user_by_id(user_id)
    return user["nickname"] if user else "匿名小伙伴"


def _ws_push_notification(recipient_id: int, notif_id: int, notif_type: str,
                          title: str, content: str, entity_type: str, entity_id: int,
                          actor_nickname: str | None = None):
    """通过 WebSocket 实时推送通知"""
    import asyncio

    async def _push():
        from services.websocket_manager import send_to_user
        from datetime import datetime
        await send_to_user(recipient_id, {
            "type": "new_notification",
            "notification": {
                "id": notif_id,
                "type": notif_type,
                "title": title,
                "content": content,
                "is_read": False,
                "created_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                "entity_type": entity_type,
                "entity_id": entity_id,
                "actor_nickname": actor_nickname,
            },
        })
        # 同时推送未读计数
        unread = db_count_unread(recipient_id)
        await send_to_user(recipient_id, {
            "type": "notification_unread_count_update",
            "unread_count": unread,
        })

    try:
        asyncio.create_task(_push())
    except Exception:
        pass


# ============ 通知触发函数 ============

def notify_follow(follower_id: int, following_id: int):
    """关注通知：首次关注成功时调用，重复关注不通知"""
    if not _should_notify(following_id, follower_id):
        return
    if db_notification_exists(following_id, follower_id, "follow", follower_id):
        return
    nickname = _get_nickname(follower_id)
    nid = db_create_notification(
        recipient_id=following_id,
        actor_id=follower_id,
        type="follow",
        entity_type="user",
        entity_id=follower_id,
        title="有人关注了你",
        content=f"{nickname} 关注了你",
    )
    if nid:
        _ws_push_notification(following_id, nid, "follow", "有人关注了你",
                              f"{nickname} 关注了你", "user", follower_id, nickname)


def notify_public_diary_like(actor_id: int, diary_id: int):
    """点亮通知：首次点亮成功时调用，自己点自己不通知"""
    diary = get_diary_by_id(diary_id)
    if not diary:
        return
    recipient_id = diary.get("user_id", 0)
    if not recipient_id or recipient_id == actor_id:
        return
    if not _should_notify(recipient_id, actor_id):
        return
    if db_notification_exists(recipient_id, actor_id, "public_diary_like", diary_id):
        return
    nickname = _get_nickname(actor_id)
    nid = db_create_notification(
        recipient_id=recipient_id,
        actor_id=actor_id,
        type="public_diary_like",
        entity_type="diary",
        entity_id=diary_id,
        title="你的日记被点亮了",
        content=f"{nickname} 点亮了你的日记",
    )
    if nid:
        _ws_push_notification(recipient_id, nid, "public_diary_like", "你的日记被点亮了",
                              f"{nickname} 点亮了你的日记", "diary", diary_id, nickname)


def notify_public_diary_comment(actor_id: int, diary_id: int, comment_content: str):
    """评论通知：评论成功后调用，自己评论自己不通知"""
    diary = get_diary_by_id(diary_id)
    if not diary:
        return
    recipient_id = diary.get("user_id", 0)
    if not recipient_id or recipient_id == actor_id:
        return
    if not _should_notify(recipient_id, actor_id):
        return
    nickname = _get_nickname(actor_id)
    summary = (comment_content or "").strip()
    if len(summary) > 30:
        summary = summary[:30] + "…"
    nid = db_create_notification(
        recipient_id=recipient_id,
        actor_id=actor_id,
        type="public_diary_comment",
        entity_type="diary",
        entity_id=diary_id,
        title="你的日记有新评论",
        content=f"{nickname} 评论了你的日记：{summary}",
    )
    if nid:
        _ws_push_notification(recipient_id, nid, "public_diary_comment",
                              "你的日记有新评论", f"{nickname} 评论了你的日记：{summary}",
                              "diary", diary_id, nickname)


def notify_comment_reply(actor_id: int, reply_to_user_id: int, diary_id: int,
                         parent_comment_id: int, reply_content: str):
    """评论被回复通知：通知被回复的人"""
    if actor_id == reply_to_user_id:
        return
    if not _should_notify(reply_to_user_id, actor_id):
        return
    if db_notification_exists(reply_to_user_id, actor_id, "public_diary_comment_reply", parent_comment_id):
        return
    nickname = _get_nickname(actor_id)
    summary = (reply_content or "").strip()
    if len(summary) > 30:
        summary = summary[:30] + "…"
    nid = db_create_notification(
        recipient_id=reply_to_user_id,
        actor_id=actor_id,
        type="public_diary_comment_reply",
        entity_type="diary",
        entity_id=diary_id,
        title="有人回复了你的评论",
        content=f"{nickname} 回复了你的评论：{summary}",
    )
    if nid:
        _ws_push_notification(reply_to_user_id, nid, "public_diary_comment_reply",
                              "有人回复了你的评论", f"{nickname} 回复了你的评论：{summary}",
                              "diary", diary_id, nickname)


def notify_treehole_hug(diary_id: int, actor_id: int | None = None):
    """树洞抱抱通知：匿名展示"""
    diary = get_diary_by_id(diary_id)
    if not diary:
        return
    recipient_id = diary.get("user_id", 0)
    if not recipient_id:
        return
    if actor_id and not _should_notify(recipient_id, actor_id):
        return
    if db_notification_exists(recipient_id, None, "treehole_hug", diary_id):
        return
    nid = db_create_notification(
        recipient_id=recipient_id,
        actor_id=None,
        type="treehole_hug",
        entity_type="treehole",
        entity_id=diary_id,
        title="你的树洞被抱抱了",
        content="有人抱抱了你的树洞",
    )
    if nid:
        _ws_push_notification(recipient_id, nid, "treehole_hug", "你的树洞被抱抱了",
                              "有人抱抱了你的树洞", "treehole", diary_id)


def notify_treehole_reply(diary_id: int, reply_content: str, actor_id: int | None = None):
    """树洞回复通知：匿名展示"""
    diary = get_diary_by_id(diary_id)
    if not diary:
        return
    recipient_id = diary.get("user_id", 0)
    if not recipient_id:
        return
    if actor_id and not _should_notify(recipient_id, actor_id):
        return
    summary = (reply_content or "").strip()
    if len(summary) > 30:
        summary = summary[:30] + "…"
    nid = db_create_notification(
        recipient_id=recipient_id,
        actor_id=None,
        type="treehole_reply",
        entity_type="treehole",
        entity_id=diary_id,
        title="你的树洞有新回应",
        content=f"有人回应了你的树洞：{summary}",
    )
    if nid:
        _ws_push_notification(recipient_id, nid, "treehole_reply", "你的树洞有新回应",
                              f"有人回应了你的树洞：{summary}", "treehole", diary_id)


def notify_treehole_reply_like(reply_id: int, actor_id: int):
    """树洞回复被点赞通知"""
    from database import get_treehole_reply_by_id as db_get_reply
    reply = db_get_reply(reply_id)
    if not reply:
        return
    recipient_id = reply.get("user_id")
    if not recipient_id or recipient_id == actor_id:
        return
    if not _should_notify(recipient_id, actor_id):
        return
    # 不重复通知
    if db_notification_exists(recipient_id, actor_id, "treehole_reply_like", reply_id):
        return
    summary = (reply.get("content") or "").strip()
    if len(summary) > 20:
        summary = summary[:20] + "…"
    nid = db_create_notification(
        recipient_id=recipient_id,
        actor_id=None,
        type="treehole_reply_like",
        entity_type="treehole_reply",
        entity_id=reply_id,
        title="你的回应被点赞了",
        content=f"有人觉得你的回应「{summary}」很温暖",
    )
    if nid:
        _ws_push_notification(recipient_id, nid, "treehole_reply_like", "你的回应被点赞了",
                              f"有人觉得你的回应「{summary}」很温暖", "treehole_reply", reply_id)


# ============ 打招呼通知 ============

def notify_greet_request(requester_id: int, receiver_id: int, request_id: int):
    """有人向我打招呼"""
    if requester_id == receiver_id:
        return
    if not _should_notify(receiver_id, requester_id):
        return
    nickname = _get_nickname(requester_id)
    nid = db_create_notification(
        recipient_id=receiver_id,
        actor_id=requester_id,
        type="greet_request",
        entity_type="greet",
        entity_id=request_id,
        title="有人想认识你",
        content=f"{nickname} 向你打了个招呼",
    )
    if nid:
        _ws_push_notification(receiver_id, nid, "greet_request", "有人想认识你",
                              f"{nickname} 向你打了个招呼", "greet", request_id, nickname)


def notify_greet_accepted(receiver_id: int, requester_id: int, request_id: int):
    """打招呼被同意"""
    if receiver_id == requester_id:
        return
    if not _should_notify(requester_id, receiver_id):
        return
    nickname = _get_nickname(receiver_id)
    nid = db_create_notification(
        recipient_id=requester_id,
        actor_id=receiver_id,
        type="greet_accepted",
        entity_type="greet",
        entity_id=request_id,
        title="打招呼已通过",
        content=f"{nickname} 同意了你的打招呼",
    )
    if nid:
        _ws_push_notification(requester_id, nid, "greet_accepted", "打招呼已通过",
                              f"{nickname} 同意了你的打招呼", "greet", request_id, nickname)


def notify_greet_rejected(receiver_id: int, requester_id: int, request_id: int):
    """打招呼被拒绝"""
    if receiver_id == requester_id:
        return
    if not _should_notify(requester_id, receiver_id):
        return
    nickname = _get_nickname(receiver_id)
    nid = db_create_notification(
        recipient_id=requester_id,
        actor_id=receiver_id,
        type="greet_rejected",
        entity_type="greet",
        entity_id=request_id,
        title="打招呼未通过",
        content=f"{nickname} 暂时没有接受你的打招呼",
    )
    if nid:
        _ws_push_notification(requester_id, nid, "greet_rejected", "打招呼未通过",
                              f"{nickname} 暂时没有接受你的打招呼", "greet", request_id, nickname)


# ============ 私信通知 ============

def notify_private_message(sender_id: int, receiver_id: int, conversation_id: int, message_content: str):
    """收到新私信"""
    if sender_id == receiver_id:
        return
    if not _should_notify(receiver_id, sender_id):
        return
    nickname = _get_nickname(sender_id)
    summary = (message_content or "").strip()
    if len(summary) > 30:
        summary = summary[:30] + "…"
    db_create_notification(
        recipient_id=receiver_id,
        actor_id=sender_id,
        type="private_message",
        entity_type="conversation",
        entity_id=conversation_id,
        title="你收到一条新消息",
        content=f"{nickname}：{summary}",
    )


# ============ 通知读取 ============

def get_my_notifications(user_id: int, page: int = 1, page_size: int = 20, unread_only: bool = False) -> dict:
    return db_list_notifications(user_id, page, page_size, unread_only)


def get_unread_count(user_id: int) -> dict:
    return {"unread_count": db_count_unread(user_id)}


def mark_read(user_id: int, notification_id: int) -> dict:
    ok = db_mark_read(user_id, notification_id)
    if not ok:
        raise HTTPException(status_code=404, detail="通知不存在或无权操作")
    return {"ok": True}


def mark_all_read(user_id: int) -> dict:
    db_mark_all_read(user_id)
    return {"ok": True}


def delete(user_id: int, notification_id: int) -> dict:
    ok = db_delete_notification(user_id, notification_id)
    if not ok:
        raise HTTPException(status_code=404, detail="通知不存在或无权操作")
    return {"ok": True}
