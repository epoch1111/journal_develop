"""通知中心路由"""

from fastapi import APIRouter, Depends, Query

from services.auth_service import require_user
from services.notification_service import (
    get_my_notifications,
    get_unread_count,
    mark_read,
    mark_all_read,
    delete,
)

router = APIRouter(prefix="/api/notifications", tags=["通知中心"])


@router.get("")
async def api_list(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    unread_only: bool = Query(False),
    user=Depends(require_user),
):
    """获取我的通知列表"""
    return get_my_notifications(user["id"], page, page_size, unread_only)


@router.get("/unread-count")
async def api_unread_count(user=Depends(require_user)):
    """获取未读通知数量"""
    return get_unread_count(user["id"])


@router.post("/{notification_id}/read")
async def api_mark_read(notification_id: int, user=Depends(require_user)):
    """标记单条通知已读"""
    return mark_read(user["id"], notification_id)


@router.post("/read-all")
async def api_mark_all_read(user=Depends(require_user)):
    """标记所有通知已读"""
    return mark_all_read(user["id"])


@router.delete("/{notification_id}")
async def api_delete(notification_id: int, user=Depends(require_user)):
    """删除通知"""
    return delete(user["id"], notification_id)
