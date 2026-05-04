# Echo 日记 - API 文档

> Base URL: `http://localhost:8000`
> 鉴权方式: `Authorization: Bearer <token>` (注册/登录返回 access_token)

## 目录

1. [认证 (Auth)](#1-认证-auth)
2. [日记 (Diary)](#2-日记-diary)
3. [AI 分析 (Analyze)](#3-ai-分析-analyze)
4. [图片上传 (Upload)](#4-图片上传-upload)
5. [统计 (Stats)](#5-统计-stats)
6. [树洞 (Treehole)](#6-树洞-treehole)
7. [公开广场 (Public Diaries)](#7-公开广场-public-diaries)
8. [用户主页 (Profile)](#8-用户主页-profile)
9. [关注 (Follow)](#9-关注-follow)
10. [通知 (Notification)](#10-通知-notification)
11. [打招呼 (Greet)](#11-打招呼-greet)
12. [私信 (Message)](#12-私信-message)
13. [安全 (Safety)](#13-安全-safety)
14. [开发工具 (Dev)](#14-开发工具-dev)

---

## 1. 认证 (Auth)

| 方法 | 路径 | 鉴权 | 说明 |
|------|------|------|------|
| POST | `/api/auth/register` | 无 | 注册 |
| POST | `/api/auth/login` | 无 | 登录 |
| GET | `/api/auth/me` | Bearer | 当前用户信息 |

### POST /api/auth/register

注册新用户，成功后返回 JWT Token。

**请求体**:
```json
{
  "username": "testuser",
  "password": "test123",
  "email": "test@test.com"
}
```

**响应 200**:
```json
{
  "ok": true,
  "access_token": "eyJ...",
  "token_type": "bearer",
  "user": { "id": 1, "username": "testuser", "nickname": "小兔", ... }
}
```

**响应 409**: `{"detail": "用户名已存在"}`

---

### POST /api/auth/login

**请求体**: 同注册（不含 email）

**响应 200**: 同注册，返回 token 和用户信息

**响应 401**: `{"detail": "用户名或密码错误"}`

---

### GET /api/auth/me

**请求头**: `Authorization: Bearer <token>`

**响应 200**:
```json
{
  "ok": true,
  "user": {
    "id": 1,
    "username": "testuser",
    "nickname": "小兔",
    "avatar": "🐰",
    "bio": "今天也在认真生活",
    "interests": "日记,生活,小确幸",
    "email": "test@test.com",
    "created_at": "2026-01-01 12:00:00"
  }
}
```

**响应 401**: `{"detail": "未登录"}`

---

## 2. 日记 (Diary)

所有接口需 Bearer Token。

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/save` | 创建日记 |
| GET | `/api/diaries` | 日记列表 (可选 `?date=YYYY-MM-DD`) |
| GET | `/api/diaries/date/{date}` | 按日期查询 |
| GET | `/api/diaries/{id}` | 日记详情 |
| PUT | `/api/diaries/{id}` | 编辑日记 |
| DELETE | `/api/diaries/{id}` | 删除日记 |

### POST /api/save

创建日记或时光胶囊。`content_type` 由后端根据 `unlock_date` 自动判断：有解锁日期 → `capsule`，无解锁日期 → `diary`。

**请求体**:
```json
{
  "mood": "😊",
  "content": "今天的日记内容...",
  "ai_summary": "AI 摘要",
  "ai_message": "AI 治愈语",
  "tags": "生活,工作",
  "is_public": true,
  "unlock_date": "",
  "image_urls": ["/uploads/abc.jpg", "/uploads/def.jpg"]
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| mood | str | 否 | 心情 emoji，默认 😊 |
| content | str | 否 | 日记内容 |
| ai_summary | str | 否 | AI 摘要 |
| ai_message | str | 否 | AI 治愈语 |
| tags | str | 否 | 逗号分隔标签 |
| is_public | bool | 否 | 是否公开，默认 false |
| unlock_date | str | 否 | `YYYY-MM-DD`，非空即为时光胶囊 |
| image_urls | list[str] | 否 | 图片 URL 数组 |

**响应 200**: `{"ok": true, "id": 123}`

---

### GET /api/diaries

**查询参数**: `?date=YYYY-MM-DD` (可选)

**响应 200**:
```json
[
  {
    "id": 123,
    "mood": "😊",
    "content": "日记内容...",
    "ai_summary": "AI 摘要",
    "ai_message": "AI 治愈语",
    "tags": "生活",
    "is_public": true,
    "created_at": "2026-01-01 12:00:00",
    "unlock_date": "",
    "image_url": "/uploads/abc.jpg",
    "image_urls": ["/uploads/abc.jpg"],
    "hug_count": 0,
    "locked": false,
    "days_left": 0
  }
]
```

> 未到期胶囊：`locked=true`, `content` 字段被屏蔽，`days_left` 为剩余天数

---

### PUT /api/diaries/{id}

编辑日记，所有字段可选。

**请求体** (全部可选):
```json
{
  "mood": "😢",
  "content": "修改后的内容",
  "ai_summary": "新摘要",
  "ai_message": "新消息",
  "tags": "新标签",
  "is_public": false,
  "image_urls": ["/uploads/new.jpg"],
  "unlock_date": ""
}
```

**响应 200**: `{"ok": true}`

**响应 403**: 非本人日记

---

### DELETE /api/diaries/{id}

**响应 200**: `{"ok": true}`

**响应 403**: 非本人日记

---

## 3. AI 分析 (Analyze)

| 方法 | 路径 | 鉴权 | 说明 |
|------|------|------|------|
| POST | `/api/analyze` | 无 | Mock AI 分析 |

### POST /api/analyze

**请求体**:
```json
{
  "content": "今天心情很好，和朋友吃了火锅！",
  "persona": "default"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| content | str | 是 | 待分析文本 |
| persona | str | 否 | AI 人格，`default` 或 `cheerful` |

**响应 200**:
```json
{
  "summary": "火锅聚餐",
  "message": "和朋友在一起的时光总是最治愈的～",
  "tags": ["朋友", "美食", "开心"],
  "mood_color": "#FFD93D"
}
```

---

## 4. 图片上传 (Upload)

| 方法 | 路径 | 鉴权 | 说明 |
|------|------|------|------|
| POST | `/api/upload` | 可选 | 上传图片 |

### POST /api/upload

**请求体**: `multipart/form-data`, 字段 `file`

**限制**: 仅允许 `image/jpeg`, `image/png`, `image/gif`, `image/webp`

**响应 200**: `{"url": "/uploads/a1b2c3d4.jpg"}`

**响应 400**: `{"detail": "不支持的文件类型：..."}`

---

## 5. 统计 (Stats)

所有接口需 Bearer Token。

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/stats` | 完整统计 (心情分布 + 日历) |
| GET | `/api/mood-stats` | 心情速览条 |

### GET /api/stats

**响应 200**:
```json
{
  "mood_distribution": [
    {"mood": "😊", "count": 15, "color": "#FFD93D"}
  ],
  "calendar_data": [
    {"date": "2026-01-01", "mood": "😊", "count": 2}
  ]
}
```

---

## 6. 树洞 (Treehole)

投递需登录（Bearer Token），读取无鉴权。树洞内容仅限 `content_type='treehole'`，**返回时一律匿名**（不返回 user_id、author_name、author_avatar）。

| 方法 | 路径 | 鉴权 | 说明 |
|------|------|------|------|
| POST | `/api/treehole` | Bearer | 匿名投递漂流瓶 |
| GET | `/api/treehole/random` | 无 | 随机漂流瓶 |
| GET | `/api/treehole/{id}` | 无 | 树洞详情（匿名） |
| POST | `/api/treehole/{id}/hug` | Bearer | 抱抱（toggle 开） |
| DELETE | `/api/treehole/{id}/hug` | Bearer | 取消抱抱（toggle 关） |
| POST | `/api/treehole/{id}/reply` | Bearer | 匿名回复 |
| POST | `/api/treehole/replies/{id}/like` | Bearer | 点赞回复（toggle 开） |
| DELETE | `/api/treehole/replies/{id}/like` | Bearer | 取消点赞回复（toggle 关） |

### POST /api/treehole

匿名投递树洞漂流瓶（登录后操作，但对外匿名）。

**请求体**:
```json
{
  "mood": "😢",
  "content": "今天有点难过...",
  "tags": "心情"
}
```

**响应 200**: `{"ok": true, "id": 456}`

### GET /api/treehole/random

随机获取一条树洞漂流瓶，不返回作者信息。

**响应 200**:
```json
{
  "id": 456,
  "mood": "😊",
  "content": "今天的日记...",
  "hug_count": 5
}
```
> 注意：不包含 `user_id`、`author_name`、`author_avatar` 字段

**响应 404**: `{"detail": "暂时还没有人投递漂流瓶哦～"}`

### GET /api/treehole/{id}

获取树洞日记详情（匿名），包含标签和回复列表。

**响应 200**:
```json
{
  "id": 456,
  "mood": "😊",
  "content": "今天的日记...",
  "tags": "心情,秘密",
  "hug_count": 5,
  "created_at": "2026-05-04 20:30:00",
  "replies": [
    {
      "id": 1,
      "content": "加油！",
      "created_at": "2026-05-04 20:35:00"
    }
  ]
}
```
> 注意：不包含 `user_id`、`author_name`、`author_avatar` 字段。回复列表中的每条回复均为匿名，仅包含 `id`、`content`、`created_at`。

**响应 404**: 树洞日记不存在或不是 treehole 类型

### POST /api/treehole/{id}/hug

给树洞日记抱抱，需登录。每个账号对同一树洞只能抱一次。Toggle 模式：点一下抱抱，再点一下取消。

**响应 200** (首次抱抱): `{"ok": true, "hug_count": 6, "already_hugged": false}`

**响应 200** (已抱过): `{"ok": true, "hug_count": 6, "already_hugged": true}`

**响应 401**: 未登录

**响应 404**: 树洞日记不存在或不是 treehole 类型

### DELETE /api/treehole/{id}/hug

取消树洞抱抱，需登录。

**响应 200** (取消成功): `{"ok": true, "hug_count": 5, "was_hugged": true}`

**响应 200** (无抱抱记录): `{"ok": true, "hug_count": 5, "was_hugged": false}`

**响应 401**: 未登录

**响应 404**: 树洞日记不存在或不是 treehole 类型

### POST /api/treehole/{id}/reply

匿名回复树洞日记，需登录（对外展示为匿名，user_id 仅内部用于通知）。仅限 `content_type='treehole'` 的条目。支持线程回复（回复某条回复）。

**请求体**:
```json
{
  "content": "加油！",
  "client_id": "",
  "parent_reply_id": null,
  "reply_to_identity_id": null
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| content | string | 是 | 回复内容（最长 500 字） |
| client_id | string | 否 | 客户端 ID（用于匿名身份生成） |
| parent_reply_id | int | 否 | 回复的父回复 ID（线程回复） |
| reply_to_identity_id | int | 否 | 被回复的匿名身份 ID（用于 "回复 XXX" 显示） |

**响应 200**:
```json
{
  "ok": true,
  "reply": {
    "id": 1,
    "content": "加油！",
    "created_at": "",
    "identity_id": 1,
    "anon_name": "清风侠",
    "anon_avatar": "🍃",
    "parent_reply_id": null,
    "root_reply_id": null,
    "reply_to_identity_id": null,
    "reply_to_anon_name": ""
  }
}
```

**响应 400**: 回复内容为空/过长/父回复不存在/跨树洞回复/匿名身份不存在

**响应 401**: 未登录

**响应 404**: 树洞日记不存在或不是 treehole 类型

### POST /api/treehole/replies/{id}/like

点赞树洞回复（toggle 开），需登录。每个账号对同一回复只能点一次赞。

**响应 200** (首次): `{"ok": true, "like_count": 1, "already_liked": false}`

**响应 200** (重复): `{"ok": true, "like_count": 1, "already_liked": true}`

### DELETE /api/treehole/replies/{id}/like

取消点赞树洞回复（toggle 关），需登录。

**响应 200** (取消成功): `{"ok": true, "like_count": 0, "was_liked": true}`

**响应 200** (无点赞记录): `{"ok": true, "like_count": 0, "was_liked": false}`

---

## 7. 公开广场 (Public Diaries)

仅展示 `content_type='diary'` + `is_public=1` + `unlock_date` 为空的公开日记。树洞 (`treehole`) 和胶囊 (`capsule`) 不会出现在广场。

可选鉴权（登录后可获得更多上下文，如过滤拉黑用户日记）。

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/public/diaries` | 分页列表 + 筛选 |
| GET | `/api/public/diaries/{id}` | 详情 (含评论和图片) |
| POST | `/api/public/diaries/{id}/like` | 点亮 |
| DELETE | `/api/public/diaries/{id}/like` | 取消点亮 |
| POST | `/api/public/diaries/{id}/comments` | 发表评论 |
| GET | `/api/public/diaries/{id}/comments` | 评论列表 |

### GET /api/public/diaries

**查询参数**:

| 参数 | 类型 | 默认 | 说明 |
|------|------|------|------|
| page | int | 1 | 页码 |
| page_size | int | 10 | 每页条数 (最大 50) |
| mood | str | - | 按心情筛选 |
| tag | str | - | 按标签筛选 |
| keyword | str | - | 关键词搜索（正文/标签/昵称/AI摘要/陪伴语/心情emoji或中文心情词），最多50字 |
| client_id | str | - | 客户端标识 (用于点亮状态) |

**响应 200**:
```json
{
  "items": [
    {
      "id": 123,
      "mood": "😊",
      "content": "日记内容...",
      "ai_summary": "摘要",
      "ai_message": "治愈语",
      "tags": "生活",
      "created_at": "2026-01-01",
      "user": { "id": 1, "nickname": "小兔", "avatar": "🐰" },
      "like_count": 10,
      "comment_count": 3,
      "liked": true,
      "image_urls": ["/uploads/abc.jpg"]
    }
  ],
  "total": 100,
  "page": 1,
  "page_size": 10
}
```

**搜索规则**：
- 匹配字段：日记正文 `content`、标签 `tags`、AI 摘要 `ai_summary`、AI 陪伴语 `ai_message`、作者昵称 `users.nickname`、心情 `mood`
- 中文心情词映射：开心/高兴/快乐->😊，疲惫/累->😫，难过/伤心->😢，生气/愤怒->😡，幸福/幸运->🥰
- 搜索范围仅限公开普通日记（排除私密日记、树洞、胶囊）
- keyword 为空时不启用搜索，超 50 字返回 400

### POST /api/public/diaries/{id}/like

**请求体**: `{"client_id": "my_device_123"}`

**响应 200**: `{"ok": true, "like_count": 11, "liked": true}`

重复点亮返回: `{"ok": true, "already_liked": true}`

### POST /api/public/diaries/{id}/comments

**请求体**:
```json
{
  "client_id": "my_device_123",
  "content": "写得真好！"
}
```

| 限制 | 说明 |
|------|------|
| content 长度 | 最长 500 字 |

**响应 200**:
```json
{
  "ok": true,
  "comment": { "id": 1, "content": "写得真好！", "created_at": "2026-01-01", "comment_count": 1 }
}
```

---

## 8. 用户主页 (Profile)

| 方法 | 路径 | 鉴权 | 说明 |
|------|------|------|------|
| GET | `/api/profile/me` | Bearer | 我的主页 |
| PUT | `/api/profile/me` | Bearer | 编辑资料 |
| GET | `/api/profile/{user_id}` | 可选 | 作者公开主页 |

### GET /api/profile/me

**响应 200**:
```json
{
  "nickname": "小兔",
  "avatar": "🐰",
  "bio": "今天也在认真生活",
  "interests": "日记,生活",
  "following_count": 5,
  "follower_count": 10,
  "public_diary_count": 20,
  "created_at": "2026-01-01"
}
```

### PUT /api/profile/me

**请求体**:
```json
{
  "nickname": "新昵称",
  "avatar": "🐱",
  "bio": "新的简介",
  "interests": "日记,摄影"
}
```

**响应 200**: `{"ok": true}`

### GET /api/profile/{user_id}

**响应 200**: 包含用户公开信息 + `is_following` + `following_count` + `follower_count` + 公开日记列表

---

## 9. 关注 (Follow)

| 方法 | 路径 | 鉴权 | 说明 |
|------|------|------|------|
| POST | `/api/users/{user_id}/follow` | Bearer | 关注 |
| DELETE | `/api/users/{user_id}/follow` | Bearer | 取消关注 |
| GET | `/api/users/{user_id}/follow-status` | 可选 | 关注状态 |
| GET | `/api/me/following` | Bearer | 我的关注 |
| GET | `/api/me/followers` | Bearer | 我的粉丝 |
| GET | `/api/me/following-feed` | Bearer | 关注动态 |

### POST /api/users/{user_id}/follow

**响应 200**:
```json
{
  "ok": true,
  "following": true,
  "already_followed": false,
  "follower_count": 1
}
```

**错误**: 自关注 400，拉黑限制 403

### GET /api/users/{user_id}/follow-status

**响应 200**:
```json
{
  "following": true,
  "follower_count": 10,
  "following_count": 5
}
```

### GET /api/me/following-feed

关注用户的公开日记动态，分页。

**查询参数**: `?page=1&page_size=10`

---

## 10. 通知 (Notification)

所有接口需 Bearer Token。

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/notifications` | 通知列表 |
| GET | `/api/notifications/unread-count` | 未读数 |
| POST | `/api/notifications/{id}/read` | 标记已读 |
| POST | `/api/notifications/read-all` | 全部已读 |
| DELETE | `/api/notifications/{id}` | 删除 |

### GET /api/notifications

**查询参数**: `?page=1&page_size=20&unread_only=true`

**响应 200**:
```json
{
  "items": [
    {
      "id": 1,
      "type": "follow",
      "title": "新的关注",
      "body": "关注了你",
      "is_read": false,
      "actor": { "id": 2, "nickname": "Alice", "avatar": "🌸" },
      "target_type": "user",
      "target_id": 2,
      "created_at": "2026-01-01"
    }
  ],
  "total": 10,
  "page": 1,
  "page_size": 20
}
```

通知类型: `follow`, `public_diary_like`, `public_diary_comment`, `greet`, `message`, `treehole_hug`, `treehole_reply`, `treehole_reply_like`

---

## 11. 打招呼 (Greet)

所有接口需 Bearer Token。

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/greet/requests` | 发起打招呼 |
| GET | `/api/greet/status/{user_id}` | 打招呼状态 |
| GET | `/api/greet/requests/received` | 收到的申请 |
| GET | `/api/greet/requests/sent` | 发出的申请 |
| GET | `/api/greet/requests/{id}` | 申请详情 |
| POST | `/api/greet/requests/{id}/accept` | 同意 |
| POST | `/api/greet/requests/{id}/reject` | 拒绝 |
| POST | `/api/greet/requests/{id}/cancel` | 取消 |
| GET | `/api/greet/pending-count` | 待处理数 |

### POST /api/greet/requests

**请求体**:
```json
{
  "receiver_id": 2,
  "message": "你好，喜欢你的日记！"
}
```

**响应 200**: `{"ok": true, "id": 1, "status": "pending"}`

**响应 400**: 自打招呼 `{"detail": "不能向自己打招呼"}`

**响应 403**: 被拉黑 `{"detail": "无法操作"}`

### GET /api/greet/requests/received

**查询参数**: `?status=pending` (可选: pending, accepted, rejected)

### POST /api/greet/requests/{id}/accept

同意后自动建立私信会话。

**响应 200**: `{"ok": true, "status": "accepted"}`

---

## 12. 私信 (Message)

所有接口需 Bearer Token。发消息需要双方已通过打招呼建立关系。

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/messages/conversations` | 会话列表 |
| POST | `/api/messages/conversations` | 创建会话 |
| GET | `/api/messages/conversations/{id}/messages` | 消息列表 |
| POST | `/api/messages/conversations/{id}/messages` | 发送消息 |
| POST | `/api/messages/conversations/{id}/read` | 标记已读 |
| GET | `/api/messages/unread-count` | 未读数 |

### POST /api/messages/conversations

**请求体**: `{"user_id": 2}`

**响应 200**:
```json
{
  "ok": true,
  "conversation": { "id": 1, "user1_id": 1, "user2_id": 2 }
}
```

**响应 403**: 未建立关系或被拉黑

### POST /api/messages/conversations/{id}/messages

**请求体**: `{"content": "Hello!"}`

**响应 200**:
```json
{
  "ok": true,
  "message": { "id": 1, "content": "Hello!", "sender_id": 1, "created_at": "..." }
}
```

### GET /api/messages/conversations/{id}/messages

**查询参数**: `?page=1&page_size=30`

**响应 200**:
```json
{
  "items": [
    { "id": 1, "sender_id": 1, "receiver_id": 2, "content": "Hello!", "is_read": false, "created_at": "..." }
  ],
  "total": 10,
  "page": 1,
  "page_size": 30
}
```

---

## 13. 安全 (Safety)

所有接口需 Bearer Token。

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/users/{user_id}/block` | 拉黑 |
| DELETE | `/api/users/{user_id}/block` | 解除拉黑 |
| GET | `/api/users/{user_id}/block-status` | 拉黑状态 |
| GET | `/api/me/blocked-users` | 我的拉黑列表 |
| POST | `/api/reports` | 提交举报 |
| GET | `/api/reports/my` | 我的举报 |

### POST /api/users/{user_id}/block

**请求体**: `{"reason": "骚扰"}` (可选)

**响应 200**:
```json
{
  "ok": true,
  "blocked": true,
  "already_blocked": false
}
```

**响应 400**: 自拉黑 `{"detail": "不能拉黑自己"}`

### DELETE /api/users/{user_id}/block

**响应 200**: `{"ok": true, "blocked": false}`

### POST /api/reports

**请求体**:
```json
{
  "target_type": "user",
  "target_id": 2,
  "reason": "harassment",
  "description": "详细描述"
}
```

| 参数 | 说明 |
|------|------|
| target_type | `user` / `diary` / `comment` / `treehole` |
| reason | `harassment` / `spam` / `inappropriate` / `other` |

**响应 200**: `{"ok": true, "id": 1, "status": "pending"}`

**响应 400**: 无效的 target_type 或 reason

### GET /api/reports/my

**响应 200**: 举报记录数组

---

## 14. 开发工具 (Dev)

仅在 `ENVIRONMENT=development` 时可用。

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/dev/seed` | 旧版种子数据 (3 条公开日记) |
| POST | `/api/dev/seed-demo` | 完整演示数据生成 |

### POST /api/dev/seed-demo

生成完整演示数据：4 个用户、18+ 篇日记、8 个胶囊、4 个关注、3 个点亮、4 条评论、3 个打招呼、1 个会话 (3 条消息)、1 个拉黑、2 个举报、通知若干。

**响应 200**:
```json
{
  "ok": true,
  "users": 4,
  "diaries": 18,
  "capsules": 8,
  "follows": 4,
  "likes": 3,
  "comments": 4,
  "greet_requests": 3,
  "conversations": 1,
  "messages": 3,
  "blocks": 1,
  "reports": 2,
  "notifications": 10
}
```

**响应 403**: `{"detail": "仅在开发环境可用"}`

---

## 15. WebSocket 实时推送

> WebSocket 连接为 **单机内存模式**，适合本地演示。多进程/多实例部署可扩展 Redis Pub/Sub。

### 连接

```
GET /ws/messages?token=<jwt_token>
```

**鉴权**: 必须携带有效 JWT token 作为查询参数。token 无效或过期时关闭连接（code 1008）。

**心跳**: 客户端发送 `{"type": "ping"}`，服务端回复 `{"type": "pong", "ts": "..."}`。

### 推送事件

服务端主动推送到对应 `user_id` 的所有连接：

| type | 触发时机 | 接收方 |
|------|----------|--------|
| `new_message` | REST 发送消息后 | 接收方 |
| `message_sent` | REST 发送消息后 | 发送方（确认） |
| `message_unread_count_update` | 未读数变化 | 接收方 |
| `new_notification` | 新通知创建 | 通知接收方 |
| `notification_unread_count_update` | 通知未读数变化 | 通知接收方 |
| `pong` | 响应 ping | 请求方 |

**new_message payload**:
```json
{
  "type": "new_message",
  "conversation_id": 1,
  "message": {
    "id": 123,
    "conversation_id": 1,
    "sender_id": 2,
    "receiver_id": 1,
    "content": "你好呀",
    "is_read": false,
    "created_at": "2026-05-04 20:30:00"
  },
  "conversation": {
    "id": 1,
    "last_message": "你好呀",
    "last_message_at": "2026-05-04 20:30:00"
  }
}
```

**降级**: WebSocket 断开时，原 HTTP REST 私信接口完全可用。离线用户通过 HTTP 拉取历史消息补偿。

---

## 通用错误码

| 状态码 | 说明 |
|--------|------|
| 200 | 成功 |
| 400 | 请求参数错误 |
| 401 | 未登录 / Token 过期 |
| 403 | 权限不足 (拉黑限制 / 非本人操作) |
| 404 | 资源不存在 |
| 409 | 冲突 (用户名已存在) |
| 422 | 请求体校验失败 |
| 500 | 服务器内部错误 |
