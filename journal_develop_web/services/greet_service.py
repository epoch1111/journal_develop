"""打招呼系统 - 业务逻辑层"""

from fastapi import HTTPException

from database import (
    create_greet_request as db_create,
    get_greet_request_by_id as db_get,
    get_pending_greet_between as db_pending_between,
    get_latest_greet_between as db_latest_between,
    list_received_greet_requests as db_list_received,
    list_sent_greet_requests as db_list_sent,
    update_greet_status as db_update_status,
    cancel_greet_request as db_cancel,
    count_pending_greet_requests as db_count_pending,
    get_user_by_id,
)

MAX_MESSAGE_LENGTH = 200


def _check_user_exists(user_id: int):
    if not get_user_by_id(user_id):
        raise HTTPException(status_code=404, detail="用户不存在")


def _validate_message(message: str) -> str:
    content = (message or "").strip()
    if not content:
        raise HTTPException(status_code=400, detail="打招呼内容不能为空")
    if len(content) > MAX_MESSAGE_LENGTH:
        raise HTTPException(
            status_code=400,
            detail=f"打招呼内容过长，最多 {MAX_MESSAGE_LENGTH} 字，当前 {len(content)} 字",
        )
    return content


# ============ 发起打招呼 ============

def create_request(current_user_id: int, receiver_id: int, message: str) -> dict:
    _check_user_exists(receiver_id)
    if current_user_id == receiver_id:
        raise HTTPException(status_code=400, detail="不能给自己打招呼哦")
    from services.safety_service import check_block_or_raise
    check_block_or_raise(current_user_id, receiver_id)
    message = _validate_message(message)

    # 检查是否已有 pending（同一方向）
    pending = db_pending_between(current_user_id, receiver_id)
    if pending:
        raise HTTPException(status_code=400, detail="你已经向该用户发送过打招呼申请，请等待回应")

    # 检查同一方向是否已经 accepted
    latest = db_latest_between(current_user_id, receiver_id)
    if latest and latest["status"] == "accepted" and latest["requester_id"] == current_user_id:
        raise HTTPException(status_code=400, detail="你已经与该用户认识了")

    request_id = db_create(current_user_id, receiver_id, message)
    if request_id is None:
        raise HTTPException(status_code=400, detail="你已经向该用户发送过打招呼申请，请等待回应")

    from services.notification_service import notify_greet_request
    notify_greet_request(current_user_id, receiver_id, request_id)

    return {"ok": True, "id": request_id, "status": "pending"}


# ============ 同意 / 拒绝 / 取消 ============

def _get_and_check_ownership(request_id: int, user_id: int, role: str) -> dict:
    """获取申请并校验角色（requester/receiver）"""
    req = db_get(request_id)
    if not req:
        raise HTTPException(status_code=404, detail="打招呼申请不存在")

    field = "receiver_id" if role == "receiver" else "requester_id"
    if req.get(field) != user_id:
        raise HTTPException(status_code=403, detail="无权操作此申请")

    if req["status"] != "pending":
        raise HTTPException(status_code=400, detail=f"申请状态为 {req['status']}，无法操作")
    return req


def accept_request(current_user_id: int, request_id: int) -> dict:
    req = _get_and_check_ownership(request_id, current_user_id, "receiver")
    db_update_status(request_id, "accepted")

    from services.notification_service import notify_greet_accepted
    notify_greet_accepted(current_user_id, req["requester_id"], request_id)

    return {"ok": True, "status": "accepted"}


def reject_request(current_user_id: int, request_id: int) -> dict:
    req = _get_and_check_ownership(request_id, current_user_id, "receiver")
    db_update_status(request_id, "rejected")

    from services.notification_service import notify_greet_rejected
    notify_greet_rejected(current_user_id, req["requester_id"], request_id)

    return {"ok": True, "status": "rejected"}


def cancel_request(current_user_id: int, request_id: int) -> dict:
    req = _get_and_check_ownership(request_id, current_user_id, "requester")
    ok = db_cancel(request_id, current_user_id)
    if not ok:
        raise HTTPException(status_code=400, detail="取消失败")
    return {"ok": True, "status": "cancelled"}


# ============ 查询 ============

def get_detail(current_user_id: int, request_id: int) -> dict:
    req = db_get(request_id)
    if not req:
        raise HTTPException(status_code=404, detail="打招呼申请不存在")
    if req["requester_id"] != current_user_id and req["receiver_id"] != current_user_id:
        raise HTTPException(status_code=403, detail="无权查看此申请")
    # 附加用户信息
    conn = None
    from database import get_connection
    conn = get_connection()
    from database import _attach_user_info
    req = _attach_user_info(conn, req, "requester")
    req = _attach_user_info(conn, req, "receiver")
    conn.close()
    return req


def get_status(current_user_id: int, target_user_id: int) -> dict:
    _check_user_exists(target_user_id)
    if current_user_id == target_user_id:
        return {"status": "self", "request_id": None, "direction": "none"}

    latest = db_latest_between(current_user_id, target_user_id)
    if not latest:
        return {"status": "none", "request_id": None, "direction": "none"}

    direction = "sent" if latest["requester_id"] == current_user_id else "received"
    return {
        "status": latest["status"],
        "request_id": latest["id"],
        "direction": direction,
    }


def list_received(current_user_id: int, status: str | None = None) -> list[dict]:
    return db_list_received(current_user_id, status)


def list_sent(current_user_id: int, status: str | None = None) -> list[dict]:
    return db_list_sent(current_user_id, status)


def get_pending_count(current_user_id: int) -> dict:
    return {"pending_count": db_count_pending(current_user_id)}
