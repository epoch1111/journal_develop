"""用户主页 - 业务逻辑层"""

from fastapi import HTTPException

from database import (
    get_or_create_default_user,
    get_user_by_id as db_get_user,
    update_user_profile as db_update_user,
    get_user_profile_stats,
    get_user_recent_public_diaries,
    get_user_mood_keywords,
    get_user_public_diary_count,
    get_following_count as db_following_count,
    get_follower_count as db_follower_count,
    is_following as db_is_following,
)

MAX_NICKNAME = 20
MAX_AVATAR = 10
MAX_BIO = 100
MAX_INTERESTS = 200


def _validate_profile(data: dict):
    """校验用户资料字段"""
    nickname = (data.get("nickname") or "").strip()
    if not nickname:
        raise HTTPException(status_code=400, detail="昵称不能为空")
    if len(nickname) > MAX_NICKNAME:
        raise HTTPException(status_code=400, detail=f"昵称最大 {MAX_NICKNAME} 字")
    avatar = (data.get("avatar") or "").strip()
    if len(avatar) > MAX_AVATAR:
        raise HTTPException(status_code=400, detail=f"头像最大 {MAX_AVATAR} 字")
    bio = (data.get("bio") or "").strip()
    if len(bio) > MAX_BIO:
        raise HTTPException(status_code=400, detail=f"简介最大 {MAX_BIO} 字")
    interests = (data.get("interests") or "").strip()
    if len(interests) > MAX_INTERESTS:
        raise HTTPException(status_code=400, detail=f"兴趣标签最大 {MAX_INTERESTS} 字")
    return {"nickname": nickname, "avatar": avatar, "bio": bio, "interests": interests}


def get_my_profile(user_id: int) -> dict:
    """获取我的主页数据"""
    user = db_get_user(user_id)
    if not user:
        raise HTTPException(status_code=500, detail="用户数据异常")
    stats = get_user_profile_stats(user_id)
    mood_keywords = get_user_mood_keywords(user_id)
    recent = get_user_recent_public_diaries(user_id, limit=5)

    return {
        "id": user_id,
        "nickname": user["nickname"],
        "avatar": user["avatar"],
        "bio": user["bio"],
        "interests": user["interests"],
        "stats": stats,
        "following_count": db_following_count(user_id),
        "follower_count": db_follower_count(user_id),
        "mood_keywords": mood_keywords,
        "recent_public_diaries": [
            {
                "id": d["id"],
                "mood": d["mood"],
                "content": d["content"],
                "tags": d["tags"],
                "created_at": d["created_at"],
            }
            for d in recent
        ],
    }


def update_my_profile(user_id: int, data: dict) -> dict:
    """编辑我的主页"""
    validated = _validate_profile(data)
    ok = db_update_user(user_id, validated)
    if not ok:
        raise HTTPException(status_code=500, detail="更新失败")
    return {"ok": True}


def get_public_profile(user_id: int, current_user_id: int = None) -> dict:
    """获取作者公开主页"""
    user = db_get_user(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    if current_user_id:
        from database import is_blocked_between
        if is_blocked_between(current_user_id, user_id):
            return {
                "blocked": True,
                "message": "由于安全设置，暂时无法查看该用户主页",
                "id": user["id"],
                "nickname": user["nickname"],
                "avatar": user["avatar"],
            }

    public_diary_count = get_user_public_diary_count(user_id)
    mood_keywords = get_user_mood_keywords(user_id)
    recent = get_user_recent_public_diaries(user_id, limit=5)
    score = _calculate_same_frequency_score(user_id)

    return {
        "id": user["id"],
        "nickname": user["nickname"],
        "avatar": user["avatar"],
        "bio": user["bio"],
        "interests": user["interests"],
        "public_diary_count": public_diary_count,
        "following_count": db_following_count(user_id),
        "follower_count": db_follower_count(user_id),
        "is_following": db_is_following(current_user_id, user_id),
        "same_frequency_score": score,
        "mood_keywords": mood_keywords,
        "recent_public_diaries": [
            {
                "id": d["id"],
                "mood": d["mood"],
                "content": d["content"],
                "tags": d["tags"],
                "created_at": d["created_at"],
            }
            for d in recent
        ],
    }


def _calculate_same_frequency_score(user_id: int) -> int:
    """计算同频指数（当前只有默认用户，返回固定高分）"""
    return 86
