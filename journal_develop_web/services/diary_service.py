"""日记业务逻辑层"""

from datetime import date, datetime, timedelta

from fastapi import HTTPException

from database import save_diary_to_db, get_all_diaries_from_db, get_diary_stats, get_random_public_diary, increment_hug_count, decrement_hug_count, get_diaries_by_date, get_diary_by_id, update_diary as db_update_diary, delete_diary as db_delete_diary, set_diary_images, get_diary_images, get_multi_diary_images, get_treehole_by_id, save_treehole_reply, list_treehole_replies, save_treehole_hug, remove_treehole_hug, get_treehole_reply_by_id, save_treehole_reply_like, remove_treehole_reply_like, count_treehole_reply_likes, get_treehole_reply_full, get_or_create_treehole_identity
from config import MOOD_COLORS

MAX_CONTENT_LENGTH = 10000


def _mask_capsule(diary: dict) -> dict:
    """如果日记是未到期时光胶囊，屏蔽 content 并附加 locked/days_left"""
    unlock_date = (diary.get("unlock_date") or "").strip()
    if unlock_date:
        try:
            target = datetime.strptime(unlock_date, "%Y-%m-%d").date()
        except ValueError:
            diary["locked"] = False
            diary["days_left"] = 0
            return diary
        today = date.today()
        days_left = (target - today).days
        if days_left > 0:
            diary["content"] = ""
            diary["locked"] = True
            diary["days_left"] = days_left
            return diary
        diary["locked"] = False
        diary["days_left"] = 0
    else:
        diary["locked"] = False
        diary["days_left"] = 0
    return diary


def _attach_mood_color(diary: dict) -> dict:
    mood = diary.get("mood", "")
    diary["mood_color"] = MOOD_COLORS.get(mood, MOOD_COLORS["😊"])
    return diary


def create_diary(mood: str, content: str, ai_summary: str, ai_message: str, tags: str, is_public: bool = False, image_url: str = "", unlock_date: str = "", user_id: int = 1, image_urls: list[str] | None = None, content_type: str = "diary") -> dict:
    """创建日记，含后端安全校验。content_type: diary/treehole/capsule"""

    if len(content) > MAX_CONTENT_LENGTH:
        raise HTTPException(
            status_code=400,
            detail=f"日记内容过长，最多 {MAX_CONTENT_LENGTH} 字，当前 {len(content)} 字",
        )

    if unlock_date:
        try:
            target = datetime.strptime(unlock_date, "%Y-%m-%d").date()
        except ValueError:
            raise HTTPException(status_code=400, detail="胶囊日期格式错误，应为 YYYY-MM-DD")

        tomorrow = date.today() + timedelta(days=1)
        if target < tomorrow:
            raise HTTPException(status_code=400, detail="时光胶囊的拆封日期必须是将来的某一天（至少是明天）")

    # 如果传了 image_urls，取第一张作为 image_url
    urls = image_urls or []
    primary_url = image_url or (urls[0] if urls else "")
    row_id = save_diary_to_db(mood, content, ai_summary, ai_message, tags, is_public, primary_url, unlock_date, user_id=user_id, content_type=content_type)
    if urls:
        set_diary_images(row_id, urls)
    elif primary_url:
        set_diary_images(row_id, [primary_url])
    return {"ok": True, "id": row_id}


def _check_ownership(diary_id: int, user_id: int) -> dict:
    """检查日记存在性和所有权，返回日记 dict，否则 raise 404/403"""
    diary = get_diary_by_id(diary_id)
    if not diary:
        raise HTTPException(status_code=404, detail="日记不存在")
    if diary.get("user_id", 1) != user_id:
        raise HTTPException(status_code=403, detail="无权操作此日记")
    return diary


def list_diaries(date: str = None, user_id: int = None) -> list[dict]:
    """获取日记列表，对未到期胶囊屏蔽内容"""
    diaries = get_all_diaries_from_db(date, user_id)
    # 批量附加图片
    if diaries:
        ids = [d["id"] for d in diaries]
        img_map = get_multi_diary_images(ids)
        for d in diaries:
            images = img_map.get(d["id"], [])
            d["image_urls"] = [img["image_url"] for img in images]
            _attach_mood_color(d)
            _mask_capsule(d)
    return diaries


def get_diary_detail(diary_id: int, user_id: int = None) -> dict:
    """获取单篇日记详情，不存在返回 404"""
    diary = get_diary_by_id(diary_id)
    if not diary:
        raise HTTPException(status_code=404, detail="日记不存在")
    if user_id is not None and diary.get("user_id", 1) != user_id:
        raise HTTPException(status_code=403, detail="无权查看此日记")
    _attach_mood_color(diary)
    _mask_capsule(diary)
    images = get_diary_images(diary_id)
    diary["image_urls"] = [img["image_url"] for img in images]
    return diary


def update_diary(diary_id: int, updates: dict, user_id: int = None) -> dict:
    """编辑日记，含后端校验和所有权检查"""
    if user_id is not None:
        _check_ownership(diary_id, user_id)

    content = updates.get("content")
    if content is not None and len(content) > MAX_CONTENT_LENGTH:
        raise HTTPException(
            status_code=400,
            detail=f"日记内容过长，最多 {MAX_CONTENT_LENGTH} 字，当前 {len(content)} 字",
        )

    unlock_date = updates.get("unlock_date")
    if unlock_date is not None and unlock_date.strip():
        try:
            datetime.strptime(unlock_date, "%Y-%m-%d")
        except ValueError:
            raise HTTPException(status_code=400, detail="胶囊日期格式错误，应为 YYYY-MM-DD")

    # 处理多图：从 updates 中提取 image_urls，单独同步到 diary_images 表
    image_urls = updates.pop("image_urls", None)
    if image_urls is not None:
        urls = [u for u in image_urls if u and str(u).strip()]
        updates["image_url"] = urls[0] if urls else ""
        set_diary_images(diary_id, urls)

    ok = db_update_diary(diary_id, updates)
    if not ok:
        raise HTTPException(status_code=500, detail="更新失败")
    return {"ok": True, "id": diary_id}


def delete_diary(diary_id: int, user_id: int = None) -> dict:
    """删除日记，含所有权检查"""
    if user_id is not None:
        _check_ownership(diary_id, user_id)
    db_delete_diary(diary_id)
    return {"ok": True}


def get_stats(user_id: int = None) -> dict:
    """获取完整统计数据：心情分布 + 日历数据"""
    stats = get_diary_stats(user_id)
    for item in stats["mood_distribution"]:
        mood = item["mood"]
        item["label"] = MOOD_COLORS.get(mood, {}).get("label", "")
        item["border"] = MOOD_COLORS.get(mood, {}).get("border", "#ccc")
    return stats


def get_mood_stats(user_id: int = None) -> dict:
    """获取心情统计（简洁版，用于顶部速览条）"""
    diaries = get_all_diaries_from_db(user_id=user_id)
    distribution = {}
    recent = []
    for d in diaries[-14:]:
        mood = d.get("mood", "")
        distribution[mood] = distribution.get(mood, 0) + 1
        recent.append({
            "date": d.get("created_at", "")[:10],
            "mood": mood,
            "label": MOOD_COLORS.get(mood, {}).get("label", ""),
        })
    return {
        "total": len(diaries),
        "distribution": distribution,
        "recent_moods": recent[::-1],
    }


def get_treehole_diary() -> dict | None:
    """获取一条随机树洞日记（匿名，不返回 user_id）"""
    diary = get_random_public_diary()
    if diary:
        diary.pop("user_id", None)
    return diary


def get_treehole_detail(diary_id: int, viewer_id: int | None = None) -> dict:
    """获取树洞日记详情（匿名），包含标签和回复列表"""
    diary = get_treehole_by_id(diary_id)
    if not diary:
        raise HTTPException(status_code=404, detail="树洞日记不存在")
    diary["replies"] = list_treehole_replies(diary_id, viewer_id)
    return diary


def hug_diary(diary_id: int, user_id: int) -> dict:
    """给树洞日记抱抱（每个账号限一次），返回新计数"""
    diary = get_treehole_by_id(diary_id)
    if not diary:
        raise HTTPException(status_code=404, detail="树洞日记不存在")
    success, already = save_treehole_hug(diary_id, user_id)
    if already:
        new_count = diary["hug_count"]
        return {"ok": True, "hug_count": new_count, "already_hugged": True}
    new_count = increment_hug_count(diary_id)
    from services.notification_service import notify_treehole_hug
    notify_treehole_hug(diary_id, user_id)
    return {"ok": True, "hug_count": new_count, "already_hugged": False}


def unhug_diary(diary_id: int, user_id: int) -> dict:
    """取消树洞抱抱，返回新计数"""
    diary = get_treehole_by_id(diary_id)
    if not diary:
        raise HTTPException(status_code=404, detail="树洞日记不存在")
    removed = remove_treehole_hug(diary_id, user_id)
    if not removed:
        return {"ok": True, "hug_count": diary["hug_count"], "was_hugged": False}
    new_count = decrement_hug_count(diary_id)
    return {"ok": True, "hug_count": new_count, "was_hugged": True}


def like_treehole_reply(reply_id: int, user_id: int) -> dict:
    """点赞树洞回复（toggle）"""
    reply = get_treehole_reply_by_id(reply_id)
    if not reply:
        raise HTTPException(status_code=404, detail="回复不存在")
    success, already = save_treehole_reply_like(reply_id, user_id)
    if not already:
        from services.notification_service import notify_treehole_reply_like
        notify_treehole_reply_like(reply_id, user_id)
    like_count = count_treehole_reply_likes(reply_id)
    return {"ok": True, "like_count": like_count, "already_liked": already}


def unlike_treehole_reply(reply_id: int, user_id: int) -> dict:
    """取消点赞树洞回复"""
    reply = get_treehole_reply_by_id(reply_id)
    if not reply:
        raise HTTPException(status_code=404, detail="回复不存在")
    removed = remove_treehole_reply_like(reply_id, user_id)
    like_count = count_treehole_reply_likes(reply_id)
    return {"ok": True, "like_count": like_count, "was_liked": removed}


def reply_treehole(diary_id: int, content: str, user_id: int | None = None,
                   client_id: str = "", parent_reply_id: int | None = None,
                   reply_to_identity_id: int | None = None) -> dict:
    """回复树洞漂流瓶（匿名，支持线程回复）"""
    diary = get_treehole_by_id(diary_id)
    if not diary:
        raise HTTPException(status_code=404, detail="树洞日记不存在")
    if not content or not content.strip():
        raise HTTPException(status_code=400, detail="回复内容不能为空")
    content = content.strip()
    if len(content) > 500:
        raise HTTPException(status_code=400, detail=f"回复内容过长，最多 500 字")

    # 获取或创建匿名身份
    identity = get_or_create_treehole_identity(diary_id, user_id, client_id)

    # 验证 parent_reply_id（如果有）
    root_reply_id = None
    if parent_reply_id:
        parent_reply = get_treehole_reply_full(parent_reply_id)
        if not parent_reply:
            raise HTTPException(status_code=400, detail="回复的评论不存在或已被删除")
        if parent_reply.get("diary_id") != diary_id:
            raise HTTPException(status_code=400, detail="该回复不属于此树洞")
        # 计算 root_reply_id
        if parent_reply.get("parent_reply_id") is None:
            root_reply_id = parent_reply_id
        else:
            root_reply_id = parent_reply.get("root_reply_id", parent_reply.get("parent_reply_id"))

    # 验证 reply_to_identity_id（如果有）
    if reply_to_identity_id:
        from database import get_treehole_identity_by_id
        target_identity = get_treehole_identity_by_id(reply_to_identity_id)
        if not target_identity:
            raise HTTPException(status_code=400, detail="被回复的匿名身份不存在")
        # 检查 identity 是否属于当前树洞
        target = get_treehole_identity_by_id(reply_to_identity_id)
        if not target or target.get("treehole_id") != diary_id:
            raise HTTPException(status_code=400, detail="该匿名身份不属于当前树洞")

    reply_id = save_treehole_reply(diary_id, content, user_id,
                                    identity_id=identity["id"],
                                    parent_reply_id=parent_reply_id,
                                    root_reply_id=root_reply_id,
                                    reply_to_identity_id=reply_to_identity_id)

    from services.notification_service import notify_treehole_reply
    notify_treehole_reply(diary_id, content, user_id)

    return {
        "ok": True,
        "reply": {
            "id": reply_id,
            "content": content,
            "created_at": "",  # 由列表接口返回完整时间
            "identity_id": identity["id"],
            "anon_name": identity["anon_name"],
            "anon_avatar": identity["anon_avatar"],
            "parent_reply_id": parent_reply_id,
            "root_reply_id": root_reply_id,
            "reply_to_identity_id": reply_to_identity_id,
            "reply_to_anon_name": "",
        },
    }


def list_diaries_by_date(target_date: str, user_id: int = None) -> list[dict]:
    """按日期查询日记，对未到期胶囊屏蔽内容"""
    diaries = get_diaries_by_date(target_date, user_id)
    if diaries:
        ids = [d["id"] for d in diaries]
        img_map = get_multi_diary_images(ids)
        for d in diaries:
            images = img_map.get(d["id"], [])
            d["image_urls"] = [img["image_url"] for img in images]
            _attach_mood_color(d)
            _mask_capsule(d)
    return diaries
