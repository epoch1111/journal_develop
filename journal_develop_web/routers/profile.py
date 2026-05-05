"""用户主页 - 路由层"""

import os, uuid
from fastapi import APIRouter, Depends, UploadFile, File, HTTPException

from models.schemas import ProfileUpdateRequest
from services.profile_service import get_my_profile, update_my_profile, get_public_profile
from services.auth_service import require_user, get_optional_user

router = APIRouter(prefix="/api/profile", tags=["profile"])

ALLOWED_AVATAR_TYPES = {"image/jpeg", "image/png", "image/gif", "image/webp"}
AVATAR_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "uploads", "avatars")


@router.get("/me")
async def my_profile(user=Depends(require_user)):
    """获取我的主页"""
    return get_my_profile(user["id"])


@router.put("/me")
async def edit_my_profile(body: ProfileUpdateRequest, user=Depends(require_user)):
    """编辑我的主页"""
    return update_my_profile(user["id"], body.model_dump())


@router.post("/avatar")
async def upload_avatar(file: UploadFile = File(...), user=Depends(require_user)):
    """上传头像图片，替换 emoji 默认头像"""
    if file.content_type not in ALLOWED_AVATAR_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"不支持的文件类型：{file.content_type}，仅允许 jpeg/png/gif/webp",
        )

    ext = file.filename.rsplit(".", 1)[-1] if "." in (file.filename or "") else "jpg"
    filename = uuid.uuid4().hex + "." + ext
    os.makedirs(AVATAR_DIR, exist_ok=True)
    filepath = os.path.join(AVATAR_DIR, filename)

    with open(filepath, "wb") as f:
        content = await file.read()
        f.write(content)

    # 前端可直接访问 /uploads/avatars/xxx.jpg
    avatar_url = f"/uploads/avatars/{filename}"
    update_my_profile(user["id"], {"avatar": avatar_url})
    return {"ok": True, "avatar": avatar_url}


@router.get("/{user_id}")
async def author_profile(user_id: int, current_user=Depends(get_optional_user)):
    """获取作者公开主页（可选登录以获取关注状态）"""
    uid = current_user["id"] if current_user else None
    return get_public_profile(user_id, uid)
