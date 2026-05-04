# Echo 日记 - 数据库文档

## 概述

- 数据库: SQLite 3
- 模式: WAL (Write-Ahead Logging)
- 文件: `echo.db` (项目根目录，运行时自动创建)
- ORM: 无，使用原生 SQL + `sqlite3.Row` → dict

## ER 关系

```
users (1) ─────< diaries (N)
  │                 │
  │                 ├──< diary_images (N)
  │                 ├──< treehole_replies (N)
  │                 │       └──< treehole_reply_likes (N)
  │                 └──< treehole_hugs (N)
  │
  ├──< user_follows (N) ──> users (N)
  ├──< notifications (N)
  ├──< greet_requests (N) ──> users (N)
  ├──< user_blocks (N) ──> users (N)
  ├──< reports (N)
  ├──< conversations (N)
  └──< private_messages (N)
```

---

## 表结构

### 1. users — 用户

| 字段 | 类型 | 约束 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | INTEGER | PK, AUTOINCREMENT | — | 用户 ID |
| username | TEXT | NOT NULL, UNIQUE INDEX | — | 登录用户名 |
| password_hash | TEXT | NOT NULL | — | bcrypt 哈希 |
| email | TEXT | — | '' | 邮箱 |
| nickname | TEXT | — | '小兔' | 显示昵称 |
| avatar | TEXT | — | '🐰' | 头像 emoji/URL |
| bio | TEXT | — | '今天也在认真生活' | 个人简介 |
| interests | TEXT | — | '日记,生活,小确幸' | 兴趣标签 (逗号分隔) |
| created_at | TEXT | NOT NULL | — | `YYYY-MM-DD HH:MM:SS` |
| updated_at | TEXT | — | '' | 更新时间 |

**索引**: `CREATE UNIQUE INDEX idx_users_username ON users(username)`

---

### 2. diaries — 日记/胶囊/树洞

| 字段 | 类型 | 约束 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | INTEGER | PK, AUTOINCREMENT | — | 日记 ID |
| created_at | TEXT | NOT NULL | — | `YYYY-MM-DD HH:MM:SS` |
| mood | TEXT | NOT NULL | — | 心情 emoji |
| content | TEXT | NOT NULL | — | 日记正文 |
| ai_summary | TEXT | — | '' | AI 摘要 |
| ai_message | TEXT | — | '' | AI 治愈语 |
| tags | TEXT | — | '' | 逗号分隔标签 |
| is_public | INTEGER | — | 0 | 是否公开 (0/1) |
| hug_count | INTEGER | — | 0 | 树洞抱抱计数 |
| image_url | TEXT | — | '' | 首张图片 (向后兼容) |
| unlock_date | TEXT | — | '' | 胶囊解锁日期 (`YYYY-MM-DD`) |
| user_id | INTEGER | NOT NULL | — | 所属用户 (FK → users) |
| content_type | TEXT | NOT NULL | 'diary' | 内容类型: `diary` / `treehole` / `capsule` |

**content_type 区分**:

| content_type | 创建入口 | 可见范围 | 广场 | 树洞 |
|-------------|---------|---------|------|------|
| diary | 日记 Tab | 自己 (私密) / 所有人 (公开) | 公开时可见 | 不可见 |
| treehole | 树洞 Tab | 匿名随机漂流 | 不可见 | 可见 |
| capsule | 胶囊入口 | 自己 (到期前屏蔽) | 不可见 | 不可见 |

**类型判断规则**:
- `content_type='diary'` — 普通日记/公开日记
- `content_type='treehole'` — 匿名树洞漂流瓶
- `content_type='capsule'` — 时光胶囊 (配合 unlock_date 判断到期)
- 公开广场: `content_type='diary' AND is_public=1 AND unlock_date 为空`
- 树洞随机: `content_type='treehole'` (按 RANDOM 排序)

---

### 3. diary_images — 日记图片

| 字段 | 类型 | 约束 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | INTEGER | PK, AUTOINCREMENT | — | — |
| diary_id | INTEGER | NOT NULL, FK | — | 关联日记 (CASCADE DELETE) |
| image_url | TEXT | NOT NULL | — | 图片路径 |
| sort_order | INTEGER | — | 0 | 排序序号 |

**外键**: `FOREIGN KEY (diary_id) REFERENCES diaries(id) ON DELETE CASCADE`

---

### 4. public_diary_likes — 点亮

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | INTEGER | PK, AUTOINCREMENT | — |
| diary_id | INTEGER | NOT NULL | 日记 ID |
| client_id | TEXT | NOT NULL | 客户端标识 |
| created_at | TEXT | NOT NULL | 点亮时间 |

**唯一约束**: `UNIQUE(diary_id, client_id)` — 同一客户端对同一日记只能点亮一次

---

### 5. public_diary_comments — 评论

| 字段 | 类型 | 约束 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | INTEGER | PK, AUTOINCREMENT | — | — |
| diary_id | INTEGER | NOT NULL | — | 日记 ID |
| client_id | TEXT | NOT NULL | — | 客户端标识 (不返回给前端) |
| content | TEXT | NOT NULL | — | 评论内容 (最长 500 字) |
| created_at | TEXT | NOT NULL | — | 评论时间 |
| user_id | INTEGER | — | NULL | 登录用户 ID (可选) |

---

### 6. user_follows — 关注关系

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | INTEGER | PK, AUTOINCREMENT | — |
| follower_id | INTEGER | NOT NULL | 关注者 |
| following_id | INTEGER | NOT NULL | 被关注者 |
| created_at | TEXT | NOT NULL | 关注时间 |

**唯一约束**: `UNIQUE(follower_id, following_id)` — 同一对用户只能关注一次

---

### 7. notifications — 通知

| 字段 | 类型 | 约束 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | INTEGER | PK, AUTOINCREMENT | — | — |
| user_id | INTEGER | NOT NULL | — | 接收者 |
| sender_id | INTEGER | NOT NULL | — | 触发者 |
| type | TEXT | NOT NULL | — | 通知类型 |
| target_type | TEXT | — | '' | 目标类型 |
| target_id | INTEGER | — | 0 | 目标 ID |
| title | TEXT | — | '' | 标题 |
| body | TEXT | — | '' | 正文 |
| is_read | INTEGER | — | 0 | 已读 (0/1) |
| created_at | TEXT | NOT NULL | — | 通知时间 |
| metadata | TEXT | — | '' | 扩展字段 |

**通知类型**:
- `follow` — 关注
- `public_diary_like` — 点亮公开日记
- `public_diary_comment` — 评论公开日记
- `greet` — 打招呼
- `message` — 私信
- `treehole_hug` — 树洞被抱抱
- `treehole_reply` — 树洞被回复
- `treehole_reply_like` — 树洞回复被点赞

---

### 8. greet_requests — 打招呼

| 字段 | 类型 | 约束 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | INTEGER | PK, AUTOINCREMENT | — | — |
| sender_id | INTEGER | NOT NULL | — | 发起者 |
| receiver_id | INTEGER | NOT NULL | — | 接收者 |
| message | TEXT | NOT NULL | — | 打招呼消息 |
| status | TEXT | NOT NULL | 'pending' | pending / accepted / rejected / cancelled |
| created_at | TEXT | NOT NULL | — | 发起时间 |
| updated_at | TEXT | — | '' | 处理时间 |

---

### 9. conversations — 会话

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | INTEGER | PK, AUTOINCREMENT | — |
| user1_id | INTEGER | NOT NULL | 用户 1 (较小 ID) |
| user2_id | INTEGER | NOT NULL | 用户 2 (较大 ID) |
| last_message | TEXT | — | 最后一条消息 |
| last_message_at | TEXT | — | 最后消息时间 |
| created_at | TEXT | NOT NULL | 创建时间 |
| updated_at | TEXT | — | 更新时间 |

**唯一约束**: `UNIQUE(user1_id, user2_id)` — 每对用户只有一个会话

**约束**: `user1_id < user2_id` (保证会话唯一性)

---

### 10. private_messages — 私信

| 字段 | 类型 | 约束 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | INTEGER | PK, AUTOINCREMENT | — | — |
| conversation_id | INTEGER | NOT NULL, FK | — | 会话 ID |
| sender_id | INTEGER | NOT NULL | — | 发送者 |
| receiver_id | INTEGER | NOT NULL | — | 接收者 |
| content | TEXT | NOT NULL | — | 消息内容 |
| is_read | INTEGER | — | 0 | 已读 (0/1) |
| created_at | TEXT | NOT NULL | — | 发送时间 |

---

### 11. user_blocks — 拉黑

| 字段 | 类型 | 约束 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | INTEGER | PK, AUTOINCREMENT | — | — |
| blocker_id | INTEGER | NOT NULL | — | 拉黑者 |
| blocked_id | INTEGER | NOT NULL | — | 被拉黑者 |
| reason | TEXT | — | '' | 拉黑原因 |
| created_at | TEXT | NOT NULL | — | 拉黑时间 |

**唯一约束**: `UNIQUE(blocker_id, blocked_id)`

**行为**: 拉黑后自动取消双向关注

---

### 12. reports — 举报

| 字段 | 类型 | 约束 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | INTEGER | PK, AUTOINCREMENT | — | — |
| reporter_id | INTEGER | NOT NULL | — | 举报者 |
| target_type | TEXT | NOT NULL | — | 举报类型 |
| target_id | INTEGER | NOT NULL | — | 目标 ID |
| target_user_id | INTEGER | — | NULL | 被举报用户 ID |
| reason | TEXT | NOT NULL | — | 举报原因 |
| description | TEXT | — | '' | 详细描述 |
| status | TEXT | — | 'pending' | pending / reviewed / resolved |
| created_at | TEXT | NOT NULL | — | 举报时间 |

**target_type 枚举**: `user`, `diary`, `comment`, `treehole`

**reason 枚举**: `harassment`, `spam`, `inappropriate`, `other`

---

### 13. treehole_identities — 树洞匿名身份

| 字段 | 类型 | 约束 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | INTEGER | PK, AUTOINCREMENT | — | — |
| treehole_id | INTEGER | NOT NULL, FK | — | 关联树洞日记 (CASCADE DELETE) |
| identity_key | TEXT | NOT NULL | — | 唯一标识：`user:{user_id}` 或 `client:{client_id}` |
| anon_name | TEXT | NOT NULL | — | 匿名昵称（确定性生成，同 key 同 name） |
| anon_avatar | TEXT | NOT NULL | — | 匿名头像 emoji |
| created_at | TEXT | NOT NULL | — | 创建时间 |

**唯一约束**: `UNIQUE(treehole_id, identity_key)` — 同一用户在同一树洞中的匿名身份唯一且固定

> 匿名身份通过 `hash(identity_key) % len(name_pool)` 确定性分配，确保同一 key 在同一树洞中始终获得相同的匿名名。

### 14. treehole_replies — 树洞匿名回复

| 字段 | 类型 | 约束 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | INTEGER | PK, AUTOINCREMENT | — | — |
| diary_id | INTEGER | NOT NULL, FK | — | 关联树洞日记 (CASCADE DELETE) |
| user_id | INTEGER | — | NULL | 回复者 ID（内部用于通知，不对外暴露） |
| identity_id | INTEGER | — | NULL | 关联匿名身份 ID |
| content | TEXT | NOT NULL | — | 匿名回复内容 |
| parent_reply_id | INTEGER | — | NULL | 父回复 ID（线程回复） |
| root_reply_id | INTEGER | — | NULL | 根回复 ID（用于构建线程树） |
| reply_to_identity_id | INTEGER | — | NULL | 被回复的匿名身份 ID（用于 "回复 XXX" 显示） |
| created_at | TEXT | NOT NULL | — | 回复时间 |

**外键**: `FOREIGN KEY (diary_id) REFERENCES diaries(id) ON DELETE CASCADE`

> 回复对外完全匿名，`user_id` 仅内部用于通知推送，API 响应中不返回。回复列表返回线程结构：一级回复包含 `replies[]` 子数组，最多两级。

### 15. treehole_reply_likes — 树洞回复点赞

| 字段 | 类型 | 约束 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | INTEGER | PK, AUTOINCREMENT | — | — |
| reply_id | INTEGER | NOT NULL | — | 关联回复 ID |
| user_id | INTEGER | NOT NULL | — | 点赞者 ID |
| created_at | TEXT | NOT NULL | — | 点赞时间 |

**唯一约束**: `UNIQUE(reply_id, user_id)` — 同一用户对同一回复只能点赞一次

---

## 隐私设计

1. **日记隔离**: 所有日记查询必须传 `user_id`，私密日记仅所有者可见
2. **胶囊遮罩**: `_mask_capsule()` 在服务层拦截，未到期胶囊的 `content` 被替换为提示信息
3. **拉黑双向**: `is_blocked_between(a, b)` 检查双向，任一方拉黑即阻断互动
4. **举报匿名**: 举报列表仅举报者本人可见，不暴露举报者身份给被举报者
5. **评论脱敏**: `client_id` 在返回时过滤，不暴露设备标识
6. **密码安全**: bcrypt 哈希存储，不保存明文

## 数据访问层

`database.py` 封装所有 SQL 操作，使用 `get_connection()` 获取连接（WAL 模式），返回 `sqlite3.Row` 对象（可用 `dict(row)` 或 `row["field"]` 访问）。

关键模式：
```python
conn = get_connection()
rows = conn.execute("SELECT ...", params).fetchall()
conn.close()
# 或使用 context manager 风格
```

所有写操作需显式 `conn.commit()`。
