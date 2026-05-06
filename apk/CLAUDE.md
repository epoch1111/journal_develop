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
