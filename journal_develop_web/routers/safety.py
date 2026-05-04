"""安全中心路由"""

from fastapi import APIRouter, Depends

from models.schemas import BlockUserRequest, ReportCreateRequest
from services.auth_service import require_user
from services.safety_service import (
    block_user,
    unblock_user,
    get_block_status,
    list_blocked_users,
    create_report,
    list_my_reports,
)

router = APIRouter(prefix="/api", tags=["安全中心"])


# ===== 拉黑 =====

@router.post("/users/{user_id}/block")
async def api_block(user_id: int, body: BlockUserRequest, user=Depends(require_user)):
    """拉黑用户"""
    return block_user(user["id"], user_id, body.reason)


@router.delete("/users/{user_id}/block")
async def api_unblock(user_id: int, user=Depends(require_user)):
    """取消拉黑"""
    return unblock_user(user["id"], user_id)


@router.get("/users/{user_id}/block-status")
async def api_block_status(user_id: int, user=Depends(require_user)):
    """查询拉黑状态"""
    return get_block_status(user["id"], user_id)


@router.get("/me/blocked-users")
async def api_my_blocked_users(user=Depends(require_user)):
    """我的拉黑列表"""
    return list_blocked_users(user["id"])


# ===== 举报 =====

@router.post("/reports")
async def api_create_report(body: ReportCreateRequest, user=Depends(require_user)):
    """提交举报"""
    return create_report(user["id"], body.target_type, body.target_id, body.reason, body.description)


@router.get("/reports/my")
async def api_my_reports(user=Depends(require_user)):
    """我的举报记录"""
    return list_my_reports(user["id"])
