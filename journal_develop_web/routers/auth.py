"""用户认证路由"""

from fastapi import APIRouter, Depends

from models.schemas import UserRegisterRequest, UserLoginRequest, UserChangePasswordRequest
from services.auth_service import register, login, get_me, get_current_user, require_user, change_password

router = APIRouter(prefix="/api/auth", tags=["用户认证"])


@router.post("/register")
async def api_register(body: UserRegisterRequest):
    return register(body.username, body.password, body.email)


@router.post("/login")
async def api_login(body: UserLoginRequest):
    return login(body.username, body.password)


@router.get("/me")
async def api_me(user=Depends(require_user)):
    return get_me(user)


@router.post("/change-password")
async def api_change_password(body: UserChangePasswordRequest, user=Depends(require_user)):
    return change_password(user, body.current_password, body.new_password)
