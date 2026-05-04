"""联系人接口"""

from fastapi import APIRouter, Depends

from services.auth_service import require_user
from services.contacts_service import get_contacts

router = APIRouter(prefix="/api", tags=["contacts"])


@router.get("/messages/contacts")
def list_contacts(current_user: dict = Depends(require_user)):
    """获取当前用户的已认识列表（已通过打招呼验证，过滤拉黑）"""
    return {"contacts": get_contacts(current_user["id"])}
