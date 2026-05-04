"""公开日记广场路由"""

from fastapi import APIRouter, Query, Body, Depends

from models.schemas import PublicDiaryLikeRequest, PublicDiaryCommentRequest
from services.public_diary_service import (
    list_public_diaries,
    get_public_diary_detail,
    like_diary,
    unlike_diary,
    add_comment,
    list_comments,
    like_comment,
    unlike_comment,
)
from services.auth_service import get_optional_user, require_user

router = APIRouter(prefix="/api/public", tags=["公开广场"])


@router.get("/diaries")
async def public_diaries(
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=50),
    mood: str = Query(None),
    tag: str = Query(None),
    keyword: str = Query(None),
    client_id: str = Query(None),
    current_user=Depends(get_optional_user),
):
    """公开日记列表（分页+筛选）"""
    viewer_id = current_user["id"] if current_user else None
    return list_public_diaries(
        page=page, page_size=page_size,
        mood=mood, tag=tag, keyword=keyword,
        client_id=client_id,
        viewer_id=viewer_id,
    )


@router.get("/diaries/{diary_id}")
async def public_diary_detail(diary_id: int, client_id: str = Query(None), current_user=Depends(get_optional_user)):
    """公开日记详情（含评论）"""
    viewer_id = current_user["id"] if current_user else None
    return get_public_diary_detail(diary_id, client_id, viewer_id)


@router.post("/diaries/{diary_id}/like")
async def public_diary_like(diary_id: int, body: PublicDiaryLikeRequest, current_user=Depends(get_optional_user)):
    """点亮公开日记"""
    actor_id = current_user["id"] if current_user else None
    return like_diary(diary_id, body.client_id, actor_id)


@router.delete("/diaries/{diary_id}/like")
async def public_diary_unlike(diary_id: int, client_id: str = Query(...)):
    """取消点亮"""
    return unlike_diary(diary_id, client_id)


@router.post("/diaries/{diary_id}/comments")
async def public_diary_comment(diary_id: int, body: PublicDiaryCommentRequest, current_user=Depends(get_optional_user)):
    """发表评论（支持一级评论和回复评论）"""
    actor_id = current_user["id"] if current_user else None
    return add_comment(diary_id, body.client_id, body.content, actor_id,
                       body.parent_comment_id, body.reply_to_user_id)


@router.get("/diaries/{diary_id}/comments")
async def public_diary_comments(diary_id: int, limit: int = Query(20, ge=1, le=50), current_user=Depends(get_optional_user)):
    """获取评论列表"""
    viewer_id = current_user["id"] if current_user else None
    return list_comments(diary_id, limit, viewer_id)


@router.post("/diaries/comments/{comment_id}/like")
async def public_diary_comment_like(comment_id: int, user=Depends(require_user)):
    """点赞评论"""
    return like_comment(comment_id, user["id"])


@router.delete("/diaries/comments/{comment_id}/like")
async def public_diary_comment_unlike(comment_id: int, user=Depends(require_user)):
    """取消点赞评论"""
    return unlike_comment(comment_id, user["id"])
