"""图片上传路由"""

import os
import uuid

from fastapi import APIRouter, UploadFile, File, HTTPException

ALLOWED_TYPES = {"image/jpeg", "image/png", "image/gif", "image/webp"}
UPLOADS_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "uploads")

router = APIRouter(prefix="/api", tags=["图片上传"])


@router.post("/upload")
async def upload_image(file: UploadFile = File(...)):
    """上传图片，仅允许常见图片格式，返回访问 URL"""
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"不支持的文件类型：{file.content_type}，仅允许 jpeg/png/gif/webp",
        )

    ext = file.filename.rsplit(".", 1)[-1] if "." in (file.filename or "") else "jpg"
    filename = uuid.uuid4().hex + "." + ext
    filepath = os.path.join(UPLOADS_DIR, filename)
    content = await file.read()
    with open(filepath, "wb") as f:
        f.write(content)
    return {"url": f"/uploads/{filename}"}
