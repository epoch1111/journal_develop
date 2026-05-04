"""Pydantic 数据模型"""

from typing import Optional
from pydantic import BaseModel


class AnalyzeRequest(BaseModel):
    content: str
    persona: str = "default"  # AI 人格选择


class AnalyzeResponse(BaseModel):
    summary: str
    message: str
    tags: list[str]
    mood_color: str = ""  # 根据内容推断的心情色


class TreeHoleDiary(BaseModel):
    """树洞漂流瓶"""
    id: int
    mood: str
    content: str
    hug_count: int


class HugResponse(BaseModel):
    ok: bool
    hug_count: int
    already_hugged: bool = False
    was_hugged: bool = False


class DiaryUpdateRequest(BaseModel):
    """日记编辑请求，所有字段可选"""
    mood: Optional[str] = None
    content: Optional[str] = None
    ai_summary: Optional[str] = None
    ai_message: Optional[str] = None
    tags: Optional[str] = None
    is_public: Optional[bool] = None
    image_url: Optional[str] = None
    image_urls: Optional[list[str]] = None
    unlock_date: Optional[str] = None


class PublicDiaryLikeRequest(BaseModel):
    """点亮/取消点亮请求"""
    client_id: str


class PublicDiaryCommentRequest(BaseModel):
    """发表评论请求（支持一级评论和回复评论）"""
    client_id: str = ""
    content: str
    parent_comment_id: Optional[int] = None
    reply_to_user_id: Optional[int] = None


class ProfileUpdateRequest(BaseModel):
    """编辑个人主页请求"""
    nickname: str
    avatar: Optional[str] = None
    bio: Optional[str] = None
    interests: Optional[str] = None


# ===== 用户认证 =====

class UserRegisterRequest(BaseModel):
    """注册请求"""
    username: str
    password: str
    email: str = ""


class UserLoginRequest(BaseModel):
    """登录请求"""
    username: str
    password: str


class AuthResponse(BaseModel):
    """认证响应"""
    ok: bool
    access_token: str = ""
    token_type: str = "bearer"
    user: Optional[dict] = None
    detail: str = ""


class TreeHoleReplyRequest(BaseModel):
    """树洞回复请求（支持一级回复和回复某条回复）"""
    content: str
    client_id: str = ""
    parent_reply_id: Optional[int] = None
    reply_to_identity_id: Optional[int] = None


class FollowActionResponse(BaseModel):
    """关注/取消关注响应"""
    ok: bool
    following: bool
    already_followed: bool = False
    follower_count: int = 0


class GreetCreateRequest(BaseModel):
    """打招呼申请请求"""
    receiver_id: int
    message: str


class StartConversationRequest(BaseModel):
    """创建会话请求"""
    user_id: int


class SendMessageRequest(BaseModel):
    """发送私信请求"""
    content: str


class BlockUserRequest(BaseModel):
    """拉黑用户请求"""
    reason: str = ""


class ReportCreateRequest(BaseModel):
    """举报请求"""
    target_type: str
    target_id: int
    reason: str
    description: str = ""
