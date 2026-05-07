"""安全中心 - 拉黑 / 举报 / 权限检查"""

from fastapi import HTTPException

from database import (
    block_user as db_block,
    unblock_user as db_unblock,
    has_blocked as db_has_blocked,
    is_blocked_between as db_is_blocked_between,
    get_block_direction,
    list_blocked_users as db_list_blocked,
    count_blocked_users as db_count_blocked,
    create_report as db_create_report,
    list_my_reports as db_list_my_reports,
    get_report_by_id as db_get_report,
    count_my_reports as db_count_my_reports,
    get_user_by_id,
    get_diary_owner_id,
    get_comment_owner_or_diary_owner,
    get_message_participants,
    get_treehole_owner_id,
    get_treehole_reply_owner_id,
)

VALID_TARGET_TYPES = {"user", "diary", "comment", "message", "treehole", "treehole_reply"}
VALID_REPORT_REASONS = {"harassment", "spam", "sexual", "violence", "privacy", "scam", "other"}
MAX_DESCRIPTION = 500
MAX_BLOCK_REASON = 200


def get_blocked_user_ids(user_id: int) -> set[int]:
    """获取当前用户所有拉黑和被拉黑的用户 ID 集合"""
    if not user_id:
        return set()
    from database import get_blocked_user_ids as db_get_blocked_ids
    return set(db_get_blocked_ids(user_id))


def filter_diaries_blocked(diaries: list[dict], viewer_id: int | None) -> list[dict]:
    """从日记列表中过滤掉被双向拉黑用户的日记，并标记拉黑状态"""
    if not viewer_id:
        return [{**d, "_blocked": False} for d in diaries]
    blocked_ids = get_blocked_user_ids(viewer_id)
    result = []
    for d in diaries:
        owner = d.get("user_id", 0)
        if owner in blocked_ids:
            d = {**d, "content": "内容不可见", "ai_summary": "", "ai_message": "", "_blocked": True}
            if d.get("image_urls"):
                d["image_urls"] = []
        else:
            d = {**d, "_blocked": False}
        result.append(d)
    return result


def check_block_or_raise(user_a_id: int, user_b_id: int):
    """检查任意方向是否存在拉黑，如果是则抛 403"""
    if not user_a_id or not user_b_id:
        return
    direction = get_block_direction(user_a_id, user_b_id)
    if direction == 'blocked':
        raise HTTPException(status_code=403, detail="你已拉黑该用户，无法进行此操作")
    if direction == 'blocked_by':
        raise HTTPException(status_code=403, detail="该用户已拉黑你，无法进行此操作")


# ============ 拉黑 ============

def block_user(current_user_id: int, target_user_id: int, reason: str = "") -> dict:
    """拉黑用户"""
    if not get_user_by_id(target_user_id):
        raise HTTPException(status_code=404, detail="用户不存在")
    if current_user_id == target_user_id:
        raise HTTPException(status_code=400, detail="不能拉黑自己哦")

    if db_has_blocked(current_user_id, target_user_id):
        return {"ok": True, "blocked": True, "already_blocked": True}

    reason = (reason or "").strip()
    if len(reason) > MAX_BLOCK_REASON:
        raise HTTPException(status_code=400, detail=f"拉黑原因最多 {MAX_BLOCK_REASON} 字")

    ok = db_block(current_user_id, target_user_id, reason)
    if not ok:
        raise HTTPException(status_code=500, detail="拉黑失败")

    # 拉黑后自动双向取消关注
    from database import unfollow_user, is_following
    if is_following(current_user_id, target_user_id):
        unfollow_user(current_user_id, target_user_id)
    if is_following(target_user_id, current_user_id):
        unfollow_user(target_user_id, current_user_id)

    return {"ok": True, "blocked": True, "already_blocked": False}


def unblock_user(current_user_id: int, target_user_id: int) -> dict:
    """取消拉黑"""
    if not get_user_by_id(target_user_id):
        raise HTTPException(status_code=404, detail="用户不存在")
    db_unblock(current_user_id, target_user_id)
    return {"ok": True, "blocked": False}


def get_block_status(current_user_id: int, target_user_id: int) -> dict:
    """查询拉黑状态"""
    if not get_user_by_id(target_user_id):
        raise HTTPException(status_code=404, detail="用户不存在")
    direction = get_block_direction(current_user_id, target_user_id)
    return {
        "blocked": direction == 'blocked',
        "blocked_by_target": direction == 'blocked_by',
        "any_blocked": direction is not None,
    }


def list_blocked_users(current_user_id: int) -> list[dict]:
    """我拉黑的用户列表"""
    return db_list_blocked(current_user_id)


# ============ 举报 ============

def _infer_target_user(target_type: str, target_id: int) -> int | None:
    """根据 target_type 和 target_id 推断被举报对象的所有者 id"""
    if target_type == "user":
        return target_id
    elif target_type == "diary":
        owner = get_diary_owner_id(target_id)
        if owner is None:
            raise HTTPException(status_code=404, detail="日记不存在")
        return owner
    elif target_type == "comment":
        owner = get_comment_owner_or_diary_owner(target_id)
        if owner is None:
            raise HTTPException(status_code=404, detail="评论不存在")
        return owner
    elif target_type == "message":
        sender, receiver = get_message_participants(target_id)
        if sender is None:
            raise HTTPException(status_code=404, detail="消息不存在")
        return sender
    elif target_type == "treehole":
        owner = get_treehole_owner_id(target_id)
        if owner is None:
            raise HTTPException(status_code=404, detail="树洞日记不存在")
        return owner
    elif target_type == "treehole_reply":
        owner = get_treehole_reply_owner_id(target_id)
        if owner is None:
            raise HTTPException(status_code=404, detail="树洞回复不存在")
        return owner
    return None


def create_report(current_user_id: int, target_type: str, target_id: int,
                  reason: str, description: str = "") -> dict:
    """提交举报"""
    if target_type not in VALID_TARGET_TYPES:
        raise HTTPException(status_code=400, detail=f"target_type 必须是 {' / '.join(sorted(VALID_TARGET_TYPES))}")
    if reason not in VALID_REPORT_REASONS:
        raise HTTPException(status_code=400, detail=f"reason 必须是 {' / '.join(sorted(VALID_REPORT_REASONS))}")

    description = (description or "").strip()
    if len(description) > MAX_DESCRIPTION:
        raise HTTPException(status_code=400, detail=f"描述最多 {MAX_DESCRIPTION} 字")

    target_user_id = _infer_target_user(target_type, target_id)

    rid = db_create_report(current_user_id, target_type, target_id, target_user_id, reason, description)
    return {"ok": True, "id": rid, "status": "pending"}


def list_my_reports(current_user_id: int) -> list[dict]:
    """我的举报记录，附加被举报内容详情"""
    from database import (
        get_diary_by_id, get_comment_by_id as db_get_comment,
        get_treehole_by_id, get_treehole_reply_by_id as db_get_treehole_reply,
        get_user_by_id,
    )

    reports = db_list_my_reports(current_user_id)
    status_labels = {
        "pending": "待处理",
        "reviewed": "处理中",
        "resolved": "已处理",
        "dismissed": "已驳回",
    }

    for r in reports:
        r["status_label"] = status_labels.get(r.get("status", "pending"), "待处理")
        # 填充被举报内容详情
        target_type = r.get("target_type", "")
        target_id = r.get("target_id", 0)
        target_user_id = r.get("target_user_id")

        # 被举报人信息
        if target_user_id:
            target_user = get_user_by_id(target_user_id)
            if target_user:
                r["target_nickname"] = target_user.get("nickname", "")
                r["target_avatar"] = target_user.get("avatar", "🐰")
                r["target_username"] = target_user.get("username", "")

        # 被举报内容
        r["target_content"] = ""
        r["target_excerpt"] = ""

        if target_type == "diary":
            diary = get_diary_by_id(target_id)
            if diary:
                r["target_content"] = diary.get("content", "")
                r["target_excerpt"] = (diary.get("content") or "")[:100]
                r["target_mood"] = diary.get("mood", "")

        elif target_type == "comment":
            comment = db_get_comment(target_id)
            if comment:
                r["target_content"] = comment.get("content", "")
                r["target_excerpt"] = (comment.get("content") or "")[:100]

        elif target_type == "treehole":
            diary = get_diary_by_id(target_id)
            if diary:
                r["target_content"] = diary.get("content", "")
                r["target_excerpt"] = (diary.get("content") or "")[:100]

        elif target_type == "treehole_reply":
            reply = db_get_treehole_reply(target_id)
            if reply:
                r["target_content"] = reply.get("content", "")
                r["target_excerpt"] = (reply.get("content") or "")[:100]

        elif target_type == "user":
            user = get_user_by_id(target_id)
            if user:
                r["target_content"] = user.get("bio", "")
                r["target_excerpt"] = (user.get("bio") or "")[:100]

    return reports
