"""用户搜索 - 路由层"""

from fastapi import APIRouter, Depends

from services.auth_service import get_optional_user
from database import search_users_by_keyword

router = APIRouter(prefix="/api/users", tags=["users"])


@router.get("/search")
async def search_users(keyword: str, current_user=Depends(get_optional_user)):
    """根据用户名或昵称搜索用户（排除自己）"""
    if not keyword or not keyword.strip():
        return {"users": []}
    keyword = keyword.strip()
    viewer_id = current_user["id"] if current_user else None
    users = search_users_by_keyword(keyword, viewer_id=viewer_id)
    return {"users": users}
