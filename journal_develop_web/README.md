# Echo — 治愈系智能日记

> **当前版本**：Web 版 | **计划中**：Android 应用版

全栈 Web 日记应用，支持心情记录、AI 情绪分析、时光胶囊、陌生人树洞、公开日记广场、关注系统、打招呼/私信社交、安全中心。

**技术栈**: Python 3.11 + FastAPI + SQLite + 原生 JS (SPA) + Tailwind CSS

## 目录

1. [功能一览](#功能一览)
2. [快速启动](#快速启动)
3. [演示账号](#演示账号)
4. [项目结构](#项目结构)
5. [技术架构](#技术架构)
6. [数据库设计](#数据库设计)
7. [API 文档](#api-文档)
8. [前端架构](#前端架构)
9. [安全设计](#安全设计)
10. [测试](#测试)
11. [开发规范](#开发规范)
12. [演示流程](#演示流程)

## 功能一览

| 模块 | 功能 | 鉴权 |
|------|------|------|
| 认证 | 注册 / 登录 / JWT Token | 无 |
| 日记 CRUD | 创建 / 编辑 / 删除 / 按日期查看 / 日历下钻 | Bearer |
| AI 分析 | Mock AI 情绪分析 + 治愈语 + 标签提取 (支持 default/cheerful 人格) | 无 |
| 图片上传 | 多图上传 + 画廊展示 (1/2/3 列自适应) | Bearer |
| 统计 | 心情分布图 + 日历热力图 + 心情速览条 | Bearer |
| 时光胶囊 | 定时解锁日记 (到期前内容屏蔽) | Bearer |
| 树洞 | 随机漂流瓶 + 抱抱 + 匿名回复 | 无 |
| 公开广场 | 心情/标签/关键词搜索（支持中文心情词+昵称+AI字段）+ 分页 + 点亮 + 评论 | 可选 |
| 关注系统 | 关注/取关 + 关注动态 + 关注/粉丝列表 | Bearer |
| 用户主页 | 个人资料编辑 + 公开主页 + 关注统计 | Bearer/可选 |
| 通知中心 | 实时通知 + 已读/未读 + 批量操作 | Bearer |
| 打招呼 | 发起/同意/拒绝/取消 + 状态查询 | Bearer |
| 私信 | 会话列表 + 发送消息 + 历史记录 + 已读标记 | Bearer |
| 安全中心 | 拉黑/解除拉黑 + 举报(用户/日记/评论/树洞) | Bearer |

### 底部导航结构

| Tab | 名称 | 内容 |
|-----|------|------|
| 📝 日记 | 时间线 | 日记列表 + 日历下钻 + 写日记入口 |
| 🔍 发现 | 发现同频 | 公开日记广场 + 全部/已关注切换 |
| 💬 消息 | 消息中心 | 私信入口 + 打招呼入口 + 通知入口 (含未读角标) |
| 🌳 树洞 | 树洞 | 随机漂流瓶 + 抱抱 + 回复 |
| 👤 我的 | 个人中心 | 主页 + 统计看板 + 时光胶囊 (子视图切换) |

## 快速启动

### Windows

双击运行 `start.bat` 或执行：

```bash
E:\Anaconda\envs\journal_develop\python.exe -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### macOS / Linux

```bash
chmod +x start.sh
./start.sh
```

### 访问

- 前端页面: http://localhost:8000
- API 文档: http://localhost:8000/docs (FastAPI Swagger)

### 环境要求

- Python 3.11+
- conda 环境 `journal_develop` (或自行安装依赖)
- 依赖见 `requirements.txt`

### 安装依赖

```bash
pip install -r requirements.txt
# 注意：bcrypt 需使用 4.0.1 版本，5.x 与 passlib 1.7.4 不兼容
pip install bcrypt==4.0.1
```

## 演示账号

运行 `POST /api/dev/seed-demo` 后可用以下账号登录：

| 用户名 | 密码 | 昵称 | 人设 |
|--------|------|------|------|
| `echo_1` | `password123` | 小兔 🐰 | 热爱生活的记录者 |
| `alice` | `password123` | Alice 🌸 | 喜欢旅行和阅读 |
| `bob` | `password123` | Bob 🐻 | 正在学习成长中 |
| `charlie` | `password123` | Charlie 🦊 | 喜欢摄影和城市观察 |

演示数据包含：日记、胶囊、关注、点亮、评论、打招呼、私信、通知等完整社交链路。

## 项目结构

```
├── main.py                    # FastAPI 入口
├── database.py                # 数据库初始化 + 数据访问层
├── config.py                  # 心情色映射 + AI 人格 + JWT 配置
├── requirements.txt           # Python 依赖
├── start.bat                  # Windows 一键启动
├── start.sh                   # macOS/Linux 一键启动
├── test_all.py                # 全量回归测试脚本
├── echo.db                    # SQLite 数据库 (运行时生成)
├── models/
│   └── schemas.py             # Pydantic 模型
├── services/
│   ├── ai_service.py          # Mock AI 分析
│   ├── auth_service.py        # 认证逻辑
│   ├── diary_service.py       # 日记 CRUD + 胶囊遮罩
│   ├── public_diary_service.py # 公开广场 + 点亮 + 评论
│   ├── profile_service.py     # 用户主页
│   ├── follow_service.py      # 关注系统
│   ├── greet_service.py       # 打招呼系统
│   ├── message_service.py     # 私信系统
│   ├── notification_service.py # 通知中心
│   └── safety_service.py      # 安全中心 (拉黑/举报)
├── routers/
│   ├── auth.py                # 认证路由
│   ├── diary.py               # 日记/胶囊/树洞/统计
│   ├── analyze.py             # AI 分析
│   ├── upload.py              # 图片上传
│   ├── public_diary.py        # 公开广场
│   ├── profile.py             # 用户主页
│   ├── follow.py              # 关注系统
│   ├── notification.py        # 通知中心
│   ├── greet.py               # 打招呼
│   ├── message.py             # 私信
│   ├── safety.py              # 安全中心
│   ├── dev.py                 # 开发辅助 (旧 seed)
│   └── seed_demo.py           # 演示数据生成
├── static/js/
│   ├── utils.js               # 工具函数
│   ├── api.js                 # API 通信层 (58 个方法)
│   └── components.js          # 组件渲染
├── templates/
│   └── index.html             # 单页面应用
├── docs/
│   ├── API.md                 # API 文档
│   └── DATABASE.md            # 数据库文档
└── uploads/                   # 图片上传目录
```

## 技术架构

### 后端

- **框架**: FastAPI 0.115
- **数据库**: SQLite (WAL 模式，`sqlite3.Row` → dict)
- **认证**: JWT Bearer Token (python-jose 3.3.0)，7 天过期
- **密码哈希**: bcrypt (passlib 1.7.4 + bcrypt 4.0.1)
- **架构**: 三层分离 — routers (路由) → services (业务逻辑) → database (数据访问)

### 前端

- **范式**: 原生 JS 单页面应用 (SPA)，无框架
- **样式**: Tailwind CSS CDN
- **图标**: Lucide Icons CDN
- **结构**: `templates/index.html` 包含全部 HTML/CSS/JS
- **模块化**: `static/js/` 下按职责拆分 (utils / api / components)
- **状态管理**: `localStorage` 存 token，全局变量存用户信息

## 数据库设计

共 12 张表，详见 [docs/DATABASE.md](docs/DATABASE.md)：

- `users` — 用户
- `diaries` — 日记/胶囊
- `diary_images` — 多图
- `public_diary_likes` — 点亮
- `public_diary_comments` — 评论
- `user_follows` — 关注
- `notifications` — 通知
- `greet_requests` — 打招呼
- `conversations` — 会话
- `private_messages` — 私信
- `user_blocks` — 拉黑
- `reports` — 举报

### 日记类型区分

| 类型 | 判断条件 |
|------|----------|
| 普通私密日记 | `unlock_date` 为空, `is_public=0` |
| 公开日记 | `unlock_date` 为空, `is_public=1` |
| 未到期胶囊 | `unlock_date > 今天` → 内容屏蔽, `locked=true` |
| 已解锁胶囊 | `unlock_date <= 今天` → 正常显示 |

## API 文档

完整 API 文档见 [docs/API.md](docs/API.md)。

共 15 个模块，50+ 个端点：

| # | 模块 | 端点数 | 鉴权 |
|---|------|--------|------|
| 1 | 认证 (Auth) | 3 | 无/Bearer |
| 2 | 日记 (Diary) | 7 | Bearer |
| 3 | AI 分析 (Analyze) | 1 | 无 |
| 4 | 图片上传 (Upload) | 1 | 可选 |
| 5 | 统计 (Stats) | 2 | Bearer |
| 6 | 树洞 (Treehole) | 3 | 无 |
| 7 | 公开广场 (Public) | 6 | 可选 |
| 8 | 用户主页 (Profile) | 3 | Bearer/可选 |
| 9 | 关注 (Follow) | 6 | Bearer/可选 |
| 10 | 通知 (Notification) | 5 | Bearer |
| 11 | 打招呼 (Greet) | 8 | Bearer |
| 12 | 私信 (Message) | 5 | Bearer |
| 13 | 安全 (Safety) | 6 | Bearer |
| 14 | 开发工具 (Dev) | 2 | 仅开发环境 |

## 前端架构

### 5 个 Tab 视图

底部固定导航，5 个 Tab 对应 5 个主视图。切换 Tab 时隐藏所有视图，仅显示当前视图。

### 模态框/弹窗

- 写日记模态框 (含 AI 分析、公开开关、多图上传)
- 时光胶囊创建模态框 (含日期选择器)
- 日记详情弹窗 (含编辑模式、多图管理)
- 发现广场日记详情弹窗
- 登录/注册模态框
- 关注/粉丝列表弹窗
- 消息中心 / 打招呼中心 / 通知中心
- Toast 提示

### JS 模块

- `static/js/utils.js` — 纯函数 (formatDate, escapeHtml, compressImage 等)
- `static/js/api.js` — `window.EchoAPI` (58 个方法，自动 Token 管理)
- `static/js/components.js` — 组件渲染 (createDiaryCard, renderMoodStats 等)

## 安全设计

- **密码**: bcrypt 哈希，不存储明文
- **认证**: JWT Bearer Token，7 天过期
- **日记隔离**: 所有日记查询按 `user_id` 过滤，他人无法查看私密日记
- **胶囊遮罩**: `_mask_capsule()` 在读取层拦截未到期胶囊内容
- **拉黑**: 双向检查 `is_blocked_between()`，拉黑后自动取消关注、禁止互动
- **举报**: 支持举报用户/日记/评论/树洞，reason 白名单校验
- **输入校验**: Pydantic 模型校验 + 评论 500 字限制
- **XSS 防护**: 前端 `escapeHtml()` 转义用户内容
- **CORS**: FastAPI 默认同源策略
- **环境隔离**: 开发工具接口仅 `ENVIRONMENT=development` 可用

## 测试

### 全量回归测试

```bash
python test_all.py
```

覆盖 15 个测试类别、80+ 个测试用例：
认证、日记 CRUD、公开广场、点亮、评论、通知、关注、打招呼、私信、拉黑、举报、胶囊、统计、树洞、回归。

### 安全系统测试

```bash
python test_safety.py
```

## 开发规范

- 路由顺序敏感：更具体的路径必须在更泛化的路径之前
- 日记查询路由：`/api/diaries/date/{date}` 在 `/api/diaries/{diary_id}` 之前
- bcrypt 版本：必须 4.0.1，5.x 不兼容
- Windows 下 curl JSON 含中文需写入文件再用 `-d @file`
- 前端 lucide 调用需 `typeof lucide !== 'undefined'` 守卫

## 演示流程

### 1. 启动服务

```bash
# Windows
start.bat

# macOS/Linux
./start.sh
```

### 2. 生成演示数据

```bash
curl -X POST http://localhost:8000/api/dev/seed-demo
```

或访问 http://localhost:8000/docs 调用 `POST /api/dev/seed-demo`

### 3. 演示路径

1. **注册/登录** — 使用 `echo_1 / password123` 登录
2. **日记列表** — 查看时间线，点击日历单元格下钻
3. **写日记** — 写一篇新日记，体验 AI 分析、图片上传
4. **时光胶囊** — 在"我的"Tab 切换到胶囊子视图，查看锁定/已解锁状态
5. **树洞** — 切换到树洞 Tab，随机浏览漂流瓶，抱抱 + 匿名回复
6. **发现广场** — 切换到发现 Tab，按心情/标签筛选，点亮 + 评论公开日记
7. **关注系统** — 点击作者头像进入主页，关注/取关
8. **消息中心** — 切换到消息 Tab，查看打招呼、私信、通知
9. **打招呼** — 向其他用户发起打招呼，体验同意/拒绝流程
10. **私信** — 在打招呼被接受后，发送私信
11. **安全中心** — 在"我的"Tab 进入安全中心，体验拉黑/举报
12. **统计看板** — 在"我的"Tab 切换到统计子视图
