"""OTA update - version check + APK download"""

import os
import json
from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse

router = APIRouter(prefix="/api/app", tags=["app"])

BASE = os.path.dirname(os.path.dirname(__file__))
VERSION_PATH = os.path.join(BASE, "version.json")
APK_PATH = os.path.join(BASE, "static", "echo_release.apk")
DEFAULT_VERSION = {"version": "1.0.0", "version_code": 1, "changelog": ""}


@router.get("/version")
async def get_version():
    try:
        with open(VERSION_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return DEFAULT_VERSION


@router.get("/download")
async def download_apk():
    if not os.path.exists(APK_PATH):
        raise HTTPException(status_code=404, detail="APK 文件不存在，请先构建")
    return FileResponse(
        APK_PATH,
        media_type="application/vnd.android.package-archive",
        filename="echo_journal.apk",
    )
