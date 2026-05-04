"""打招呼系统路由"""

from fastapi import APIRouter, Query, Depends

from models.schemas import GreetCreateRequest
from services.auth_service import require_user
from services.greet_service import (
    create_request,
    accept_request,
    reject_request,
    cancel_request,
    get_detail,
    get_status,
    list_received,
    list_sent,
    get_pending_count,
)

router = APIRouter(prefix="/api/greet", tags=["打招呼"])


@router.post("/requests")
async def api_create(body: GreetCreateRequest, user=Depends(require_user)):
    """发起打招呼申请"""
    return create_request(user["id"], body.receiver_id, body.message)


@router.get("/status/{target_user_id}")
async def api_status(target_user_id: int, user=Depends(require_user)):
    """获取我与某用户的打招呼状态"""
    return get_status(user["id"], target_user_id)


@router.get("/requests/received")
async def api_list_received(status: str = Query(None), user=Depends(require_user)):
    """我收到的打招呼申请"""
    return list_received(user["id"], status)


@router.get("/requests/sent")
async def api_list_sent(status: str = Query(None), user=Depends(require_user)):
    """我发出的打招呼申请"""
    return list_sent(user["id"], status)


@router.get("/requests/{request_id}")
async def api_detail(request_id: int, user=Depends(require_user)):
    """查看打招呼申请详情"""
    return get_detail(user["id"], request_id)


@router.post("/requests/{request_id}/accept")
async def api_accept(request_id: int, user=Depends(require_user)):
    """同意打招呼"""
    return accept_request(user["id"], request_id)


@router.post("/requests/{request_id}/reject")
async def api_reject(request_id: int, user=Depends(require_user)):
    """拒绝打招呼"""
    return reject_request(user["id"], request_id)


@router.post("/requests/{request_id}/cancel")
async def api_cancel(request_id: int, user=Depends(require_user)):
    """取消打招呼"""
    return cancel_request(user["id"], request_id)


@router.get("/pending-count")
async def api_pending_count(user=Depends(require_user)):
    """获取待处理打招呼数量"""
    return get_pending_count(user["id"])
