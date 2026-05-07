"""Echo 日记 - 应用入口"""

import os

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
from pathlib import Path

from database import init_db
from routers.analyze import router as analyze_router
from routers.diary import router as diary_router
from routers.upload import router as upload_router
from routers.dev import router as dev_router
from routers.public_diary import router as public_diary_router
from routers.profile import router as profile_router
from routers.auth import router as auth_router
from routers.follow import router as follow_router
from routers.notification import router as notification_router
from routers.greet import router as greet_router
from routers.message import router as message_router
from routers.safety import router as safety_router
from routers.contacts import router as contacts_router
from routers.ws import router as ws_router
from routers.seed_demo import router as seed_demo_router
from routers.app_version import router as app_version_router
from routers.users import router as users_router

app = FastAPI(title="Echo - 治愈系智能日记")

# CORS：允许所有来源（用于 ngrok 等公网穿透场景）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 确保上传目录存在
UPLOADS_DIR = os.path.join(os.path.dirname(__file__), "uploads")
os.makedirs(UPLOADS_DIR, exist_ok=True)


@app.on_event("startup")
def startup():
    init_db()


# 静态资源挂载
app.mount("/static", StaticFiles(directory="static"), name="static")
app.mount("/uploads", StaticFiles(directory=UPLOADS_DIR), name="uploads")

# 注册路由模块
app.include_router(analyze_router)
app.include_router(diary_router)
app.include_router(upload_router)
app.include_router(dev_router)
app.include_router(public_diary_router)
app.include_router(profile_router)
app.include_router(auth_router)
app.include_router(follow_router)
app.include_router(notification_router)
app.include_router(greet_router)
app.include_router(message_router)
app.include_router(safety_router)
app.include_router(contacts_router)
app.include_router(ws_router)
app.include_router(seed_demo_router)
app.include_router(app_version_router)
app.include_router(users_router)


@app.get("/", response_class=HTMLResponse)
async def root():
    html_path = Path("templates/index.html")
    return html_path.read_text(encoding="utf-8")
