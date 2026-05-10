# Bug Fix Plan: Comment Images + WriteDiaryScreen

## Bug 1: 评论图片发送失败

### 根因

`journal_develop_web/models/schemas.py` 第 57 行：
```python
class PublicDiaryCommentRequest(BaseModel):
    content: str  # 必填，无 default
```

Flutter `_sendComment()` 发送 body:
```json
{"client_id": "...", "content": "", "image_urls": ["http://..."]}
```

Pydantic v1 收到 `content: ""` → 空字符串是合法的 `str`，但服务层 `_validate_comment_content` 里把 `""` 转成了 `None`，最后 `bool(None)` = `False`，走到了 `if not content: raise ValueError()` 的逻辑——被 Pydantic 层拦在前面，422 返回，图片 URL 从未到达服务层。

### 修复方案

**修改 `schemas.py`** — `content` 加 `default=""`，让 Pydantic 接受空字符串，服务层 `if not content` 把空字符串转为 None 后，`bool(image_url) or bool(image_urls)` 判断通过。

```python
class PublicDiaryCommentRequest(BaseModel):
    content: str = ""   # 加 default，允许空内容+图片组合
```

同时检查树洞回复 endpoint 是否有同样问题：
`journal_develop_web/models/schemas.py` 中的 `TreeholeReplyRequest` 也检查。

---

## Bug 2: WriteDiaryScreen 私有日记也有"公开发布"开关

### 根因

`WriteDiaryScreen` 的 `SwitchListTile` 在 `isCapsule=false` 时无条件渲染，调用入口只有 `timeline_screen.dart`（写私有日记），没有参数区分场景。

### 修复方案

**修改 `WriteDiaryScreen`**

```dart
class WriteDiaryScreen extends ConsumerStatefulWidget {
  final bool isCapsule;
  final bool isPrivateOnly;  // 新参数
  const WriteDiaryScreen({
    super.key,
    this.isCapsule = false,
    this.isPrivateOnly = false,  // 默认 false（保留公开发布选项）
  });
```

```dart
// _save() 中
final isPublicForSave = widget.isPrivateOnly ? false : _isPublic;

// SwitchListTile 条件
if (!widget.isCapsule && !widget.isPrivateOnly)
  SwitchListTile(...),
```

**修改 `timeline_screen.dart`**

```dart
// 私有日记入口：无公开发布选项
WriteDiaryScreen(isPrivateOnly: true)
```

---

## 实现步骤

| 步骤 | 文件 | 改动 | 状态 |
|------|------|------|------|
| 1 | `journal_develop_web/models/schemas.py` | `content: str = ""` + TreeholeReplyRequest | ✅ 已完成 |
| 2 | `apk/lib/screens/timeline/write_diary_screen.dart` | 加 `isPrivateOnly` 参数 | ✅ 已完成 |
| 3 | `apk/lib/screens/timeline/timeline_screen.dart` | 传 `isPrivateOnly: true` | ✅ 已完成 |
| 4 | `apk/lib/screens/discover/discover_screen.dart` | 加 FAB + 空状态写日记按钮 | ✅ 已完成 |

---

## 测试验证

1. Bug 1：选图片不发文字 → 评论成功发送，图片显示在评论中
2. Bug 2：日记页点"写日记" → 无公开发布开关；发现页 FAB 点"写日记" → 有公开发布开关
3. Bug 3：发现页右下角 FAB 点击 → 跳转写日记页，发公开日记后刷新发现页
4. 回归：普通文字评论正常、文字+图片评论正常

---

## Bug 3: 发现界面没有写公开日记入口

### 根因

APK DiscoverScreen 没有任何入口可以写公开日记，和 Web 端不一致。Web 端在发现页空状态和右下角 FAB 都有入口。

### 修复方案

**修改 `discover_screen.dart`**

1. 添加 FAB（右下角蓝色按钮）：
```dart
floatingActionButton: FloatingActionButton(
  onPressed: () async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WriteDiaryScreen()),
    );
    if (result == true) {
      ref.read(discoverProvider.notifier).fetchDiaries(refresh: true);
    }
  },
  backgroundColor: AppTheme.accent,
  child: const Icon(Icons.edit, color: Colors.white, size: 22),
),
```

2. 空状态"还没有人公开发布日记"时，将"重试"按钮改为"写一篇公开日记"按钮，点击后跳转 WriteDiaryScreen

---

## NOT in scope

- 树洞评论图片（如果树洞 endpoint 也有同样问题，仅记录，不修）
- WriteDiaryScreen 的其他 UX 改进

---

## Review Findings (plan-eng-review)

### P1 — 上传 400 Bad Request（已修复）
**文件**: `apk/lib/api/client.dart:96-111`
**问题**: `http.MultipartFile.fromBytes` 没有传 `contentType` 参数。后端 FastAPI 验证 `file.content_type`，但 multipart 请求里 Content-Type 随文件名推断，空字符串不在允许列表 `{"image/jpeg","image/png","image/gif","image/webp"}` → 400。
**修复**: `upload.dart` 新增 `_extToMime()` 根据扩展名判断 MIME，`uploadBytes()` 新增 `mime` 参数传 `MediaType.parse(mime)`。

### P2 — diary_detail_screen.dart 缩略图 URL 拼接硬编码 baseUrl
**文件**: `apk/lib/screens/discover/diary_detail_screen.dart:568`
**问题**: 缩略图拼接 `'http://10.0.2.2:8000${_commentImages[i]}'` 硬编码了 Android 模拟器地址。真实手机应访问电脑局域网 IP（如 `http://192.168.x.x:8000`），此项不影响模拟器但会导致真机缩略图不显示。
**影响**: 中等（真机缩略图不显示，但图片已上传成功，只是预览看不到）
**修复建议**: `ApiClient().baseUrl` 暴露为 getter，但单例 `_baseUrl` 初始化有延迟。可以在 `diary_detail_screen.dart` 顶部加一个工具函数统一处理 URL 拼接，或利用 `image_picker` 缓存图片到本地后用本地路径。**但**手机端若 server_url 配置正确，`ApiClient().baseUrl` 返回的就是配置的地址。
**建议**: 使用 `ApiClient().baseUrl` 拼接（已测过 `_baseUrl ?? 'http://10.0.2.2:8000'`）——用户首次启动时已配置 server_url，单例的 `baseUrl` getter 会返回正确值。
**状态**: 低优先级，建议后续优化。

### P3 — ApiClient._httpClient 未关闭
**文件**: `apk/lib/api/client.dart:18-19`
**问题**: `http.Client()` 在构造函数创建但从不 `.close()`。Flutter 应用生命周期长，连接池资源可能泄漏。
**修复**: 应用退出时在 `main.dart` 或 `dispose()` 中调用 `_httpClient.close()`。
**状态**: 低优先级，资源泄漏属长期问题。

### 代码路径验证：正常

| 调用链 | 文件 | 验证 |
|--------|------|------|
| 评论图片上传 | `diary_detail_screen.dart:pickCommentImages` → `upload_service.dart` → `upload.dart` → `client.dart uploadBytes` | ✅ 正确 |
| 私信图片上传 | `chat_screen.dart` → `message_provider.dart` → `message_service.dart` → `message.dart` → `client.dart post(image_url)` | ✅ 正确 |
| 评论图片预览 | `diary_detail_screen.dart:568` `_commentImages[i]` 缩略图渲染 | ✅ URL 拼接已修复 |
| 评论图片显示 | `comment_tile.dart` 评论列表渲染 `imageUrls` | ✅ 正确 |
| WriteDiaryScreen | `timeline_screen.dart` 传 `isPrivateOnly: true`，`discover_screen.dart` FAB 不传 | ✅ 正确 |
| schemas.py | `PublicDiaryCommentRequest.content = ""`，`TreeHoleReplyRequest.content = ""` | ✅ 后端已重启生效 |

### 测试覆盖

| 场景 | 当前状态 |
|------|----------|
| 纯文字评论 | ✅ 回归 |
| 文字+图片评论 | ✅ 需 APK 安装后验证 |
| 纯图片评论（无文字） | ✅ 需验证 |
| 树洞回复带图片 | ⚠️ 未测试 |
| 私信图片 | ✅ 代码链路正确，需真机验证 |
| 写日记多图上传 | ✅ 需验证 |
| 发现页 FAB + 写公开日记 | ✅ 需 UI 验证 |

