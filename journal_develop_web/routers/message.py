"""私信系统路由"""

from fastapi import APIRouter, Query, Depends

from models.schemas import StartConversationRequest, SendMessageRequest
from services.auth_service import require_user
from services.message_service import (
    get_or_create_chat,
    list_conversations,
    send_message,
    list_messages,
    mark_read,
    get_unread_count,
)

router = APIRouter(prefix="/api/messages", tags=["私信"])


@router.get("/conversations")
async def api_list_conversations(user=Depends(require_user)):
    """获取我的会话列表"""
    return list_conversations(user["id"])


@router.post("/conversations")
async def api_create_conversation(body: StartConversationRequest, user=Depends(require_user)):
    """创建或获取会话"""
    return get_or_create_chat(user["id"], body.user_id)


@router.get("/conversations/{conversation_id}/messages")
async def api_list_messages(
    conversation_id: int,
    page: int = Query(1, ge=1),
    page_size: int = Query(30, ge=1, le=50),
    user=Depends(require_user),
):
    """获取会话消息列表"""
    return list_messages(user["id"], conversation_id, page, page_size)


@router.post("/conversations/{conversation_id}/messages")
async def api_send_message(conversation_id: int, body: SendMessageRequest, user=Depends(require_user)):
    """发送消息"""
    return send_message(user["id"], conversation_id, body.content, body.image_url or '')


@router.post("/conversations/{conversation_id}/read")
async def api_mark_read(conversation_id: int, user=Depends(require_user)):
    """标记会话已读"""
    return mark_read(user["id"], conversation_id)


@router.get("/unread-count")
async def api_unread_count(user=Depends(require_user)):
    """获取私信未读数"""
    return get_unread_count(user["id"])
