"""安全系统测试脚本 - 使用 FastAPI TestClient"""
import io, sys, os, random

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

os.environ['ENVIRONMENT'] = 'development'

from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

PASS, FAIL = 0, 0
TOKENS = {}

def test(name, condition, detail=""):
    global PASS, FAIL
    if condition:
        PASS += 1
        print(f"  [PASS] {name}")
    else:
        FAIL += 1
        print(f"  [FAIL] {name} -- {detail}")

def separator(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")

def auth_headers(token):
    return {"Authorization": f"Bearer {token}"} if token else {}

def register(username, password):
    res = client.post("/api/auth/register", json={"username": username, "password": password, "email": ""})
    data = res.json()
    token = data.get("access_token", "")
    if token:
        TOKENS[username] = token
    return token

def login(username, password):
    res = client.post("/api/auth/login", json={"username": username, "password": password})
    data = res.json()
    token = data.get("access_token", "")
    if token:
        TOKENS[username] = token
    return token


# ===== Setup: register users =====
separator("SETUP")
uid = random.randint(10000, 99999)
a_user, a_pass = f"test_a_{uid}", "test123"
b_user, b_pass = f"test_b_{uid}", "test123"
c_user, c_pass = f"test_c_{uid}", "test123"

token_a = register(a_user, a_pass)
token_b = register(b_user, b_pass)
token_c = register(c_user, c_pass)

# Get user IDs
res_a = client.get("/api/auth/me", headers=auth_headers(token_a))
res_b = client.get("/api/auth/me", headers=auth_headers(token_b))
res_c = client.get("/api/auth/me", headers=auth_headers(token_c))
user_a = res_a.json()
user_b = res_b.json()
user_c = res_c.json()
id_a = user_a['user']['id']
id_b = user_b['user']['id']
id_c = user_c['user']['id']
print(f"  User A (id={id_a}): {a_user}")
print(f"  User B (id={id_b}): {b_user}")
print(f"  User C (id={id_c}): {c_user}")

# A creates a public diary
res = client.post("/api/save", json={
    "mood": "😊", "content": "A的公开日记", "is_public": True,
    "ai_summary": "开心的一天", "ai_message": "继续加油", "tags": "test"
}, headers=auth_headers(token_a))
diary = res.json()
id_diary_a = diary.get('id')

# B creates a public diary
res = client.post("/api/save", json={
    "mood": "🥰", "content": "B的公开日记", "is_public": True,
    "ai_summary": "幸福", "ai_message": "美好", "tags": "test"
}, headers=auth_headers(token_b))
diary2 = res.json()
id_diary_b = diary2.get('id')
print(f"  Diary A id={id_diary_a}, Diary B id={id_diary_b}")


# ===== A. 拉黑用户 =====
separator("A. 拉黑用户")

# A 拉黑 B
res = client.post(f"/api/users/{id_b}/block", json={"reason": "测试拉黑"}, headers=auth_headers(token_a))
data = res.json()
test("A blocks B - ok", data.get('ok'), str(data))
test("A blocks B - blocked=true", data.get('blocked'), str(data))
test("A blocks B - not already_blocked", not data.get('already_blocked'), str(data))

# 重复拉黑
res = client.post(f"/api/users/{id_b}/block", json={"reason": "再次"}, headers=auth_headers(token_a))
data = res.json()
test("Duplicate block - already_blocked", data.get('already_blocked') == True, str(data))

# 自己拉黑自己
res = client.post(f"/api/users/{id_a}/block", json={"reason": ""}, headers=auth_headers(token_a))
data = res.json()
test("Self block rejected - 400", res.status_code == 400, str(data))
test("Self block message", "不能拉黑自己" in str(data.get('detail', '')), str(data))

# 查询拉黑状态
res = client.get(f"/api/users/{id_b}/block-status", headers=auth_headers(token_a))
data = res.json()
test("Block status - blocked", data.get('blocked') == True, str(data))
test("Block status - not blocked_by", data.get('blocked_by_target') == False, str(data))
test("Block status - any_blocked", data.get('any_blocked') == True, str(data))

# 拉黑列表
res = client.get("/api/me/blocked-users", headers=auth_headers(token_a))
data = res.json()
test("Blocked users list", len(data) >= 1, str(data))
test("Blocked user info has nickname", 'nickname' in (data[0] if data else {}), str(data))
test("Blocked user info has blocked_at", 'blocked_at' in (data[0] if data else {}), str(data))

# C 不能查看 A 的拉黑列表
res = client.get("/api/me/blocked-users", headers=auth_headers(token_c))
data = res.json()
test("C sees own blocked list (empty)", len(data) == 0, str(data))


# ===== B. 被拉黑后的限制 =====
separator("B. 被拉黑后的限制")

# B 不能关注 A
res = client.post(f"/api/users/{id_a}/follow", headers=auth_headers(token_b))
data = res.json()
test("B cannot follow A - 403", res.status_code == 403, str(data))

# B 不能打招呼 A
res = client.post("/api/greet/requests", json={"receiver_id": id_a, "message": "你好"}, headers=auth_headers(token_b))
data = res.json()
test("B cannot greet A - 403", res.status_code == 403, str(data))

# B 不能给 A 发私信
res = client.post("/api/messages/conversations", json={"user_id": id_a}, headers=auth_headers(token_b))
data = res.json()
test("B cannot message A - 403", res.status_code == 403, str(data))

# B 不能点亮 A 的公开日记
res = client.post(f"/api/public/diaries/{id_diary_a}/like", json={"client_id": f"test_{uid}_b"}, headers=auth_headers(token_b))
data = res.json()
test("B cannot like A's diary - 403", res.status_code == 403, str(data))

# B 不能评论 A 的公开日记
res = client.post(f"/api/public/diaries/{id_diary_a}/comments", json={
    "client_id": f"test_{uid}_b", "content": "Great diary!"
}, headers=auth_headers(token_b))
data = res.json()
test("B cannot comment A's diary - 403", res.status_code == 403, str(data))

# B 查看 A 的作者主页
res = client.get(f"/api/profile/{id_a}", headers=auth_headers(token_b))
data = res.json()
test("B sees blocked status in A's profile", data.get('blocked') == True, str(data))


# ===== C. 举报功能 =====
separator("C. 举报功能")

# A 举报 B (用户)
res = client.post("/api/reports", json={
    "target_type": "user", "target_id": id_b,
    "reason": "harassment", "description": "这个用户骚扰我"
}, headers=auth_headers(token_a))
data = res.json()
test("Report user - ok", data.get('ok'), str(data))
test("Report user - status pending", data.get('status') == 'pending', str(data))

# A 举报日记
res = client.post("/api/reports", json={
    "target_type": "diary", "target_id": id_diary_b,
    "reason": "spam", "description": "垃圾内容"
}, headers=auth_headers(token_a))
data = res.json()
test("Report diary - ok", data.get('ok'), str(data))

# A 举报评论 (先让C评论A的日记)
res = client.post(f"/api/public/diaries/{id_diary_a}/comments", json={
    "client_id": f"test_{uid}_c", "content": "好日记！"
}, headers=auth_headers(token_c))
comment_data = res.json()
comment_id = comment_data.get('comment', {}).get('id') if comment_data.get('comment') else None
print(f"  C commented on A's diary, comment_id={comment_id}")

if comment_id:
    res = client.post("/api/reports", json={
        "target_type": "comment", "target_id": comment_id,
        "reason": "harassment", "description": ""
    }, headers=auth_headers(token_a))
    data = res.json()
    test("Report comment - ok", data.get('ok'), str(data))

# A 举报树洞
res = client.post("/api/reports", json={
    "target_type": "treehole", "target_id": id_diary_b,
    "reason": "other", "description": "测试举报树洞"
}, headers=auth_headers(token_a))
data = res.json()
test("Report treehole - ok", data.get('ok'), str(data))

# 无效 target_type
res = client.post("/api/reports", json={
    "target_type": "invalid", "target_id": 1,
    "reason": "other", "description": ""
}, headers=auth_headers(token_a))
data = res.json()
test("Invalid target_type - 400", res.status_code == 400, str(data))

# 无效 reason
res = client.post("/api/reports", json={
    "target_type": "user", "target_id": id_b,
    "reason": "bad_reason", "description": ""
}, headers=auth_headers(token_a))
data = res.json()
test("Invalid reason - 400", res.status_code == 400, str(data))

# 查看我的举报
res = client.get("/api/reports/my", headers=auth_headers(token_a))
data = res.json()
test("My reports - has items", len(data) >= 1, str(data))
test("My reports include user report", any(r.get('target_type') == 'user' for r in data), str(data))

# C 不能看 A 的举报
res = client.get("/api/reports/my", headers=auth_headers(token_c))
data = res.json()
test("C sees own reports (empty)", len(data) == 0, str(data))

# 未登录不能举报
res = client.post("/api/reports", json={
    "target_type": "user", "target_id": id_b,
    "reason": "harassment", "description": ""
})
data = res.json()
test("Anonymous report rejected - 401", res.status_code == 401, str(data))


# ===== D. 解除拉黑 =====
separator("D. 解除拉黑")

# A 解除拉黑 B
res = client.delete(f"/api/users/{id_b}/block", headers=auth_headers(token_a))
data = res.json()
test("Unblock - ok", data.get('ok'), str(data))
test("Unblock - blocked=false", data.get('blocked') == False, str(data))

# 再次查询状态
res = client.get(f"/api/users/{id_b}/block-status", headers=auth_headers(token_a))
data = res.json()
test("After unblock - blocked=false", data.get('blocked') == False, str(data))
test("After unblock - any_blocked=false", data.get('any_blocked') == False, str(data))

# B 现在可以关注 A 了
res = client.post(f"/api/users/{id_a}/follow", headers=auth_headers(token_b))
data = res.json()
test("B can follow A after unblock", data.get('ok'), str(data))

# 取消关注以清理
client.delete(f"/api/users/{id_a}/follow", headers=auth_headers(token_b))


# ===== E. 重新拉黑测试私信限制 =====
separator("E. 拉黑后私信限制（双向）")

# 先打招呼建立关系: C → A
res = client.post("/api/greet/requests", json={"receiver_id": id_a, "message": "你好A"}, headers=auth_headers(token_c))
data = res.json()
print(f"  C greet A: status={res.status_code}, data={data}")
if data.get('id'):
    # A 同意 C 的打招呼
    res = client.post(f"/api/greet/requests/{data['id']}/accept", headers=auth_headers(token_a))
    print(f"  A accept C's greet: status={res.status_code}")

    # C 给 A 发消息
    res = client.post("/api/messages/conversations", json={"user_id": id_a}, headers=auth_headers(token_c))
    data = res.json()
    conv_id = data.get('conversation', {}).get('id') if data.get('conversation') else None
    print(f"  C start conv with A: conv_id={conv_id}")
    test("C can start conversation with A", conv_id is not None, str(data))

    if conv_id:
        res = client.post(f"/api/messages/conversations/{conv_id}/messages", json={"content": "Hello A!"}, headers=auth_headers(token_c))
        data = res.json()
        test("C can message A before block", data.get('ok'), str(data))

        # A 拉黑 C
        res = client.post(f"/api/users/{id_c}/block", json={"reason": ""}, headers=auth_headers(token_a))
        blk_data = res.json()
        print(f"  A blocks C: status={res.status_code}, data={blk_data}")
        test("A blocks C", blk_data.get('ok'), str(blk_data))

        # C 不能再发消息给 A
        res = client.post(f"/api/messages/conversations/{conv_id}/messages", json={"content": "Can I still talk?"}, headers=auth_headers(token_c))
        data = res.json()
        test("C cannot send msg after A blocks C - 403", res.status_code == 403, str(data))

        # A 也不能再发消息给 C (双向)
        res = client.post(f"/api/messages/conversations/{conv_id}/messages", json={"content": "Reply from A"}, headers=auth_headers(token_a))
        data = res.json()
        test("A cannot send msg either (bidirectional) - 403", res.status_code == 403, str(data))

        # 但可以查看历史消息
        res = client.get(f"/api/messages/conversations/{conv_id}/messages", headers=auth_headers(token_c))
        data = res.json()
        test("C can still view history", len(data.get('items', [])) >= 1, str(data))

    # 解除拉黑
    res = client.delete(f"/api/users/{id_c}/block", headers=auth_headers(token_a))
    print(f"  A unblocks C: status={res.status_code}")


# ===== F. 主页和发现页过滤 =====
separator("F. 主页和发现页过滤")

# A 拉黑 B
res = client.post(f"/api/users/{id_b}/block", json={"reason": ""}, headers=auth_headers(token_a))
blk = res.json()
print(f"  A re-blocks B: status={res.status_code}, data={blk}")

# A 查看发现页 - 不应该包含 B 的日记
res = client.get("/api/public/diaries?page_size=50", headers=auth_headers(token_a))
data = res.json()
b_ids = [d.get('user_id') for d in data.get('items', [])]
test("A's discover does not show B's diaries", id_b not in b_ids, str(b_ids))

# 解除拉黑
client.delete(f"/api/users/{id_b}/block", headers=auth_headers(token_a))


# ===== G. 权限测试 =====
separator("G. 权限测试")

# 用户 C 不能拉黑不存在的用户
res = client.post("/api/users/99999/block", json={"reason": ""}, headers=auth_headers(token_c))
data = res.json()
test("Block nonexistent user - 404", res.status_code == 404, str(data))

# 未登录不能拉黑
res = client.post(f"/api/users/{id_b}/block", json={"reason": ""})
data = res.json()
test("Anonymous block - 401", res.status_code == 401, str(data))

# 未登录查看拉黑列表
res = client.get("/api/me/blocked-users")
data = res.json()
test("Anonymous blocked list - 401", res.status_code == 401, str(data))


# ===== 回归测试 =====
separator("H. 回归测试")

# 注册
token_new = register(f"regr_{uid}", "test123")
test("Registration - ok", token_new is not None and len(token_new) > 0)

# 登录
token_login = login(f"regr_{uid}", "test123")
test("Login - ok", token_login is not None and len(token_login) > 0)

# 日记 CRUD
res = client.get("/api/auth/me", headers=auth_headers(token_new))
me = res.json()
my_id = me['user']['id']

res = client.post("/api/save", json={
    "mood": "😊", "content": "回归测试日记", "is_public": False,
    "ai_summary": "", "ai_message": "", "tags": ""
}, headers=auth_headers(token_new))
data = res.json()
test("Save diary - ok", data.get('ok'))
regr_diary_id = data.get('id')

res = client.get("/api/diaries", headers=auth_headers(token_new))
data = res.json()
test("List diaries - ok", len(data) >= 1)

res = client.get(f"/api/diaries/{regr_diary_id}", headers=auth_headers(token_new))
data = res.json()
test("Get diary detail - ok", data.get('id') == regr_diary_id)

res = client.put(f"/api/diaries/{regr_diary_id}", json={"content": "更新后的日记"}, headers=auth_headers(token_new))
data = res.json()
test("Update diary - ok", data.get('ok'))

res = client.delete(f"/api/diaries/{regr_diary_id}", headers=auth_headers(token_new))
data = res.json()
test("Delete diary - ok", data.get('ok'))

# 统计
res = client.get("/api/stats", headers=auth_headers(token_new))
data = res.json()
test("Stats - ok", 'mood_distribution' in data)

# 树洞
res = client.get("/api/treehole/random")
test("Treehole random - ok", res.status_code in (200, 404))

# 通知
res = client.get("/api/notifications", headers=auth_headers(token_new))
data = res.json()
test("Notifications - ok", 'items' in data)

# 打招呼
res = client.get("/api/greet/pending-count", headers=auth_headers(token_new))
data = res.json()
test("Greet pending count - ok", 'pending_count' in data)

# 私信
res = client.get("/api/messages/conversations", headers=auth_headers(token_new))
data = res.json()
test("Conversations - ok", isinstance(data, list))

# 关注
res = client.get("/api/me/following", headers=auth_headers(token_new))
data = res.json()
test("Following list - ok", isinstance(data, list))

# 主页
res = client.get("/api/profile/me", headers=auth_headers(token_new))
data = res.json()
test("My profile - ok", 'nickname' in data)

# 安全
res = client.get("/api/me/blocked-users", headers=auth_headers(token_new))
data = res.json()
test("Blocked users - ok", isinstance(data, list))

res = client.get("/api/reports/my", headers=auth_headers(token_new))
data = res.json()
test("My reports - ok", isinstance(data, list))


# ===== SUMMARY =====
separator("SUMMARY")
print(f"\n  PASS: {PASS}")
print(f"  FAIL: {FAIL}")
print(f"  TOTAL: {PASS + FAIL}")
if FAIL == 0:
    print("  ALL TESTS PASSED!")
else:
    print(f"  {FAIL} TEST(S) FAILED!")
