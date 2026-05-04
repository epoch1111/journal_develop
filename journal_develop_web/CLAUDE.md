# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概览

Echo（治愈系智能日记）— 全栈 Web 应用。用户注册/登录后记录心情 + 文字 → 后端 Mock AI 进行情绪分析和事件总结 → 存入 SQLite → 前端以时间线展示。支持时光胶囊（定时解锁）、陌生人树洞、公开日记广场（同频发现）、用户关注系统、多图上传、私信实时推送（WebSocket 单机内存模式）等社交雏形功能。

## 核心命令

```bash
# 启动开发服务器（必须使用 conda 环境）
E:\Anaconda\envs\journal_develop\python.exe -m uvicorn main:app --reload --host 0.0.0.0 --port 8000

# 安装新依赖
E:\Anaconda\envs\journal_develop\python.exe -m pip install <package>
# 同步 requirements.txt
E:\Anaconda\envs\journal_develop\python.exe -m pip install -r requirements.txt

# 安装 bcrypt（注意版本兼容性）
E:\Anaconda\envs\journal_develop\python.exe -m pip install bcrypt==4.0.1
```

- 启动后访问 `http://localhost:8000/docs` 查看 FastAPI Swagger 文档
- 数据库文件 `echo.db` 在项目根目录自动创建，已启用 WAL 模式
- 服务重启前需要 `taskkill //F //IM python.exe` 杀掉所有残留 Python 进程
- Windows 也可直接双击 `start.bat`，macOS/Linux 运行 `./start.sh`
- 生成演示数据：`curl -X POST http://localhost:8000/api/dev/seed-demo`
- 全量回归测试：`python test_all.py`（需服务运行或使用 TestClient 模式，151 用例）
- 评论线程测试：`python test_comment_threading.py`（需服务运行，33 用例）
- 树洞线程测试：`python test_treehole_threading.py`（需服务运行，36 用例）
- 可见性边界测试：`python test_visibility_boundaries.py`（需服务运行，47 用例）
- 安全系统测试：`python test_safety.py`（需服务运行，61 用例）

## 技术架构

- **后端**: Python 3.11 + FastAPI，入口 `main.py`
- **数据库**: SQLite，通过 `database.py` 封装所有操作（`sqlite3.Row` → dict）
- **认证**: JWT Bearer Token（`python-jose`）+ bcrypt 密码哈希（`passlib` + `bcrypt==4.0.1`），7 天过期
- **前端**: 纯 HTML + Tailwind CSS CDN + Lucide Icons CDN + 原生 JS，全部写在 `templates/index.html` 中
- **模板**: FastAPI 直接读取 `templates/index.html` 返回，无模板引擎
- **静态文件**: 挂载在 `/static`，目录 `static/js/` 中按职责拆分为 `utils.js`、`api.js`、`components.js`
- **架构**: 三层分离 — routers（路由）→ services（业务逻辑）→ database（数据访问）
- **实时推送**: WebSocket 单机内存模式（`services/websocket_manager.py`），在线用户收到实时消息/通知推送，离线用户通过 HTTP 拉取补偿。适合本地演示，多实例部署需扩展 Redis Pub/Sub。

## 项目结构

```
├── main.py                    # FastAPI 入口，注册所有路由
├── database.py                # 数据库初始化 + 所有 SQL 操作
├── config.py                  # 心情色映射、AI 人格预设、JWT 配置
├── echo.db                    # SQLite 数据库文件（运行时生成）
├── requirements.txt
├── models/
│   └── schemas.py             # Pydantic 请求/响应模型
├── services/
│   ├── diary_service.py       # 日记 CRUD + 胶囊遮罩逻辑
│   ├── public_diary_service.py # 公开日记广场 + 点亮 + 评论
│   ├── profile_service.py     # 用户主页 + 作者主页（含关注统计）
│   ├── follow_service.py      # 关注/取消关注/关注列表/关注动态
│   ├── greet_service.py       # 打招呼/同意/拒绝/取消
│   ├── message_service.py     # 私信会话/发送消息/已读标记
│   ├── notification_service.py # 通知增删改查
│   ├── safety_service.py      # 拉黑/举报/安全检查
│   └── auth_service.py        # 注册/登录/JWT 生成与解析
├── routers/
│   ├── auth.py                # 认证接口（register/login/me）
│   ├── diary.py               # 日记/胶囊/树洞/统计接口
│   ├── analyze.py             # Mock AI 分析接口
│   ├── upload.py              # 图片上传接口
│   ├── public_diary.py        # 公开日记广场接口
│   ├── profile.py             # 用户主页接口
│   ├── follow.py              # 关注系统接口
│   ├── notification.py        # 通知中心接口
│   ├── greet.py               # 打招呼系统接口
│   ├── message.py             # 私信系统接口
│   ├── safety.py              # 安全中心接口（拉黑/举报）
│   ├── dev.py                 # 开发辅助接口（旧 seed）
│   └── seed_demo.py           # 演示数据生成接口（新 seed-demo）
├── static/js/
│   ├── utils.js               # 纯函数库（formatDate, escapeHtml, compressImage 等）
│   ├── api.js                 # API 通信层（window.EchoAPI，58 个方法）
│   └── components.js          # 组件渲染（createDiaryCard, renderDiaryCardInner, renderMoodStats）
├── templates/
│   └── index.html             # 完整单页面前端
├── docs/
│   ├── API.md                 # 完整 API 文档（15 模块）
│   └── DATABASE.md            # 数据库设计文档（12 张表）
├── test_all.py                # 全量回归测试（15 类，80+ 用例）
├── test_safety.py             # 安全系统手动测试
└── uploads/                   # 图片上传目录（运行时生成）
```

## 数据库 Schema

### 表 `diaries`

| 字段 | 类型 | 说明 |
|---|---|---|
| id | INTEGER PK AUTOINCREMENT | 主键 |
| created_at | TEXT NOT NULL | `YYYY-MM-DD HH:MM:SS` |
| mood | TEXT NOT NULL | 心情 emoji |
| content | TEXT NOT NULL | 日记正文 |
| ai_summary | TEXT DEFAULT '' | AI 摘要 |
| ai_message | TEXT DEFAULT '' | AI 治愈语 |
| tags | TEXT DEFAULT '' | 逗号分隔标签 |
| is_public | INTEGER DEFAULT 0 | 是否公开 |
| hug_count | INTEGER DEFAULT 0 | 抱抱计数（树洞用） |
| image_url | TEXT DEFAULT '' | 首张图片路径（向后兼容，与 diary_images 同步） |
| unlock_date | TEXT DEFAULT '' | 胶囊解锁日期，非空即为胶囊 |
| user_id | INTEGER DEFAULT 1 | 所属用户 |
| content_type | TEXT NOT NULL DEFAULT 'diary' | 内容类型: diary/treehole/capsule |

### 表 `users`

| 字段 | 类型 | 说明 |
|---|---|---|
| id | INTEGER PK AUTOINCREMENT | 主键 |
| username | TEXT | 登录用户名（唯一索引） |
| password_hash | TEXT | bcrypt 哈希密码 |
| email | TEXT DEFAULT '' | 邮箱 |
| nickname | TEXT DEFAULT '小兔' | 显示昵称 |
| avatar | TEXT DEFAULT '🐰' | 头像 emoji/URL |
| bio | TEXT DEFAULT '今天也在认真生活' | 个人简介 |
| interests | TEXT DEFAULT '日记,生活,小确幸' | 兴趣标签 |
| created_at | TEXT NOT NULL | 创建时间 |
| updated_at | TEXT DEFAULT '' | 更新时间 |

### 表 `public_diary_likes`

| 字段 | 说明 |
|---|---|
| diary_id + client_id | UNIQUE 约束防重复点亮 |

### 表 `public_diary_comments`

| 字段 | 说明 |
|---|---|
| diary_id, client_id, content, created_at | 评论存储，不返回 client_id |

### 表 `user_follows`

| 字段 | 说明 |
|---|---|
| follower_id + following_id | UNIQUE 约束防重复关注 |

### 表 `diary_images`

| 字段 | 说明 |
|---|---|
| diary_id | 关联日记（FK，级联删除） |
| image_url | 图片路径 |
| sort_order | 排序序号 |

### 表 `treehole_identities` — 树洞匿名身份

| 字段 | 说明 |
|---|---|
| treehole_id + identity_key | UNIQUE 约束，同一用户在同一树洞中匿名身份固定 |
| identity_key | `user:{user_id}` 或 `client:{client_id}` |
| anon_name / anon_avatar | 确定性生成，同 key 同 name（12 个预设名字/头像池） |

### 表 `treehole_replies` — 树洞匿名回复

| 字段 | 说明 |
|---|---|
| identity_id | 关联匿名身份 |
| parent_reply_id | 父回复 ID（线程回复） |
| root_reply_id | 根回复 ID（用于构建两级线程树） |
| reply_to_identity_id | 被回复的匿名身份（"回复 XXX" 显示） |
| user_id | 仅内部通知用，API 不返回 |

> 回复列表返回线程结构：一级回复包含 `replies[]` 子数组，最多两级。API 只返回 `anon_name`/`anon_avatar`，不暴露真实用户信息。

## 日记类型区分

| 类型 | content_type | 判断条件 |
|---|---|---|
| 普通日记 | diary | content_type='diary', unlock_date 为空 |
| 公开日记 | diary | content_type='diary', is_public=1, unlock_date 为空 |
| 私密日记 | diary | content_type='diary', is_public=0 |
| 时光胶囊 | capsule | content_type='capsule', unlock_date 非空 |
| 未到期胶囊 | capsule | unlock_date > 今天 → content 被 `_mask_capsule()` 屏蔽 |
| 已解锁胶囊 | capsule | unlock_date <= 今天 → 正常显示内容 |
| 树洞漂流瓶 | treehole | content_type='treehole'（随机获取，匿名返回） |

**核心安全规则**:
- `_mask_capsule()` 在所有日记读取路径中调用，确保未到期胶囊的 content 不泄露
- 树洞 API **一律不返回** `user_id`、`author_name`、`author_avatar`
- 公开广场仅查询 `content_type='diary' AND is_public=1 AND unlock_date 为空`
- 发现广场/关注动态/作者主页均排除 treehole 和 capsule 类型

## 完整 API 路由总览

### 页面
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/` | 返回 index.html（SPA） |

### 认证
| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| POST | `/api/auth/register` | 无 | 注册（返回 token） |
| POST | `/api/auth/login` | 无 | 登录（返回 token） |
| GET | `/api/auth/me` | Bearer | 获取当前用户信息 |

### 日记 CRUD
| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| POST | `/api/save` | Bearer | 保存日记（支持 image_urls 数组） |
| GET | `/api/diaries?date=YYYY-MM-DD` | Bearer | 日记列表（按日期过滤） |
| GET | `/api/diaries/date/{date}` | Bearer | 按日期查询（日历下钻） |
| GET | `/api/diaries/{id}` | Bearer | 日记详情（含 image_urls） |
| PUT | `/api/diaries/{id}` | Bearer | 编辑日记（支持 image_urls） |
| DELETE | `/api/diaries/{id}` | Bearer | 删除日记（级联删除图片） |

> 路由顺序注意：`/api/diaries/date/{date}` 必须在 `/api/diaries/{diary_id}` 之前。

### AI 分析 & 图片
| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| POST | `/api/analyze` | 无 | Mock AI 分析（支持 persona 参数：default/cheerful） |
| POST | `/api/upload` | 可选 | 图片上传（jpeg/png/gif/webp） |

### 统计
| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| GET | `/api/stats` | Bearer | 心情分布 + 日历数据 |
| GET | `/api/mood-stats` | Bearer | 顶部心情速览条 |

### 树洞
| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| POST | `/api/treehole` | Bearer | 匿名投递漂流瓶 |
| GET | `/api/treehole/random` | 无 | 随机漂流瓶（匿名） |
| GET | `/api/treehole/{id}` | 无 | 树洞详情（匿名，含线程回复列表） |
| POST | `/api/treehole/{id}/hug` | Bearer | 抱抱（需 treehole 类型） |
| DELETE | `/api/treehole/{id}/hug` | Bearer | 取消抱抱 |
| POST | `/api/treehole/{id}/reply` | Bearer | 匿名回复（支持 parent_reply_id 线程回复） |
| POST | `/api/treehole/replies/{id}/like` | Bearer | 点赞回复 |
| DELETE | `/api/treehole/replies/{id}/like` | Bearer | 取消点赞回复 |

### 公开日记广场
| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| GET | `/api/public/diaries` | 无 | 分页列表（支持 mood/tag/keyword/client_id 筛选，keyword 搜索正文/标签/昵称/AI字段/心情词） |
| GET | `/api/public/diaries/{id}` | 无 | 公开日记详情（含评论和 image_urls） |
| POST | `/api/public/diaries/{id}/like` | 无 | 点亮（client_id 去重） |
| DELETE | `/api/public/diaries/{id}/like` | 无 | 取消点亮 |
| POST | `/api/public/diaries/{id}/comments` | 无 | 发表评论（最长 500 字） |
| GET | `/api/public/diaries/{id}/comments` | 无 | 评论列表 |

### 用户主页
| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| GET | `/api/profile/me` | Bearer | 我的主页（含关注数/粉丝数） |
| PUT | `/api/profile/me` | Bearer | 编辑资料（nickname/avatar/bio/interests） |
| GET | `/api/profile/{user_id}` | 可选 | 作者公开主页（含 is_following/following_count/follower_count） |

### 关注系统
| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| POST | `/api/users/{user_id}/follow` | Bearer | 关注用户（防自关注/重复关注） |
| DELETE | `/api/users/{user_id}/follow` | Bearer | 取消关注（幂等） |
| GET | `/api/users/{user_id}/follow-status` | 可选 | 关注状态（following/follower_count/following_count） |
| GET | `/api/me/following` | Bearer | 我的关注列表（含最新公开日记预览） |
| GET | `/api/me/followers` | Bearer | 我的粉丝列表 |
| GET | `/api/me/following-feed` | Bearer | 关注动态（关注用户的公开日记，分页） |

### 通知中心
| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| GET | `/api/notifications` | Bearer | 通知列表（分页，支持 unread_only） |
| GET | `/api/notifications/unread-count` | Bearer | 未读通知数 |
| POST | `/api/notifications/{id}/read` | Bearer | 标记单条已读 |
| POST | `/api/notifications/read-all` | Bearer | 全部标记已读 |
| DELETE | `/api/notifications/{id}` | Bearer | 删除通知 |

### 打招呼系统
| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| POST | `/api/greet/requests` | Bearer | 发起打招呼（防自打招呼/拉黑限制） |
| GET | `/api/greet/status/{user_id}` | Bearer | 双方打招呼状态 |
| GET | `/api/greet/requests/received` | Bearer | 收到的申请（按 status 筛选） |
| GET | `/api/greet/requests/sent` | Bearer | 发出的申请 |
| GET | `/api/greet/requests/{id}` | Bearer | 申请详情 |
| POST | `/api/greet/requests/{id}/accept` | Bearer | 同意（自动建立私信会话） |
| POST | `/api/greet/requests/{id}/reject` | Bearer | 拒绝 |
| POST | `/api/greet/requests/{id}/cancel` | Bearer | 取消 |
| GET | `/api/greet/pending-count` | Bearer | 待处理数 |

### 私信系统
| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| GET | `/api/messages/conversations` | Bearer | 会话列表 |
| POST | `/api/messages/conversations` | Bearer | 创建会话（需已 accepted） |
| GET | `/api/messages/conversations/{id}/messages` | Bearer | 消息列表（分页） |
| POST | `/api/messages/conversations/{id}/messages` | Bearer | 发送消息（拉黑拦截） |
| POST | `/api/messages/conversations/{id}/read` | Bearer | 标记已读 |
| GET | `/api/messages/unread-count` | Bearer | 未读私信数 |

### 安全中心
| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| POST | `/api/users/{user_id}/block` | Bearer | 拉黑用户（防自拉黑） |
| DELETE | `/api/users/{user_id}/block` | Bearer | 解除拉黑 |
| GET | `/api/users/{user_id}/block-status` | Bearer | 拉黑状态查询 |
| GET | `/api/me/blocked-users` | Bearer | 拉黑列表 |
| POST | `/api/reports` | Bearer | 提交举报（user/diary/comment/treehole） |
| GET | `/api/reports/my` | Bearer | 我的举报记录 |

### 开发工具
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/api/dev/seed` | 插入 3 条公开日记种子数据（仅 development 环境） |
| POST | `/api/dev/seed-demo` | 完整演示数据（4 用户 + 全部社交数据，仅 dev） |

## 鉴权依赖注入

| 函数 | 用途 |
|---|---|
| `require_user` | 强制鉴权，未登录返回 401 |
| `get_optional_user` | 可选鉴权，未登录返回 None |
| `get_current_user` | 解析 token，注入 request.state.user |

## 前端模块说明

### 5 个底部 Tab 视图
1. **日记 (timeline)** — 日记列表 + 日历下钻 + 写日记入口
2. **发现 (discover)** — 公开日记广场，支持心情/标签/关键词筛选 + "全部/已关注"切换
3. **消息 (messages)** — 消息中心入口（私信/打招呼/通知），各入口带未读角标
4. **树洞 (treehole)** — 随机漂流瓶 + 抱抱 + 匿名回复
5. **我的 (profile)** — 个人主页 + 统计看板 + 时光胶囊（3 个子视图切换）

### 模态框/弹窗
- 写日记模态框（含 AI 分析、公开开关、多图上传）
- 时光胶囊创建模态框（含日期选择器、多图上传）
- 日记详情弹窗（含编辑模式、多图管理）
- 发现广场日记详情弹窗
- 登录/注册模态框
- 关注/粉丝列表弹窗
- 消息中心 / 打招呼中心 / 通知中心
- 安全中心（拉黑列表 / 举报记录）
- Toast 提示、纸飞机动画

### `static/js/utils.js`
纯函数：`formatDate()`, `escapeHtml()`, `compressImage()`, `calculateDaysLeft()`, `shakeCard()`, `getTodayStr()`, `enableHorizontalDragScroll(el)`

`enableHorizontalDragScroll(el)` 实现筛选条的鼠标拖拽横向滚动 + 滚轮横向滚动。关键设计：mousedown 时检测 `e.target.closest('button,input,textarea,select')` 跳过按钮点击，只在非交互元素上启动拖拽。

### `static/js/api.js` — `window.EchoAPI`（58 个方法）
核心设计：`_authFetch(url, options)` 自动附加 Bearer token，401 时清除 token 并弹出登录框。

**认证**: `register()`, `login()`, `fetchCurrentUser()`, `logout()`
**日记**: `fetchDiaries()`, `fetchDiariesByDate()`, `fetchDiaryById()`, `saveDiary()`, `updateDiary()`, `deleteDiary()`
**其他**: `fetchStats()`, `analyzeDiary()`, `uploadImage()`, `hugDiary()`, `fetchTreeholeRandom()`, `replyTreehole()`
**广场**: `fetchPublicDiaries()`, `fetchPublicDiaryById()`, `likePublicDiary()`, `unlikePublicDiary()`, `commentPublicDiary()`, `fetchPublicDiaryComments()`
**主页**: `fetchMyProfile()`, `updateMyProfile()`, `fetchUserProfile()`
**关注**: `followUser()`, `unfollowUser()`, `fetchFollowStatus()`, `fetchMyFollowing()`, `fetchMyFollowers()`, `fetchFollowingFeed()`
**通知**: `fetchNotifications()`, `fetchUnreadNotificationCount()`, `markNotificationRead()`, `markAllNotificationsRead()`, `deleteNotification()`
**打招呼**: `createGreetRequest()`, `fetchGreetStatus()`, `fetchReceivedGreetRequests()`, `fetchSentGreetRequests()`, `fetchGreetRequestDetail()`, `acceptGreetRequest()`, `rejectGreetRequest()`, `cancelGreetRequest()`, `fetchGreetPendingCount()`
**私信**: `fetchConversations()`, `startConversation()`, `fetchMessages()`, `sendMessage()`, `markConversationRead()`, `fetchMessageUnreadCount()`
**安全**: `blockUser()`, `unblockUser()`, `fetchBlockStatus()`, `fetchBlockedUsers()`, `createReport()`, `fetchMyReports()`

### `static/js/components.js`
- `createDiaryCard(d, options)` — 统一卡片工厂，自动判断 3 种状态（锁定胶囊/已解锁胶囊/普通日记）返回对应 DOM
- `renderDiaryCardInner(d)` — 普通日记卡片内部 HTML
- `renderMoodStats(diaries)` — 心情速览统计条

### `templates/index.html` 关键 JS 逻辑
- **图片系统**: `renderImageGallery(imageUrls, opts)` 根据图片数量生成 1/2/3 列画廊；写日记/编辑/胶囊三处均支持多图上传（`currentImageUrls`、`editImageUrls`、`capsuleImageUrls` 数组），删除使用 `splice` + 重新渲染缩略图
- **编辑模态框**: `openDetailModal()` → `loadDetail()` → `enterEditMode()`；每次进入编辑模式时 `cloneNode`+`replaceChild` 重置 file input 以清除旧事件监听器
- **关注交互**: `handleAuthorFollow()` 关注/取消切换；`openFollowList(type)` 关注/粉丝列表弹窗；发现页 `switchDiscoverFeed(type)` 全部/已关注切换
- **数据同步**: `currentDetailData` 缓存当前查看的日记对象，编辑保存后同时更新缓存和渲染视图
- **CDN 容错**: `lucide.createIcons()` 需 `typeof lucide !== 'undefined'` 守卫

## 关键约束

- **不要引入** 会员/VIP/真实 AI/复杂推荐算法/第三方登录/管理后台/WebSocket
- **保持** FastAPI + SQLite + 原生 JS + 单页面前端架构
- **不要** 大规模重构 UI，改动限定在功能需求范围内
- **路由顺序** 敏感：FastAPI 中更具体的路由路径必须在更泛化的路径之前
- **隐私**：`_mask_capsule()` 拦截未到期胶囊；公开列表 SQL 过滤 `is_public=1 AND unlock_date IS NULL`
- **CDN 容错**：lucide 调用需 `typeof lucide !== 'undefined'` 守卫
- **emoji/中文 curl 测试**：Windows 下 curl JSON 含中文会编码错误，需先写入文件再用 `-d @file`
- **bcrypt 版本**：必须使用 `bcrypt==4.0.1`，5.x 与 passlib 1.7.4 不兼容
- **图片压缩**：前端上传前必须通过 `compressImage()` 压缩（max 1200px, JPEG 0.8 quality），编辑模式同样需要
- **file input 事件**：每次进入编辑模式时需 `cloneNode(true)` + `replaceChild` 重置 file input，否则 `.click()` 触发在已脱离 DOM 的元素上
- **多图存储**：`diary_images` 表独立存储，`diaries.image_url` 仅缓存首图用于向后兼容，所有读路径批量查询 `diary_images` 返回 `image_urls` 数组
