# CLAUDE.md

## 遇到 Bug 时的第一原则

**任何 Flutter 端的功能 bug，先去 `F:\Interview_Project\journal_develop\journal_develop_web` 找对应功能的正确写法。**

Web 版本是参考实现（reference implementation），所有功能的预期行为以 `journal_develop_web` 为准，包括但不限于：

- API 调用方式（auth vs no-auth、字段名、响应解析路径）
- UI 交互模式（嵌套回复、递归渲染、按钮行为）
- 数据模型字段映射（JSON key → 属性名）

### 具体做法

1. 遇到 bug → 去 `journal_develop_web` 看对应代码
2. 对比 Flutter 端和 Web 端的差异
3. 以 Web 端的写法为准来修正 Flutter 端

### 关键文件对应关系

| Web 端 | Flutter 端 |
|---|---|
| `templates/index.html` | `apk/lib/screens/` |
| `static/js/api.js` | `apk/lib/services/` |
| `static/js/components.js` | `apk/lib/widgets/` |
| `models/schemas.py` | `apk/lib/models/` |
| `services/*.py` | `apk/lib/services/` |
| `routers/*.py` | `apk/lib/services/` (API 调用) |
| `database.py` | (backend — 权威数据源) |

### 常见模式（来自 Web 版）

1. **API 评论/回复**：Web 对所有评论操作使用 `_authFetch`（带 JWT）→ Flutter 应使用 `auth: true`
2. **嵌套回复**：Web 递归渲染所有回复（`renderCommentItem(c, isChild)`），且**每条**都有回复按钮 → Flutter 应递归渲染 `CommentTile`
3. **响应解析**：Web 的 `_authFetch` 返回原始 JSON，后端 Router 直接返回字典/数组 → Flutter 的 `ApiClient._handleResponse` 将数组包装为 `{"data": [...]}`
4. **树洞回复**：Web 发送 `parent_reply_id` + `reply_to_identity_id` → Flutter 应发送相同字段

---

## APK 调试流程（手机端日志抓取）

当 App 在真机上出现问题时，按以下流程排查：

### 第一步：安装含调试日志的 APK

```bash
# 1. 清除旧日志
"/f/Android/sdk/platform-tools/adb.exe" logcat -c

# 2. 构建并安装
cd "F:/Interview_Project/journal_develop/apk"
F:/flutter/bin/flutter.bat build apk --release
cp build/app/outputs/flutter-apk/app-release.apk echo_release.apk
"/f/Android/sdk/platform-tools/adb.exe" install -r echo_release.apk
```

### 第二步：触发问题后抓日志

```bash
# 方式一：实时过滤（推荐）
"/f/Android/sdk/platform-tools/adb.exe" logcat -s flutter | findstr KEYWORD

# 方式二：获取全部日志后本地过滤
"/f/Android/sdk/platform-tools/adb.exe" logcat -d flutter > log.txt
# 然后在 log.txt 中搜索
```

常用过滤关键词：
- `DISCOVER` — 发现页相关日志
- `DIARY` — 日记相关日志
- `Error|ERROR` — 错误信息
- `ClassCast` — 类型转换错误
- `Exception` — 异常信息

### 第三步：分析日志

**API 请求/响应正常但页面空白/灰色：**
```
DISCOVER URL: http://192.168.0.104:8000/api/public/diaries params={page: 1}
DISCOVER raw: {items: [{id: 130, ...}], has_more: true}
```
→ 数据返回正确，问题在渲染层。检查 Widget 的 build 方法是否有 `Expanded` 放错位置、条件渲染逻辑错误等。

**请求发出但无响应：**
```
DISCOVER URL: http://192.168.0.104:8000/api/public/diaries params={page: 1}
# 没有后续 raw 日志
```
→ 网络不通或后端无响应。检查手机能否访问该 IP、防火墙、后端服务是否运行。

**类型转换错误：**
```
java.lang.ClassCastException: Cannot cast java.lang.Boolean to java.util.ArrayList
```
→ Model 的 `fromJson` 字段类型不匹配。检查 model 中 `_toInt`、`_toBool` 等转换函数。

**一直转圈不跳转（SplashScreen 卡住）：**
→ `fetchCurrentUser()` 异常未捕获，或网络超时无响应。添加 5 秒超时保护：
```dart
await Future.any([
  ref.read(authProvider.notifier).fetchCurrentUser(),
  Future.delayed(const Duration(seconds: 5)),
]);
```

### 常见渲染错误

**`DiagnosticsProperty<void>` 异常：**
Flutter 内部错误，表示某个 Widget build 方法返回了 void 或类型不兼容。常见原因：
- `Expanded` 放在了 `Wrap` 或 `GridView` 的 children 中（`Expanded` 只能用在 `Row/Column/Flex` 里）
- `child` 参数传入了条件表达式（如 `condition ? Expanded(child) : SizedBox()`）

### 快速检查项

1. **网络连通性**：`curl http://<手机填的地址>:8000/api/public/diaries` 从电脑能否访问
2. **后端运行状态**：后端窗口是否显示 `Uvicorn running on`
3. **手机和电脑同一 WiFi**：局域网地址是否在同一网段
4. **防火墙**：电脑防火墙是否允许 8000 端口入站

---

## 执行权限说明

**用户说"好的，你直接执行"或"你自己运行"时，无需等待确认，直接执行命令即可。**

用户说"需要权限再问我"时，必须先询问用户获得批准才能执行危险操作（删除文件、改系统配置、git force 等）。

---

## 本次修复记录

### 2026-05-06 发现页灰色空白 + 私有日记评论失败

**问题 1：发现页灰色空白**
- 根因：`DiaryCard` 中把 `Expanded` 放在了 `Wrap` 的 children 里（`Expanded` 只能用在 `Row/Column/Flex` 中）
- 修复：将 `Expanded(child: Text(...))` 改为 `Padding(child: Text(...))`

**问题 2：私有日记点击后显示"日记不存在或不是公开日记"**
- 根因：`DiaryDetailScreen` 在 `isPublic: false` 分支里调用了 `DiscoverService().fetchComments()`，这是公开日记的评论 API
- 修复：私有日记不调用公开评论 API，设为空列表

**问题 3：公开日记评论失败**
- 根因：`commentOnDiary` 异常只通过 SnackBar 显示，无日志
- 修复：添加 `print('COMMENT ERROR: $e')` 日志
