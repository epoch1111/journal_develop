"""用户主页 - 路由层"""

from fastapi import APIRouter, Depends

from models.schemas import ProfileUpdateRequest
from services.profile_service import get_my_profile, update_my_profile, get_public_profile
from services.auth_service import require_user, get_optional_user

router = APIRouter(prefix="/api/profile", tags=["profile"])


@router.get("/me")
async def my_profile(user=Depends(require_user)):
    """获取我的主页"""
    return get_my_profile(user["id"])


@router.put("/me")
async def edit_my_profile(body: ProfileUpdateRequest, user=Depends(require_user)):
    """编辑我的主页"""
    return update_my_profile(user["id"], body.model_dump())


@router.get("/{user_id}")
async def author_profile(user_id: int, current_user=Depends(get_optional_user)):
    """获取作者公开主页（可选登录以获取关注状态）"""
    uid = current_user["id"] if current_user else None
    return get_public_profile(user_id, uid)
