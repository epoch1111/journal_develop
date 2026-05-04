"""关注系统 - 业务逻辑层"""

from fastapi import HTTPException

from database import (
    follow_user as db_follow,
    unfollow_user as db_unfollow,
    is_following as db_is_following,
    get_following_count as db_following_count,
    get_follower_count as db_follower_count,
    list_following_users as db_list_following,
    list_follower_users as db_list_followers,
    get_following_recent_diaries as db_following_diaries,
    get_user_by_id as db_get_user,
    get_user_public_diary_count,
    get_user_recent_public_diaries,
)


def _check_user_exists(user_id: int):
    if not db_get_user(user_id):
        raise HTTPException(status_code=404, detail="用户不存在")


def _sanitize_user_list_item(user: dict) -> dict:
    """清理用户列表项，附加统计信息"""
    uid = user["id"]
    recent = get_user_recent_public_diaries(uid, limit=1)
    return {
        "id": uid,
        "nickname": user.get("nickname", ""),
        "avatar": user.get("avatar", "🐰"),
        "bio": user.get("bio", ""),
        "interests": user.get("interests", ""),
        "follower_count": db_follower_count(uid),
        "public_diary_count": get_user_public_diary_count(uid),
        "recent_public_diary": {
            "id": recent[0]["id"],
            "mood": recent[0]["mood"],
            "content": recent[0]["content"],
            "created_at": recent[0]["created_at"],
        } if recent else None,
    }


# ============ 关注 / 取消关注 ============

def follow(current_user_id: int, target_user_id: int) -> dict:
    _check_user_exists(target_user_id)
    if current_user_id == target_user_id:
        raise HTTPException(status_code=400, detail="不能关注自己哦")
    from services.safety_service import check_block_or_raise
    check_block_or_raise(current_user_id, target_user_id)

    already = db_is_following(current_user_id, target_user_id)
    if not already:
        db_follow(current_user_id, target_user_id)
        from services.notification_service import notify_follow
        notify_follow(current_user_id, target_user_id)

    return {
        "ok": True,
        "following": True,
        "already_followed": already,
        "follower_count": db_follower_count(target_user_id),
    }


def unfollow(current_user_id: int, target_user_id: int) -> dict:
    _check_user_exists(target_user_id)
    db_unfollow(current_user_id, target_user_id)
    return {
        "ok": True,
        "following": False,
        "already_followed": False,
        "follower_count": db_follower_count(target_user_id),
    }


# ============ 关注状态 ============

def get_follow_status(current_user_id: int | None, target_user_id: int) -> dict:
    _check_user_exists(target_user_id)
    return {
        "following": db_is_following(current_user_id, target_user_id),
        "follower_count": db_follower_count(target_user_id),
        "following_count": db_following_count(target_user_id),
    }


# ============ 关注列表 / 粉丝列表 ============

def list_my_following(current_user_id: int) -> list[dict]:
    users = db_list_following(current_user_id)
    return [_sanitize_user_list_item(u) for u in users]


def list_my_followers(current_user_id: int) -> list[dict]:
    users = db_list_followers(current_user_id)
    return [_sanitize_user_list_item(u) for u in users]


# ============ 关注动态 ============

def get_following_feed(current_user_id: int, page: int = 1, page_size: int = 10) -> dict:
    page = max(1, page)
    page_size = min(max(1, page_size), 50)
    diaries = db_following_diaries(current_user_id, limit=1000)

    # 过滤拉黑用户的日记
    from database import get_blocked_user_ids
    blocked_ids = set(get_blocked_user_ids(current_user_id))
    diaries = [d for d in diaries if d.get("user_id", 0) not in blocked_ids]

    total = len(diaries)
    start = (page - 1) * page_size
    items = diaries[start:start + page_size]

    from database import count_public_diary_likes, count_public_diary_comments, get_multi_diary_images

    # 批量获取图片
    img_map = {}
    if items:
        ids = [d["id"] for d in items]
        img_map = get_multi_diary_images(ids)

    return {
        "items": [
            {
                "id": d["id"],
                "user_id": d["user_id"],
                "author_name": d.get("author_name", ""),
                "author_avatar": d.get("author_avatar", "🐰"),
                "mood": d.get("mood", ""),
                "content": d.get("content", ""),
                "tags": d.get("tags", ""),
                "image_urls": [img["image_url"] for img in img_map.get(d["id"], [])],
                "created_at": d.get("created_at", ""),
                "like_count": count_public_diary_likes(d["id"]),
                "comment_count": count_public_diary_comments(d["id"]),
            }
            for d in items
        ],
        "page": page,
        "page_size": page_size,
        "has_more": start + page_size < total,
    }
