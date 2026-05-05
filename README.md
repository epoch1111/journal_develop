# Echo — 治愈系智能日记

全栈日记应用，支持心情记录、AI 情绪分析、时光胶囊、陌生人树洞、公开日记广场、关注系统、打招呼/私信社交、安全中心。

## 项目结构

| 目录 | 说明 |
|---|---|
| `journal_develop_web/` | Web 版：FastAPI + SQLite + 原生 JS (SPA) + Tailwind CSS |
| `apk/` | 移动端：Flutter + Riverpod，支持 Android / iOS / Web / Desktop |

详见各目录下的 README。

## 快速开始

### Web 版

```bash
cd journal_develop_web
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

浏览器打开 `http://localhost:8000`

### 移动端

```bash
cd apk
flutter pub get
flutter run
```

### UI 模拟器

移动端交互预览（无需 Flutter 环境）：

```bash
# 直接用浏览器打开
start apk/web/simulator.html
```
