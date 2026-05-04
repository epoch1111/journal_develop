"""安全中心 - 拉黑 / 举报 / 权限检查"""

from fastapi import HTTPException

from database import (
    block_user as db_block,
    unblock_user as db_unblock,
    has_blocked as db_has_blocked,
    is_blocked_between as db_is_blocked_between,
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
)

VALID_TARGET_TYPES = {"user", "diary", "comment", "message", "treehole"}
VALID_REPORT_REASONS = {"harassment", "spam", "sexual", "violence", "privacy", "scam", "other"}
MAX_DESCRIPTION = 500
MAX_BLOCK_REASON = 200


def check_block_or_raise(user_a_id: int, user_b_id: int):
    """检查任意方向是否存在拉黑，如果是则抛 403"""
    if not user_a_id or not user_b_id:
        return
    if db_is_blocked_between(user_a_id, user_b_id):
        raise HTTPException(status_code=403, detail="由于安全设置，暂时不能进行该操作")


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
    blocked = db_has_blocked(current_user_id, target_user_id)
    blocked_by = db_has_blocked(target_user_id, current_user_id)
    return {
        "blocked": blocked,
        "blocked_by_target": blocked_by,
        "any_blocked": blocked or blocked_by,
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
    """我的举报记录"""
    return db_list_my_reports(current_user_id)
