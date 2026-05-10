# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概览

**Echo — 治愈系智能日记**，全栈双端应用：
- `journal_develop_web/` — Web 版：FastAPI + SQLite + 原生 JS SPA + Tailwind CSS
- `apk/` — 移动端：Flutter + Riverpod，支持 Android / iOS / Web / Desktop

两个子项目各有独立的 `CLAUDE.md`，包含各自详细的技术文档和调试流程。

## 根目录文件

| 文件 | 说明 |
|------|------|
| `apk/build.bat` | Android APK 构建脚本 |
| `journal_develop_web/database.py` | Web 后端数据库（已被 git 删除，需确保后端运行时不依赖） |

## 子项目 CLAUDE.md

| 路径 | 覆盖范围 |
|------|---------|
| `journal_develop_web/CLAUDE.md` | Web 后端架构、API 路由、数据库 Schema、前端 JS 模块、调试指南 |
| `apk/CLAUDE.md` | Flutter 调试流程、bug 修复记录、Web 版作为参考实现 |

## Flutter ↔ Web 调试原则

**任何 Flutter 端的功能 bug，先去 `journal_develop_web/` 找对应功能的正确写法。**

Web 版是参考实现（reference implementation），所有功能的预期行为以 Web 端为准。

### 快速对应关系

| Web 端 | Flutter 端 |
|--------|-----------|
| `templates/index.html` | `apk/lib/screens/` |
| `static/js/api.js` | `apk/lib/services/` |
| `static/js/components.js` | `apk/lib/widgets/` |
| `models/schemas.py` | `apk/lib/models/` |
| `routers/*.py` | `apk/lib/api/endpoints/` |
| `services/*.py` | `apk/lib/services/` |
| `database.py` | （后端 — 权威数据源） |

## 网络代理

在需要连接外网时使用 Clash 代理：

```bash
HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 <command>
```

## GStack Skill 自动路由规则

在开始中等或大型任务前，根据任务类型自动选择 Skill，不需要每次询问。

### 可用 Skill

- `/plan-ceo-review`：产品价值、功能取舍、需求优先级、MVP 范围、用户价值和差异化
- `/plan-design-review`：UI/UX、页面布局、交互流程、视觉层级、移动端体验
- `/plan-eng-review`：工程实现、后端逻辑、前端状态管理、API、数据库、权限认证、架构、边界情况、测试
- `/plan-devex-review`：README、API 文档、数据库文档、部署说明、开发者体验
- `/open-gstack-browser`：真实浏览器测试、页面点击、控制台调试、截图检查、CSS/布局验证

### 使用顺序

#### 1. 完整新功能
`/plan-ceo-review` → `/plan-design-review` → `/plan-eng-review` → `/open-gstack-browser`

#### 2. 页面改版或 UI 功能
`/plan-design-review` → `/plan-eng-review` → `/open-gstack-browser`

#### 3. Bug 修复或工程问题
`/plan-eng-review` → `/open-gstack-browser`

#### 4. 纯后端或纯工程实现
`/plan-eng-review`

#### 5. 文档和项目展示
`/plan-eng-review` → `/plan-devex-review`

#### 6. 只需要真实页面验证
`/open-gstack-browser`

#### 7. 简单任务不使用 skill
一行代码修改、简单解释、单个报错说明等小任务，直接处理。

### 执行要求

中大型代码修改前，先明确：需求目标、影响文件、前后端接口关系、数据库影响、数据流和调用链、权限和状态管理、可能副作用、需要补充的测试。
根据任务类型自动选择 Skill，不要问是否使用。

## 行为偏好

### 执行命令前必须说明目的

执行任何 CLI / Bash / Shell 命令前，必须先用中文说明这条命令要做什么、为什么要执行，等用户确认后再执行（除非是很简单的只读操作如 `ls`、`git status`）。

例外：纯读操作如 `ls`、`pwd`、`git status`、`git log`、`git diff`、`find`、`grep`、`glob`、`cat`、read 文件内容、`curl`、web fetch 读取网页（GET 类）不需要事先说明，可直接执行。

**原因：** 用户不是技术人员，需要知道每条命令的意图才能判断是否允许执行。

## 计算表格面积的流程

收到 Excel 表格时：

1. **确认列** — 问用户哪列是宽，哪列是长
2. **确认单位** — 默认毫米（mm）
3. **计算** — 总面积 = Σ(宽 × 长)
4. **换算** — mm² ÷ 1,000,000 = m²

