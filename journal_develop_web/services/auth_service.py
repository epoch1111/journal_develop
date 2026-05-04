"""用户认证 - 业务逻辑层"""

from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, Request, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from passlib.context import CryptContext

from config import JWT_SECRET_KEY, JWT_ALGORITHM, JWT_EXPIRE_DAYS
from database import (
    get_user_by_username as db_get_user_by_username,
    create_user as db_create_user,
    get_user_by_id as db_get_user_by_id,
)

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer(auto_error=False)

MIN_USERNAME_LEN = 2
MAX_USERNAME_LEN = 20
MIN_PASSWORD_LEN = 6
MAX_PASSWORD_LEN = 128

USERNAME_PATTERN = r'^[a-zA-Z0-9_一-鿿]+$'


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


def create_access_token(user_id: int, username: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=JWT_EXPIRE_DAYS)
    payload = {
        "sub": str(user_id),
        "username": username,
        "exp": expire,
    }
    return jwt.encode(payload, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)


def decode_access_token(token: str) -> dict | None:
    try:
        return jwt.decode(token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
    except JWTError:
        return None


def get_current_user(request: Request, credentials: HTTPAuthorizationCredentials = Depends(security)):
    """从 Bearer Token 中解析当前用户并注入 request.state.user"""
    user = _resolve_user(credentials)
    request.state.user = user
    request.state.user_id = user["id"] if user else None
    return user


def get_optional_user(request: Request, credentials: HTTPAuthorizationCredentials = Depends(security)):
    """可选鉴权：有 token 则解析用户，没有也不报错"""
    user = _resolve_user(credentials) if credentials else None
    request.state.user = user
    request.state.user_id = user["id"] if user else None
    return user


def require_user(user=Depends(get_current_user)):
    """强制鉴权：未登录返回 401"""
    if user is None:
        raise HTTPException(status_code=401, detail="请先登录")
    return user


def _resolve_user(credentials: HTTPAuthorizationCredentials | None):
    if credentials is None:
        return None
    payload = decode_access_token(credentials.credentials)
    if payload is None:
        return None
    user_id = int(payload.get("sub", 0))
    if not user_id:
        return None
    return db_get_user_by_id(user_id)


# ============ 注册 / 登录 ============

def register(username: str, password: str, email: str = "") -> dict:
    import re
    username = (username or "").strip()
    password = (password or "").strip()
    email = (email or "").strip()

    if not username or not password:
        raise HTTPException(status_code=400, detail="用户名和密码不能为空")
    if len(username) < MIN_USERNAME_LEN or len(username) > MAX_USERNAME_LEN:
        raise HTTPException(status_code=400, detail=f"用户名长度需要 {MIN_USERNAME_LEN}-{MAX_USERNAME_LEN} 个字符")
    if not re.match(USERNAME_PATTERN, username):
        raise HTTPException(status_code=400, detail="用户名只能包含字母、数字、下划线和中文")
    if len(password) < MIN_PASSWORD_LEN or len(password) > MAX_PASSWORD_LEN:
        raise HTTPException(status_code=400, detail=f"密码长度需要 {MIN_PASSWORD_LEN}-{MAX_PASSWORD_LEN} 个字符")

    existing = db_get_user_by_username(username)
    if existing:
        raise HTTPException(status_code=409, detail="用户名已被注册")

    hashed = hash_password(password)
    user = db_create_user(username, hashed, email)
    if not user:
        raise HTTPException(status_code=500, detail="注册失败，请重试")

    token = create_access_token(user["id"], username)
    return {
        "ok": True,
        "access_token": token,
        "token_type": "bearer",
        "user": _sanitize_user(user),
    }


def login(username: str, password: str) -> dict:
    username = (username or "").strip()
    password = (password or "").strip()

    if not username or not password:
        raise HTTPException(status_code=400, detail="用户名和密码不能为空")

    user = db_get_user_by_username(username)
    if not user or not verify_password(password, user.get("password_hash", "")):
        raise HTTPException(status_code=401, detail="用户名或密码错误")

    token = create_access_token(user["id"], username)
    return {
        "ok": True,
        "access_token": token,
        "token_type": "bearer",
        "user": _sanitize_user(user),
    }


def get_me(user: dict = Depends(require_user)) -> dict:
    return {"ok": True, "user": _sanitize_user(user)}


def _sanitize_user(user: dict) -> dict:
    return {
        "id": user["id"],
        "username": user.get("username", ""),
        "nickname": user.get("nickname", "小兔"),
        "avatar": user.get("avatar", "🐰"),
        "bio": user.get("bio", ""),
        "interests": user.get("interests", ""),
        "email": user.get("email", ""),
        "created_at": user.get("created_at", ""),
    }
