"""日记 CRUD 路由"""

from fastapi import APIRouter, HTTPException, Depends, Body
from models.schemas import TreeHoleDiary, HugResponse, DiaryUpdateRequest, TreeHoleReplyRequest
from services.diary_service import create_diary, list_diaries, get_mood_stats, get_stats, get_treehole_diary, hug_diary, unhug_diary, reply_treehole, list_diaries_by_date, get_diary_detail, update_diary, delete_diary, get_treehole_detail, like_treehole_reply, unlike_treehole_reply
from services.auth_service import require_user, get_optional_user

router = APIRouter(prefix="/api", tags=["日记管理"])


@router.post("/save")
async def save(body: dict = Body(...), user=Depends(require_user)):
    """保存日记。content_type: diary(默认) / capsule(胶囊)"""
    is_capsule = bool((body.get("unlock_date") or "").strip())
    result = create_diary(
        mood=body.get("mood", "😊"),
        content=body.get("content", ""),
        ai_summary=body.get("ai_summary", ""),
        ai_message=body.get("ai_message", ""),
        tags=body.get("tags", ""),
        is_public=body.get("is_public", False),
        image_url=body.get("image_url", ""),
        unlock_date=body.get("unlock_date", ""),
        user_id=user["id"],
        image_urls=body.get("image_urls"),
        content_type="capsule" if is_capsule else "diary",
    )
    return {"ok": True, "id": result["id"]}


@router.get("/diaries")
async def diaries(date: str = None, user=Depends(require_user)):
    """获取日记列表，可选按日期过滤 (?date=YYYY-MM-DD)"""
    return list_diaries(date, user["id"])


@router.get("/diaries/date/{date}")
async def diaries_by_date(date: str, user=Depends(require_user)):
    """按日期查询日记（日历下钻）"""
    return list_diaries_by_date(date, user["id"])


@router.get("/diaries/{diary_id}")
async def diary_detail(diary_id: int, user=Depends(require_user)):
    """获取单篇日记详情"""
    return get_diary_detail(diary_id, user["id"])


@router.put("/diaries/{diary_id}")
async def diary_update(diary_id: int, body: DiaryUpdateRequest, user=Depends(require_user)):
    """编辑日记"""
    updates = body.model_dump(exclude_none=True)
    return update_diary(diary_id, updates, user["id"])


@router.delete("/diaries/{diary_id}")
async def diary_delete(diary_id: int, user=Depends(require_user)):
    """删除日记"""
    return delete_diary(diary_id, user["id"])


@router.get("/mood-stats")
async def mood_stats(user=Depends(require_user)):
    """获取心情统计数据"""
    return get_mood_stats(user["id"])


@router.get("/stats")
async def stats(user=Depends(require_user)):
    """获取完整统计：心情分布 + 日历数据"""
    return get_stats(user["id"])


# ===== 树洞接口 =====

@router.post("/treehole")
async def treehole_create(body: dict = Body(...), user=Depends(require_user)):
    """匿名投递树洞漂流瓶"""
    result = create_diary(
        mood=body.get("mood", "😊"),
        content=body.get("content", ""),
        ai_summary="",
        ai_message="",
        tags=body.get("tags", ""),
        is_public=False,
        image_url=body.get("image_url", ""),
        unlock_date="",
        user_id=user["id"],
        image_urls=body.get("image_urls"),
        content_type="treehole",
    )
    return {"ok": True, "id": result["id"]}


@router.get("/treehole/random", response_model=TreeHoleDiary)
async def treehole_random():
    """随机获取一条树洞日记（匿名）"""
    diary = get_treehole_diary()
    if not diary:
        raise HTTPException(status_code=404, detail="暂时还没有人投递漂流瓶哦～")
    return TreeHoleDiary(**diary)


# ---- 树洞回复点赞（必须在 /{diary_id} 之前，避免路由冲突） ----

@router.post("/treehole/replies/{reply_id}/like")
async def treehole_reply_like(reply_id: int, user=Depends(require_user)):
    """点赞树洞回复（toggle 开）"""
    return like_treehole_reply(reply_id, user["id"])


@router.delete("/treehole/replies/{reply_id}/like")
async def treehole_reply_unlike(reply_id: int, user=Depends(require_user)):
    """取消点赞树洞回复（toggle 关）"""
    return unlike_treehole_reply(reply_id, user["id"])


# ---- 树洞日记路由 ----

@router.get("/treehole/{diary_id}")
async def treehole_detail(diary_id: int, user=Depends(get_optional_user)):
    """获取树洞日记详情（匿名，不返回作者信息）"""
    viewer_id = user["id"] if user else None
    return get_treehole_detail(diary_id, viewer_id)


@router.post("/treehole/{diary_id}/hug", response_model=HugResponse)
async def treehole_hug(diary_id: int, user=Depends(require_user)):
    """给一篇树洞日记抱抱（toggle 开）"""
    result = hug_diary(diary_id, user["id"])
    return HugResponse(**result)


@router.delete("/treehole/{diary_id}/hug", response_model=HugResponse)
async def treehole_unhug(diary_id: int, user=Depends(require_user)):
    """取消树洞抱抱（toggle 关）"""
    result = unhug_diary(diary_id, user["id"])
    return HugResponse(**result)


@router.post("/treehole/{diary_id}/reply")
async def treehole_reply(diary_id: int, body: TreeHoleReplyRequest, user=Depends(require_user)):
    """回复一篇树洞日记（需登录，对外匿名）"""
    return reply_treehole(diary_id, body.content, user["id"], body.client_id, body.parent_reply_id, body.reply_to_identity_id)
