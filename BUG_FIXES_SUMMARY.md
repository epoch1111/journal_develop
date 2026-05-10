# Bug 修复总结

## 问题 1：评论图片上传失败（后端 schema）

### 根因
`PublicDiaryCommentRequest.content` 没有默认值，空字符串被 Pydantic 拒绝（返回 422）。

### 解决方案
修改 `journal_develop_web/models/schemas.py`：
```python
class PublicDiaryCommentRequest(BaseModel):
    content: str = ""  # 加默认值
```

同时修复 `TreeHoleReplyRequest`。

---

## 问题 2：私有日记有"公开发布"开关

### 根因
`WriteDiaryScreen` 没有区分私有/公开场景。

### 解决方案
添加 `isPrivateOnly` 参数：
- `timeline_screen.dart` → `WriteDiaryScreen(isPrivateOnly: true)`（无开关）
- `discover_screen.dart` → `WriteDiaryScreen()`（有开关）

---

## 问题 3：发现页没有写公开日记入口

### 根因
DiscoverScreen 没有任何入口写公开日记。

### 解决方案
添加 FAB + 空状态按钮，跳转 `WriteDiaryScreen()`。

---

## 问题 4：评论/私信图片上传损坏

### 根因
1. `http` 库的 `MultipartFile.fromBytes` 在 Android 上处理 multipart 有问题
2. 没有 Content-Type 导致后端 400
3. 双重 JPEG 压缩导致质量严重下降

### 解决方案
1. 用 `dio` 库替代 `http` 库上传（更可靠）
2. 后端已经重启加载最新代码
3. 用 `image` 包做格式转换（JPEG 跳过，HEIC/PNG 转 JPEG）
4. 移除硬编码 `http://10.0.2.2:8000` 拼接，用完整 URL 显示

---

## 问题 5：公开日记默认不公开发布

### 根因
`_isPublic` 默认为 `false`。

### 解决方案
改为 `true`，发现页写日记默认公开发布。

---

## 修改文件

| 文件 | 改动 |
|------|------|
| `journal_develop_web/models/schemas.py` | content 默认值 |
| `apk/lib/api/client.dart` | 用 dio 上传 |
| `apk/lib/api/endpoints/upload.dart` | image 包格式转换 |
| `apk/lib/services/upload_service.dart` | 返回完整 URL |
| `apk/lib/screens/discover/diary_detail_screen.dart` | 移除硬编码拼接 |
| `apk/lib/screens/timeline/write_diary_screen.dart` | isPrivateOnly 参数，_isPublic 默认 true |
| `apk/lib/screens/timeline/timeline_screen.dart` | 传 isPrivateOnly: true |
| `apk/lib/screens/discover/discover_screen.dart` | 添加 FAB |
| `apk/pubspec.yaml` | 添加 image 包依赖 |