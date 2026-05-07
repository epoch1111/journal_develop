"""公开日记广场 - 业务逻辑层"""

from fastapi import HTTPException

from config import MOOD_COLORS
from database import (
    list_public_diaries as db_list_public,
    count_public_diaries as db_count_public,
    get_public_diary_by_id as db_get_public,
    has_liked_public_diary,
    like_public_diary as db_like,
    unlike_public_diary as db_unlike,
    count_public_diary_likes,
    add_public_diary_comment as db_add_comment,
    list_public_diary_comments as db_list_comments,
    count_public_diary_comments,
    get_user_by_id,
    get_diary_images,
    get_multi_diary_images,
    save_comment_like,
    remove_comment_like,
    count_comment_likes,
    get_comment_by_id as db_get_comment,
    get_block_direction,
)
from services.safety_service import check_block_or_raise

MAX_COMMENT_LENGTH = 500


def _validate_comment_content(content: str, allow_empty: bool = False):
    content = (content or "").strip()
    if not content and not allow_empty:
        raise HTTPException(status_code=400, detail="评论内容不能为空")
    if len(content) > MAX_COMMENT_LENGTH:
        raise HTTPException(
            status_code=400,
            detail=f"评论内容过长，最多 {MAX_COMMENT_LENGTH} 字，当前 {len(content)} 字",
        )
    return content


def _attach_mood_color(diary: dict) -> dict:
    mood = diary.get("mood", "")
    diary["mood_color"] = MOOD_COLORS.get(mood, MOOD_COLORS["😊"])
    return diary


def _format_public_diary(diary: dict, client_id: str = None, images: list[str] | None = None) -> dict:
    """格式化为广场返回格式"""
    did = diary["id"]
    liked = has_liked_public_diary(did, client_id) if client_id else False
    like_count = count_public_diary_likes(did)
    comment_count = count_public_diary_comments(did)

    # 从 users 表获取真实作者信息
    uid = diary.get("user_id", 1)
    user = get_user_by_id(uid)
    author_name = user["nickname"] if user else "小兔"
    author_avatar = user["avatar"] if user else "🐰"

    if images is None:
        images = [img["image_url"] for img in get_diary_images(did)]

    return {
        "id": did,
        "created_at": diary.get("created_at", ""),
        "mood": diary.get("mood", ""),
        "mood_color": diary.get("mood_color", {}),
        "content": diary.get("content", ""),
        "ai_summary": diary.get("ai_summary", ""),
        "ai_message": diary.get("ai_message", ""),
        "tags": diary.get("tags", ""),
        "image_url": diary.get("image_url", ""),
        "image_urls": images,
        "user_id": uid,
        "author_name": author_name,
        "author_avatar": author_avatar,
        "anonymous": False,
        "like_count": like_count,
        "liked": liked,
        "comment_count": comment_count,
    }


# ============ 公开日记列表 ============

def list_public_diaries(page: int = 1, page_size: int = 10, mood: str = None,
                        tag: str = None, keyword: str = None, client_id: str = None,
                        viewer_id: int = None) -> dict:
    page = max(1, page)
    page_size = min(max(1, page_size), 50)

    # 获取拉黑用户 id 列表用于过滤
    blocked_ids = set()
    if viewer_id:
        from database import get_blocked_user_ids
        blocked_ids = set(get_blocked_user_ids(viewer_id))

    diaries = db_list_public(page=page, page_size=page_size * 2, mood=mood, tag=tag, keyword=keyword)

    # 过滤掉拉黑用户的日记，然后分页
    diaries = [d for d in diaries if d.get("user_id", 0) not in blocked_ids]
    total = len(diaries)  # 近似 total（经过过滤）
    start = (page - 1) * page_size
    diaries = diaries[start:start + page_size]

    # 批量获取图片
    img_map = {}
    if diaries:
        ids = [d["id"] for d in diaries]
        img_map = get_multi_diary_images(ids)

    items = []
    for d in diaries:
        _attach_mood_color(d)
        images = [img["image_url"] for img in img_map.get(d["id"], [])]
        items.append(_format_public_diary(d, client_id, images))

    return {
        "items": items,
        "page": page,
        "page_size": page_size,
        "total": total,
        "has_more": start + page_size < total if not blocked_ids else True,
    }


# ============ 公开日记详情 ============

def get_public_diary_detail(diary_id: int, client_id: str = None, viewer_id: int | None = None) -> dict:
    diary = db_get_public(diary_id)
    if not diary:
        raise HTTPException(status_code=404, detail="日记不存在或不是公开日记")

    owner = diary.get("user_id")
    block_reason = None
    if viewer_id and owner:
        direction = get_block_direction(viewer_id, owner)
        if direction == 'blocked':
            block_reason = "你已拉黑该用户"
        elif direction == 'blocked_by':
            block_reason = "该用户已拉黑你"

    _attach_mood_color(diary)
    images = [img["image_url"] for img in get_diary_images(diary_id)]
    result = _format_public_diary(diary, client_id, images)
    # 被拉黑时内容不可见
    if block_reason:
        result["content"] = f"[{block_reason}，无法查看内容]"
        result["ai_summary"] = ""
        result["ai_message"] = ""
        result["image_urls"] = []
        result["_blocked"] = True
        result["_block_reason"] = block_reason
    result["comments"] = _list_comments_masked(diary_id, viewer_id)
    return result


def _list_comments_masked(diary_id: int, viewer_id: int | None) -> list[dict]:
    """评论列表，将被双向拉黑的评论内容屏蔽"""
    comments = db_list_comments(diary_id, viewer_id=viewer_id)
    if not viewer_id:
        return comments
    blocked_ids = set()
    from database import get_blocked_user_ids
    blocked_ids = set(get_blocked_user_ids(viewer_id))
    for c in comments:
        if c.get("user_id") in blocked_ids:
            c["content"] = "[内容不可见]"
            c["image_urls"] = []
        # 二级回复也检查
        if c.get("replies"):
            for r in c["replies"]:
                if r.get("user_id") in blocked_ids:
                    r["content"] = "[内容不可见]"
                    r["image_urls"] = []
    return comments


# ============ 点亮 ============

def like_diary(diary_id: int, client_id: str, actor_id: int | None = None) -> dict:
    if not db_get_public(diary_id):
        raise HTTPException(status_code=404, detail="日记不存在或不是公开日记")
    if actor_id:
        from services.safety_service import check_block_or_raise
        from database import get_diary_owner_id
        owner = get_diary_owner_id(diary_id)
        if owner:
            check_block_or_raise(actor_id, owner)
    success, already = db_like(diary_id, client_id)
    count = count_public_diary_likes(diary_id)
    if success and not already and actor_id:
        from services.notification_service import notify_public_diary_like
        notify_public_diary_like(actor_id, diary_id)
    return {"ok": True, "liked": True, "already_liked": already, "like_count": count}


def unlike_diary(diary_id: int, client_id: str) -> dict:
    if not db_get_public(diary_id):
        raise HTTPException(status_code=404, detail="日记不存在或不是公开日记")
    db_unlike(diary_id, client_id)
    count = count_public_diary_likes(diary_id)
    return {"ok": True, "liked": False, "like_count": count}


# ============ 评论 ============

def add_comment(diary_id: int, client_id: str, content: str, actor_id: int | None = None,
                parent_comment_id: int | None = None, reply_to_user_id: int | None = None,
                image_url: str = '', image_urls=None) -> dict:
    # 日记必须存在且为公开
    diary = db_get_public(diary_id)
    if not diary:
        raise HTTPException(status_code=404, detail="日记不存在或不是公开日记")
    if actor_id:
        from services.safety_service import check_block_or_raise
        from database import get_diary_owner_id
        owner = get_diary_owner_id(diary_id)
        if owner:
            check_block_or_raise(actor_id, owner)
        # 回复他人时也要检查被回复人
        if reply_to_user_id:
            check_block_or_raise(actor_id, reply_to_user_id)
    content = _validate_comment_content(content, allow_empty=bool(image_url) or bool(image_urls))

    # 验证 parent_comment_id
    root_comment_id = None
    if parent_comment_id:
        from database import get_comment_by_id as db_get_comment
        parent_comment = db_get_comment(parent_comment_id)
        if not parent_comment:
            raise HTTPException(status_code=400, detail="回复的评论不存在或已被删除")
        if parent_comment.get("diary_id") != diary_id:
            raise HTTPException(status_code=400, detail="该评论不属于此日记")
        # root_comment_id: 如果父评论是一级评论, root = 父评论 id; 如果父评论是二级回复, root = 父评论的 root_comment_id
        if parent_comment.get("parent_comment_id") is None:
            root_comment_id = parent_comment_id
        else:
            root_comment_id = parent_comment.get("root_comment_id", parent_comment.get("parent_comment_id"))

    # 验证 reply_to_user_id
    if reply_to_user_id:
        from database import get_user_by_id as db_get_user
        target_user = db_get_user(reply_to_user_id)
        if not target_user:
            raise HTTPException(status_code=400, detail="被回复的用户不存在")

    cid = db_add_comment(diary_id, client_id, content, actor_id,
                         parent_comment_id, reply_to_user_id, root_comment_id, image_url, image_urls)

    # 通知逻辑
    if actor_id:
        diary_owner_id = diary.get("user_id", 0)
        from services.notification_service import notify_public_diary_comment, notify_comment_reply
        if parent_comment_id and reply_to_user_id:
            # 这是一条回复：优先通知被回复的人
            if reply_to_user_id != actor_id:
                notify_comment_reply(actor_id, reply_to_user_id, diary_id, parent_comment_id, content)
            # 如果被回复的人不是日记作者，也通知日记作者
            if reply_to_user_id != diary_owner_id and diary_owner_id != actor_id:
                notify_public_diary_comment(actor_id, diary_id, content)
        else:
            # 一级评论：通知日记作者
            notify_public_diary_comment(actor_id, diary_id, content)

    return {
        "ok": True,
        "comment": {
            "id": cid,
            "content": content,
            "created_at": "",
            "image_url": image_url,
        },
    }


def list_comments(diary_id: int, limit: int = 20, viewer_id: int | None = None) -> list[dict]:
    if not db_get_public(diary_id):
        raise HTTPException(status_code=404, detail="日记不存在或不是公开日记")
    limit = min(max(1, limit), 50)
    return db_list_comments(diary_id, limit, viewer_id)


def like_comment(comment_id: int, user_id: int) -> dict:
    """点赞评论"""
    comment = db_get_comment(comment_id)
    if not comment:
        raise HTTPException(status_code=404, detail="评论不存在")
    comment_owner = comment.get("user_id")
    if comment_owner:
        check_block_or_raise(user_id, comment_owner)
    success, already = save_comment_like(comment_id, user_id)
    like_count = count_comment_likes(comment_id)
    return {"ok": True, "like_count": like_count, "already_liked": already}


def unlike_comment(comment_id: int, user_id: int) -> dict:
    """取消点赞评论"""
    comment = db_get_comment(comment_id)
    if not comment:
        raise HTTPException(status_code=404, detail="评论不存在")
    removed = remove_comment_like(comment_id, user_id)
    like_count = count_comment_likes(comment_id)
    return {"ok": True, "like_count": like_count, "was_liked": removed}
