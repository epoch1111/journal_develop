"""关注系统路由"""

from fastapi import APIRouter, Depends, Query

from services.auth_service import require_user, get_optional_user
from services.follow_service import (
    follow,
    unfollow,
    get_follow_status,
    list_my_following,
    list_my_followers,
    get_following_feed,
)

router = APIRouter(tags=["关注系统"])


@router.post("/api/users/{user_id}/follow")
async def api_follow(user_id: int, user=Depends(require_user)):
    """关注用户"""
    return follow(user["id"], user_id)


@router.delete("/api/users/{user_id}/follow")
async def api_unfollow(user_id: int, user=Depends(require_user)):
    """取消关注"""
    return unfollow(user["id"], user_id)


@router.get("/api/users/{user_id}/follow-status")
async def api_follow_status(user_id: int, current_user=Depends(get_optional_user)):
    """获取关注状态（可选登录）"""
    uid = current_user["id"] if current_user else None
    return get_follow_status(uid, user_id)


@router.get("/api/me/following")
async def api_my_following(user=Depends(require_user)):
    """我的关注列表"""
    return list_my_following(user["id"])


@router.get("/api/me/followers")
async def api_my_followers(user=Depends(require_user)):
    """我的粉丝列表"""
    return list_my_followers(user["id"])


@router.get("/api/me/following-feed")
async def api_following_feed(
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=50),
    user=Depends(require_user),
):
    """我关注用户的公开日记动态"""
    return get_following_feed(user["id"], page, page_size)
